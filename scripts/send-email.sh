#
# ------------------------------------------------------------------
#          Install aws cli tools and jq
# ------------------------------------------------------------------

usage() { 
    cat <<EOF
    Usage: $0 [options]
        -h print usage        
        -t Topic
        -e email
EOF
    exit 1
}

# ------------------------------------------------------------------
#          Read all inputs
# ------------------------------------------------------------------



while getopts ":h:p:s:n:d:l:" o; do
    case "${o}" in
        h) usage && exit 0
            ;;
        p) HANAPASSWORD=${OPTARG}
            ;;
        s) SID=${OPTARG}
            ;;
        n) MASTER_HOSTNAME=${OPTARG}
            ;;
        d) DOMAIN=${OPTARG}
            ;;
        l)
           HANA_LOG_FILE=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done



[ -e /root/install/jq ] && export JQ_COMMAND=/root/install/jq
[ -z ${JQ_COMMAND} ] && export JQ_COMMAND=/home/ec2-user/jq

if [ ! -f ${JQ_COMMAND} ]; then
	wget -O ${JQ_COMMAND} https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/media/jq
	chmod 755 ${JQ_COMMAND}
fi

[ -e /root/install/config.sh ] && source /root/install/config.sh 
export AWS_DEFAULT_REGION=${REGION}
export AWS_DEFAULT_AVAILABILITY_ZONE=${AVAILABILITY_ZONE}


if [ -z ${AWS_DEFAULT_REGION} ]; then
	 export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
					| ${JQ_COMMAND} '.region'  \
					| sed 's/^"\(.*\)"$/\1/' )
fi
if [ -z ${AWS_DEFAULT_AVAILABILITY_ZONE} ]; then
	 export AWS_DEFAULT_AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
						| ${JQ_COMMAND} '.availabilityZone' \
						| sed 's/^"\(.*\)"$/\1/' )
fi

if [ -z ${AWS_INSTANCEID} ]; then
	 export AWS_INSTANCEID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
						| ${JQ_COMMAND} '.instanceId' \
						| sed 's/^"\(.*\)"$/\1/' )
fi

# ------------------------------------------------------------------
#          remove double quotes, if any. cli doesn't like it!
# ------------------------------------------------------------------

export AWS_DEFAULT_REGION=$(echo ${AWS_DEFAULT_REGION} | sed 's/^"\(.*\)"$/\1/' )
export AWS_DEFAULT_AVAILABILITY_ZONE=$(echo ${AWS_DEFAULT_AVAILABILITY_ZONE} | sed 's/^"\(.*\)"$/\1/' )
export AWS_INSTANCEID=$(echo ${AWS_INSTANCEID} | sed 's/^"\(.*\)"$/\1/' )


export AWS_CMD=/usr/local/bin/aws

${AWS_CMD} sns create-topic --name MyTopic




exit 0








