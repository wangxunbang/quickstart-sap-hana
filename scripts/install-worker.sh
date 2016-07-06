#!/bin/bash


# ------------------------------------------------------------------
#
#          Install SAP HANA Worker Node
#		   Run once via cloudformation call through user-data
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

usage() {
	cat <<EOF
	Usage: $0 [options]
		-h print usage
		-s SID
		-p HANA password
		-n MASTER_HOSTNAME
		-d DOMAIN
		-l HANA_LOG_FILE [optional]
EOF
	exit 1
}

[ -e /root/install/jq ] && export JQ_COMMAND=/root/install/jq
[ -z ${JQ_COMMAND} ] && export JQ_COMMAND=/home/ec2-user/jq
export PATH=${PATH}:/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/X11R6/bin:/usr/games:/usr/lib/AmazonEC2/ec2-api-tools/bin:/usr/lib/AmazonEC2/ec2-ami-tools/bin:/usr/lib/mit/bin:/usr/lib/mit/sbin
myInstance=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document/ | ${JQ_COMMAND} '.instanceType' | \
			 sed 's/"//g')

export USE_NEW_STORAGE=1

# ------------------------------------------------------------------
#          Read all inputs
# ------------------------------------------------------------------


while getopts ":h:s:p:n:d:l:" o; do
    case "${o}" in
        h) usage && exit 0
			;;
		s) SID=${OPTARG}
			;;
		p) HANAPASSWORD=${OPTARG}
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


# ------------------------------------------------------------------
#          Make sure all input parameters are filled
# ------------------------------------------------------------------


[[ -z "$SID" ]]  && echo "input SID missing" && usage;
[[ -z "$HANAPASSWORD" ]]  && echo "input HANAPASSWORD missing" && usage;
[[ -z "$MASTER_HOSTNAME" ]]  && echo "input MASTER_HOSTNAME missing" && usage;
[[ -z "$DOMAIN" ]]  && echo "input DOMAIN Name missing" && usage;
shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;



[ -e /root/install/config.sh ] && source /root/install/config.sh
[ -e /root/install/os.sh ] && source /root/install/os.sh


# ------------------------------------------------------------------
#          Build storage from storage.json
#		   First build a master script via generator code, then run it
# ------------------------------------------------------------------

export USE_NEW_STORAGE=1
MyInstanceType=$(/usr/local/bin/aws cloudformation describe-stacks --stack-name ${MyStackId}  --region ${REGION}  \
				| /root/install/jq '.Stacks[0].Parameters[] | select(.ParameterKey=="MyInstanceType") | .ParameterValue' \
				| sed 's/"//g')
MyVolumeType=$(/usr/local/bin/aws cloudformation describe-stacks --stack-name ${MyStackId}  --region ${REGION}  \
				| /root/install/jq '.Stacks[0].Parameters[] | select(.ParameterKey=="VolumeType") | .ParameterValue' \
				| sed 's/"//g')


STORAGE_SCRIPT=/root/install/storage_builder_generated_worker.sh
python /root/install/build_storage.py  -config /root/install/storage.json  \
					     -ismaster ${IsMasterNode} \
					     -hostcount ${HostCount} -which hana_data_log \
					     -instance_type ${MyInstanceType} -storage_type ${MyVolumeType} \
					     >> ${STORAGE_SCRIPT}
python /root/install/build_storage.py  -config /root/install/storage.json  \
					     -ismaster ${IsMasterNode} \
					     -hostcount ${HostCount} -which usr_sap \
					     -instance_type ${MyInstanceType} -storage_type ${MyVolumeType} \
					     >> ${STORAGE_SCRIPT}




# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

if (( ${USE_NEW_STORAGE} == 1 ));
then
	log `date` "Using New Storage from storage.json"
	sh -x ${STORAGE_SCRIPT} >> ${HANA_LOG_FILE} 
	log `date` "END Storage from storage.json"
fi


log() {
	echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}


log `date` BEGIN install-worker


