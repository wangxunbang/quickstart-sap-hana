#!/bin/bash


# ------------------------------------------------------------------
# Fence progress of HANA cluster to make sure they all sync up
# Update own StatusAck and make sure all nodes acknowledges its status 
# ------------------------------------------------------------------

JQ_COMMAND=/root/install/jq
export PATH=${PATH}:/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/X11R6/bin:/usr/games:/usr/lib/AmazonEC2/ec2-api-tools/bin:/usr/lib/AmazonEC2/ec2-ami-tools/bin:/usr/lib/mit/bin:/usr/lib/mit/sbin

usage() { 
    cat <<EOF
    Usage: $0 [options]
        -h print usage
        -w Wait until #HANA nodes acknowledge a specific state (StatusAck=N)
        -n Table Name (optional, else pick from /root/config.sh)
EOF
    exit 0
}


# ------------------------------------------------------------------
#          Read all inputs
# ------------------------------------------------------------------


[[ $# -eq 0 ]] && usage;

while getopts "h:n:w:" o; do
    case "${o}" in
        h) usage && exit 0
            ;;
        w) WAIT_STATUS_COUNT_PAIR=${OPTARG}
            ;;
        n) TABLE_NAME=${OPTARG}
            ;;
        *) 
            usage
            ;;
    esac
done

# ------------------------------------------------------------------
#          Make sure all input parameters are filled
# ------------------------------------------------------------------
                    
                    
[[ -z "$TABLE_NAME" ]] && source /root/install/config.sh
shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;

SCRIPT_DIR=/root/install/
if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}


source /root/install/config.sh 
source /root/install/os.sh 

export AWS_DEFAULT_REGION=${REGION}

#Check if SIG_FLAG_FILE is present

if [ $(issignal_check) == 1 ]
then
    #Exit since there is a signal file
    log "Exiting $0 script at `date` because $SIG_FLAG_FILE exists"
    exit 1
fi

GetMyIp() {
    ip=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
    # Begin RHEL 7.2  addition
    if [ $ip = '']; then
    ip=$(ifconfig eth0 | grep 'inet ' | cut -d: -f2 | awk '{ print $2}')
    fi
    # End RHEL 7.2 addition
    echo ${ip}
}



# ------------------------------------------------------------------
#          Update or insert table item with new key=value pair
#          New attributes get added, old attributes get updated
#          Use private ip as primary hash key
#          Usage InsertMyKeyValueS key=value
# ------------------------------------------------------------------

InsertMyKeyValueS() {

    keyvalue=$1
    if [ -z "$keyvalue" ]; then
        echo "Invalid KeyPair Values!"
        return
    fi
    key=$(echo $keyvalue | awk -F'=' '{print $1}')
    value=$(echo $keyvalue | awk -F'=' '{print $2}')

    keyjson_template='{"PrivateIpAddress": {
        "S": "myip"
        }}'
    myip=$(GetMyIp)  
    keyjson=$(echo -n ${keyjson_template} | sed "s/myip/${myip}/g")

    insertjson_template='{"key": {
                "Value": {
                    "S": "value"
                },
                "Action": "PUT"
            }
        }'

    insertjson=$(echo -n ${insertjson_template} | sed "s/key/${key}/g")    
    insertjson=$(echo -n ${insertjson} | sed "s/value/${value}/g")    
    cmd=$(echo  "/usr/local/bin/aws dynamodb update-item --table-name ${TABLE_NAME} --key '${keyjson}' --attribute-updates '${insertjson}'")
	log "${cmd}"	
    echo ${cmd} | sh 


}

# ------------------------------------------------------------------
# Set my StatusAck (i.e Acknowledge own status)
# Usage: AckMyStatus "PRE_INSTALL_COMPLETE"
# ------------------------------------------------------------------
AckMyStatus() {
    status=$1
    if [ -z "$status" ]; then
        echo "Invalid StatusAck Update!"
        return
    fi
    keyjson_template='{"PrivateIpAddress": {
        "S": "myip"
        }}'
    myip=$(GetMyIp)    
    keyjson=$(echo -n ${keyjson_template} | sed "s/myip/${myip}/g")

    updatejson_template='{"StatusAck": {
                "Value": {
                    "S": "mystatus"
                },
                "Action": "PUT"
            }
        }'

    updatejson=$(echo -n ${updatejson_template} | sed "s/mystatus/${status}/g")    
    cmd=$(echo  "/usr/local/bin/aws dynamodb update-item --table-name ${TABLE_NAME} --key '${keyjson}' --attribute-updates '${updatejson}'")
    echo ${cmd} | sh 

}


# ------------------------------------------------------------------
#          Count number of HANA hosts in specific state after ack
#          Usage: QueryStatusAckCount "PRE_INSTALL_COMPLETE" etc
# ------------------------------------------------------------------

QueryStatusAckCount(){
    status=$1
    if [ -z "$status" ]; then
        echo "StatusAckCountQuery invalid!"
        return 
    fi
    count=$(/usr/local/bin/aws dynamodb scan --table-name ${TABLE_NAME} --scan-filter '
            { "StatusAck" : {
                "AttributeValueList": [
                    {
                        "S": '\"${status}\"'
                    }
                ],
                "ComparisonOperator":"EQ"
                }} ' | ${JQ_COMMAND}  '.Items[]|.PrivateIpAddress|.S' | wc -l)
    echo ${count}
}


# ------------------------------------------------------------------
#          Set own StatusAck to be status and then wait
#          Wait until specific #HANA hosts reach specific state ack
#          Usage: WaitUntilStatusAck "PRE_INSTALL_COMPLETE=5" etc.
#          Wait until 5 HANA nodes reach "PRE_INSTALL_COMPLETE" statusack
# ------------------------------------------------------------------

WaitForSpecificStatusAck() {
	log "WaitForSpecificStatusAck START ($1) in fence-cluter.sh"

    status_count_pair=$1
    if [ -z "$status_count_pair" ]; then
        echo "Invalid StatusAck=count Values!"
        return
    fi
	log "Received ${status_count_pair} in fence watcher"
    status=$(echo $status_count_pair | /usr/bin/awk -F'=' '{print $1}')
    expected_count=$(echo $status_count_pair | /usr/bin/awk -F'=' '{print $2}')
	log "Checking for ${status} = ${expected_count} times in fence-cluster.sh"
   
    $(AckMyStatus ${status})
    while true; do
        count=$(QueryStatusAckCount ${status})
		log "Ack ${count}..."
        if [ "${count}" -lt "${expected_count}" ]; then
            log "${count}/${expected_count} in ${status} status...Waiting"
	    sleep 10
       else
            log "${count} out of ${expected_count} in ${status} status!"
            log "WaitForSpecificStatusAck END ($1) in fence-cluster.sh"
            return
        fi
    done 
	


}

if [ $WAIT_STATUS_COUNT_PAIR ]; then
    WaitForSpecificStatusAck $WAIT_STATUS_COUNT_PAIR
fi

