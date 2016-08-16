 #!/bin/bash
# ------------------------------------------------------------------
#
#          Install SAP HANA Master Node
#		   invoked once via cloudformation call through user-data
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

usage() {
	cat <<EOF
	Usage: $0 [options]
		-h print usage
		-s SID
		-i instance
		-p HANA password
		-n MASTER_HOSTNAME
		-d DOMAIN
		-w WORKER_HOSTNAME
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


while getopts ":h:s:i:p:n:d:w:l:" o; do
    case "${o}" in
        h) usage && exit 0
			;;
		s) SID=${OPTARG}
			;;
		i) INSTANCE=${OPTARG}
			;;
		p) HANAPASSWORD=${OPTARG}
			;;
		n) MASTER_HOSTNAME=${OPTARG}
			;;
		d) DOMAIN=${OPTARG}
			;;
                w) WORKER_HOSTNAME=${OPTARG}
                        ;;
       		l) HANA_LOG_FILE=${OPTARG}
                        ;;
       	*)
            usage
            ;;
    esac
done


[ -e /root/install/config.sh ] && source /root/install/config.sh
[ -e /root/install/os.sh ] && source /root/install/os.sh


if (( $(isSLES12) == 1 )); then
	if [ -d "/home/ec2-user/media.cache" ]; then
		export ENABLE_FAST_DEBUG=1
	else
		export ENABLE_FAST_DEBUG=0
	fi
else
	export ENABLE_FAST_DEBUG=0
fi	


# ------------------------------------------------------------------
#          Build storage from storage.json
#		   First build a master script via generator code, then run it
# ------------------------------------------------------------------


MyInstanceType=$(/usr/local/bin/aws cloudformation describe-stacks --stack-name ${MyStackId}  --region ${REGION}  \
				| /root/install/jq '.Stacks[0].Parameters[] | select(.ParameterKey=="MyInstanceType") | .ParameterValue' \
				| sed 's/"//g')

MyVolumeType=$(/usr/local/bin/aws cloudformation describe-stacks --stack-name ${MyStackId}  --region ${REGION}  \
				| /root/install/jq '.Stacks[0].Parameters[] | select(.ParameterKey=="VolumeType") | .ParameterValue' \
				| sed 's/"//g')


 

STORAGE_SCRIPT=/root/install/storage_builder_generated_master.sh
python /root/install/build_storage.py  -config /root/install/storage.json  \
					     -ismaster ${IsMasterNode} \
					     -hostcount ${HostCount} -which backup \
					     -instance_type ${MyInstanceType} -storage_type ${BACKUP_VOL} \
					     > ${STORAGE_SCRIPT}
python /root/install/build_storage.py  -config /root/install/storage.json  \
					     -ismaster ${IsMasterNode} \
					     -hostcount ${HostCount} -which hana_data_log \
					     -instance_type ${MyInstanceType} -storage_type ${MyVolumeType} \
					     >> ${STORAGE_SCRIPT}
python /root/install/build_storage.py  -config /root/install/storage.json  \
					     -ismaster ${IsMasterNode} \
					     -hostcount ${HostCount} -which shared \
					     -instance_type ${MyInstanceType} -storage_type ${SHARED_VOL} \
					     >> ${STORAGE_SCRIPT}
python /root/install/build_storage.py  -config /root/install/storage.json  \
					     -ismaster ${IsMasterNode} \
					     -hostcount ${HostCount} -which usr_sap \
					     -instance_type ${MyInstanceType} -storage_type ${USR_SAP_VOL} \
					     >> ${STORAGE_SCRIPT}



# ------------------------------------------------------------------
#          Helper functions
#          log()
#          update_status()
#          create_volume()
#          set_noop_scheduler()
# ------------------------------------------------------------------