update_status () {
   local status="$1"
   if [ "$status" ]; then
      if [ -e /root/install/cluster-watch-engine.sh ]; then
         sh /root/install/cluster-watch-engine.sh -s "$status"
      fi
   fi
}


update_status "CONFIGURING_INSTANCE_FOR_HANA"

# ------------------------------------------------------------------
#          Create PV's for LVM2 saphana volume group
# ------------------------------------------------------------------

if (( ${USE_NEW_STORAGE} == 1 ));
then
	log `date` "Disabled Creating Physical Volumes for saphana volume group"
else
	log `date` "Creating Physical Volumes for saphana volume group"
	for i in {b..e}
	do
	  pvcreate /dev/xvd$i
	done
fi

# ------------------------------------------------------------------
#           Set i/o scheduler to noop
# ------------------------------------------------------------------

log `date` "Setting i/o scheduler to noop for each physical volume"
for i in `pvs | grep dev | awk '{print $1}' | sed s/\\\/dev\\\///`
do
  echo "noop" > /sys/block/$i/queue/scheduler
  printf "$i: "
  cat /sys/block/$i/queue/scheduler
done


# ------------------------------------------------------------------
#          Create volume group vghana
#          Create Logical Volumes
#          Format filesystems
# ------------------------------------------------------------------

log `date` "Creating volume group vghana"
if (( ${USE_NEW_STORAGE} == 1 ));
then
	echo "disabled vgcreate"
else
	vgcreate vghana /dev/xvd{b..d}
fi


logsize=",c3.8xlarge:244G,r3.2xlarge:244G,r3.4xlarge:244G,r3.8xlarge:244G,"
datasize=",c3.8xlarge:488G,r3.2xlarge:488G,r3.4xlarge:488G,r3.8xlarge:488G,"
sharedsize=",c3.8xlarge:60G,r3.2xlarge:60G,r3.4xlarge:122G,r3.8xlarge:244G,"
backupsize=",c3.8xlarge:300G,r3.2xlarge:300G,r3.4xlarge:610G,r3.8xlarge:1200G,"



get_logsize() {
    echo "$(expr "$logsize" : ".*,$1:\([^,]*\),.*")"
}

get_datasize() {
    echo "$(expr "$datasize" : ".*,$1:\([^,]*\),.*")"
}
get_sharedsize() {
    echo "$(expr "$sharedsize" : ".*,$1:\([^,]*\),.*")"
}
get_backupsize() {
    echo "$(expr "$backupsize" : ".*,$1:\([^,]*\),.*")"
}

mylogSize=$(get_logsize  ${myInstance})
mydataSize=$(get_datasize   ${myInstance})
mysharedSize=$(get_sharedsize  ${myInstance})
mybackupSize=$(get_backupsize  ${myInstance})



#log "Creating hana data logical volume"
#lvcreate -n lvhanadata -i 4  -I 256 -L ${mydataSize} vghana
#log "Creating hana log logical volume"
#lvcreate -n lvhanalog  -i 4 -I 256  -L ${mylogSize} vghana

###8. Updated number of stripes to 3 for logical volumes created under volume group vghana (Both Master and Worker)

if (( ${USE_NEW_STORAGE} == 1 )); then
	log `date` "DISABLED old lvcreate"
else
	lvcreate -n lvhanashared -i 3 -I 256 -L ${mysharedSize}  vghana
	log `date` "Creating hana data logical volume"
	lvcreate -n lvhanadata -i 3 -I 256  -L ${mydataSize} vghana
	log `date` "Creating hana log logical volume"
	lvcreate -n lvhanalog  -i 3 -I 256 -L ${mylogSize} vghana
fi


if (( ${USE_NEW_STORAGE} == 1 ));
then
	echo "Disabled old storage code"
	log `date` "Formatting block device for /usr/sap"
	mkfs.xfs -f /dev/xvds

else
	log `date` "Formatting block device for /usr/sap"
	mkfs.xfs -f /dev/xvds


	## 9.1 Create a new volume to store media.
	## This is where media bits will be downloaded from S3 and extracted

	mkfs.xfs -f /dev/xvdz
	mkdir -p /media/
	mount /dev/xvdz /media/
fi


#/backup /hana/shared /hana/log /hana/data
for lv in `ls /dev/mapper | grep vghana`
do
   log `date` "Formatting logical volume $lv"
   mkfs.xfs /dev/mapper/$lv
done



# ------------------------------------------------------------------
#          Create mount points and important directories
#		   Update /etc/fstab
#		   Mount all filesystems
# ------------------------------------------------------------------

log `date` "Creating SAP and HANA directories"
mkdir /usr/sap
mkdir /hana /hana/log /hana/data /hana/shared
mkdir /backup

log `date` "Creating mount points in fstab"
echo "/dev/xvds			   /usr/sap       xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
echo "/dev/mapper/vghana-lvhanadata     /hana/data     xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
echo "/dev/mapper/vghana-lvhanalog      /hana/log      xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab

log `date` "mounting filesystems"
mount -a
mount

mkdir /hana/data/$SID /hana/log/$SID
#mkdir /usr/sap/$SID

##activate LVM at boot
if (( $(isSLES) == 1 )); then
  log `date` "Turning on Activate of LVM at boot"
  chkconfig boot.lvm on
fi

##configure autofs
log  `date` "Configuring NFS client services"
sed -i '/auto.master/c\#+auto.master' /etc/auto.master
echo "/- auto.direct" >> /etc/auto.master
echo "/hana/shared	-rw,rsize=32768,wsize=32768,timeo=14,intr     $MASTER_HOSTNAME.$DOMAIN:/hana/shared" >> /etc/auto.direct
echo "/backup		-rw,rsize=32768,wsize=32768,timeo=14,intr     $MASTER_HOSTNAME.$DOMAIN:/backup" >> /etc/auto.direct

mount -t nfs $MASTER_HOSTNAME.$DOMAIN:/hana/shared /hana/shared
mount -t nfs $MASTER_HOSTNAME.$DOMAIN:/backup /backup

#trigger automount to mount shared filesystems
echo "trigger automount to mount shared filesystems"
ls -l /hana/shared
ls -l /backup


# ------------------------------------------------------------------
#          Pass through HANA installation
# ------------------------------------------------------------------

if [ "${INSTALL_HANA}" == "No" ]; then
    log `date` "INSTALL_HANA set to no, will pass through install-worker.sh"
    exit 0
else
    log `date` "INSTALL_HANA set to yes, will install HANA via install-worker.sh"
fi

#------------------------------------------------------------------
#	Add HANA Wroker to HANA Master
#------------------------------------------------------------------

#Change permissions temporarily for install
chmod 777 /hana/data/$SID /hana/log/$SID

update_status "INSTALLING_SAP_HANA"
sh ${SCRIPT_DIR}/install-hana-worker.sh -p $HANAPASSWORD -s $SID -n $MASTER_HOSTNAME -d $DOMAIN
update_status "PERFORMING_POST_INSTALL_STEPS"

#Fix permissions
chmod 755 /hana/data/$SID /hana/log/$SID

echo `date` END install-worker  >> /root/install/install.log

#--------------------------------------------------------------------------------
#          Update Init scripts to make autofs start before SAP upon system reboot
#--------------------------------------------------------------------------------

if (( $(isSLES) == 1 )); then
	sed -i '/# Required-Start:/ c\# Required-Start: $network $syslog $remote_fs $time autofs' /etc/init.d/sapinit
	insserv sapinit
	chkconfig sapinit on
else
	sed -i '/# Required-Start:/ c\# Required-Start: $network $syslog $remote_fs $time autofs' /etc/init.d/sapinit
	chkconfig sapinit on
fi

cat /root/install/install.log >> /var/log/messages


# Post installation: Install AWS Data provider
cd /root/install/
/usr/local/bin/aws s3 cp s3://aws-data-provider/bin/aws-agent_install.sh /root/install/aws-agent_install.sh
chmod +x aws-agent_install.sh
./aws-agent_install.sh