log() {
	echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

#Check if SIG_FLAG_FILE is present

if [ $(issignal_check) == 1 ]; then
    #Exit since there is a signal file
    log `date` "Exiting $0 script at `date` because $SIG_FLAG_FILE exists"
    exit 1
fi

update_status () {
   local status="$1"
   if [ "$status" ]; then
      if [ -e /root/install/cluster-watch-engine.sh ]; then
         sh /root/install/cluster-watch-engine.sh -s "$status"
      fi
   fi
}

create_volume () {
	if (( ${USE_NEW_STORAGE} == 1 )); then
		log `date` "Creating Physical Volumes for saphana volume group"
		#for i in {b..m}
		for i in {b..f}
		do
		  pvcreate /dev/xvd$i
		done
	fi
}


set_noop_scheduler () {
	log `date` "Setting i/o scheduler to noop for each physical volume"
	for i in `pvs | grep dev | awk '{print $1}' | sed s/\\\/dev\\\///`
	do
	  echo "noop" > /sys/block/$i/queue/scheduler
	  printf "$i: "
	  cat /sys/block/$i/queue/scheduler
	done

}



# ------------------------------------------------------------------
#          Make sure all input parameters are filled
# ------------------------------------------------------------------


[[ -z "$SID" ]]  && echo "input SID missing" && usage;
[[ -z "$INSTANCE" ]]  && echo "input INSTANCE missing" && usage;
[[ -z "$HANAPASSWORD" ]]  && echo "input HANAPASSWORD missing" && usage;
[[ -z "$MASTER_HOSTNAME" ]]  && echo "input MASTER_HOSTNAME missing" && usage;

shift $((OPTIND-1))

[[ $# -gt 0 ]] && usage;

# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
	HANA_LOG_FILE=/root/install/install.log
fi

if (( ${USE_NEW_STORAGE} == 1 ));
then
	log `date` "Using New Storage from storage.json"
	sh -x ${STORAGE_SCRIPT} >> ${HANA_LOG_FILE} 
	log `date` "END Storage from storage.json"
fi

echo `date` BEGIN install-master  2>&1 | tee -a ${HANA_LOG_FILE}

update_status "CONFIGURING_INSTANCE_FOR_HANA"
create_volume;
set_noop_scheduler;


logsize=",c3.8xlarge:244G,r3.2xlarge:244G,r3.4xlarge:244G,r3.8xlarge:244G,"
datasize=",c3.8xlarge:488G,r3.2xlarge:488G,r3.4xlarge:488G,r3.8xlarge:488G,"
sharedsize=",c3.8xlarge:244G,r3.2xlarge:244G,r3.4xlarge:244G,r3.8xlarge:244G,"
backupsize=",1:488G,2:976G,3:1464G,4:1952G,5:2440G,6:2928G,7:3416G,8:3904G,9:4392G,10:4880G,11:5368G,12:5856G,13:6344G,14:6832G,15:7320G,16:7808G,17:8296G,18:8784G,19:9272G,20:9760G,"


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
mybackupSize=$(get_backupsize  ${HostCount})

# ------------------------------------------------------------------
#          Create volume group vghana
#          Create Logical Volumes
#          Format filesystems
# ------------------------------------------------------------------

if (( ${USE_NEW_STORAGE} == 1 ));
then
	echo "Disabled old code."
	log `date` "Formatting block device for /usr/sap"
	mkfs.xfs -f /dev/xvds

	## 9.1 Create a new volume to store media.
	## This is where media bits will be downloaded from S3 and extracted
	sh -x /root/install/create-attach-single-volume.sh 50:gp2:/dev/sdz:HANA-MEDIA
	mkfs.xfs -f /dev/xvdz
	mkdir -p /media/
	mount /dev/xvdz /media/

else
	log `date` "Creating volume group vghana"
	#vgcreate vghana /dev/xvd{b..m}
	vgcreate vghana /dev/xvd{b..d}

	###7. Created a new volume group called vghanaback  (Master only)
	vgcreate vghanaback /dev/xvd{e..f}


	###8. Updated number of stripes to 3 for logical volumes created under volume group vghana (Both Master and Worker)

	lvcreate -n lvhanashared -i 3 -I 256 -L ${mysharedSize}  vghana
	log `date` "Creating hana data logical volume"
	lvcreate -n lvhanadata -i 3 -I 256  -L ${mydataSize} vghana
	log `date` "Creating hana log logical volume"
	lvcreate -n lvhanalog  -i 3 -I 256 -L ${mylogSize} vghana


	##9.Created a new logical volume called lvhanaback with 2 stripes (Master Only)
	log `date` "Creating backup logical volume"
	lvcreate -n lvhanaback  -i 2 -I 256  -L ${mybackupSize} vghanaback

	log `date` "Formatting block device for /usr/sap"
	mkfs.xfs -f /dev/xvds

	## 9.1 Create a new volume to store media.
	## This is where media bits will be downloaded from S3 and extracted
	mkfs.xfs -f /dev/xvdz
	mkdir -p /media/
	mount /dev/xvdz /media/
fi


# TODO: REMOVE THIS BEFORE LAUNCH
# ------------------------------------------------------------------
if (( ${ENABLE_FAST_DEBUG} == 1 ));	
then
	log `date` "WARNING !!!!!! FAST DEBUG ENABLED. NEED TO DISABLE THIS!"
	log `date` "BYPASSING S3 MEDIA DOWNLOAD"
	mkdir -p /media
	cp -r /home/ec2-user/media.cache /media
else
	log `date` "Downloading SAP HANA Media from S3: START"
	# Download media
	python ${SCRIPT_DIR}/download_media.py  -o /media/
	log `date` "Downloading SAP HANA Media from S3: END"
	# extract media

	log `date` "Extracting SAP HANA Media: START"
	sh ${SCRIPT_DIR}/extract.sh
	log `date` "Extracting SAP HANA Media: END"
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
mkdir -p /usr/sap
mkdir -p /media

mkdir -p /hana /hana/log /hana/data /hana/shared
mkdir -p /backup

log `date` "Creating SAP and HANA shared dir"
mkdir -p /shared
if (( ${USE_NEW_STORAGE} == 1 ));then
	mkfs.xfs -f /dev/xvde
	mount /dev/xvde /hana/shared/
fi

log `date` "Creating mount points in fstab"
echo "/dev/xvds /usr/sap   xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab

if (( ${USE_NEW_STORAGE} == 1 ));
then
	echo "/dev/xvde /hana/shared   xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
else
	echo "/dev/mapper/vghana-lvhanashared   /hana/shared   xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
fi
echo "/dev/mapper/vghana-lvhanadata     /hana/data     xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
echo "/dev/mapper/vghana-lvhanalog      /hana/log      xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
#echo "/dev/mapper/vghana-lvhanaback     /backup        xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab
if (( ${USE_NEW_STORAGE} == 1 ));then
	echo "/dev/xvdz /media   xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0"  >> /etc/fstab
else
	echo "/dev/xvdz1                        /media         ntfs rw,allow_other 0 0" >> /etc/fstab
fi

##10. Updated the fstab entry for /backup (Master only)
echo "/dev/mapper/vghanaback-lvhanaback     /backup        xfs nobarrier,noatime,nodiratime,logbsize=256k,delaylog 0 0" >> /etc/fstab


log `date` "mounting filesystems"
mount -a
mount


# ------------------------------------------------------------------
#          Creating additional directories
#          Activate LVM @boot
# ------------------------------------------------------------------

mkdir -p /hana/data/$SID /hana/log/$SID
mkdir -p  /usr/sap/$SID
mkdir -p /backup/data /backup/log /backup/data/$SID /backup/log/$SID

if (( $(isSLES) == 1 )); then
	log `date` "Turning on Activate of LVM at boot"
	chkconfig boot.lvm on
fi

# ------------------------------------------------------------------
#         Configure NFS exports 
# ------------------------------------------------------------------
##ensure nfs service starts on boot
if (( $(isSLES) == 1 )); then
        log `date` "Installing and configuring NFS Server"
        zypper --non-interactive install nfs-kernel-server
fi

sed -i '/STATD_PORT=/ c\STATD_PORT="4000"' /etc/sysconfig/nfs
sed -i '/LOCKD_TCPPORT=/ c\LOCKD_TCPPORT="4001"' /etc/sysconfig/nfs
sed -i '/LOCKD_UDPPORT=/ c\LOCKD_UDPPORT="4001"' /etc/sysconfig/nfs
sed -i '/MOUNTD_PORT=/ c\MOUNTD_PORT="4002"' /etc/sysconfig/nfs

if (( $(isSLES) == 1 )); then
        service nfsserver start
        chkconfig nfsserver on
else
        service nfs restart
        chkconfig nfs on
fi

echo "#Share global HANA shares" >> /etc/exports
if (( ${USE_NEW_STORAGE} == 1 )); then
        echo "/hana/shared   ${WORKER_HOSTNAME}*(rw,no_root_squash,no_subtree_check)" >> /etc/exports
else
        echo "/hana/shared   ${WORKER_HOSTNAME}*(rw,no_root_squash,no_subtree_check)" >> /etc/exports
fi
echo "/backup        ${WORKER_HOSTNAME}*(rw,no_root_squash,no_subtree_check)" >> /etc/exports
exportfs -a

log `date` "Current exports"
showmount -e

# ------------------------------------------------------------------
#          Pass through HANA installation
# ------------------------------------------------------------------

if [ "${INSTALL_HANA}" == "No" ]; then
    log `date` "INSTALL_HANA set to No, will pass through install-master.sh"
    exit 0
else
    log `date` "INSTALL_HANA set to Yes, Will install HANA via install-master.sh"
fi


# ------------------------------------------------------------------
#          Install HANA Master
# ------------------------------------------------------------------
update_status "INSTALLING_SAP_HANA"
sh ${SCRIPT_DIR}/install-hana-master.sh -p $HANAPASSWORD -s $SID -i $INSTANCE -n $MASTER_HOSTNAME -d $DOMAIN
update_status "PERFORMING_POST_INSTALL_STEPS"

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

log `date` END install-master

cat ${HANA_LOG_FILE} >> /var/log/messages

# Post installation: Install AWS Data provider
cd /root/install/
/usr/local/bin/aws s3 cp s3://aws-data-provider/bin/aws-agent_install.sh /root/install/aws-agent_install.sh
chmod +x aws-agent_install.sh
./aws-agent_install.sh



exit 0
