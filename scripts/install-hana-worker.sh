#!/bin/bash


# ------------------------------------------------------------------
#          This script installs HANA worker node
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

usage() {
    cat <<EOF
    Usage: $0 [options]
        -h print usage
        -p HANA MASTER PASSWD
        -s SID
        -n MASTER HOSTNAME
        -d DOMAIN
        -l HANA_LOG_FILE [optional]
EOF
    exit 1
}

# ------------------------------------------------------------------
#          Read all inputs
# ------------------------------------------------------------------

export USE_NEW_STORAGE=1


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


# ------------------------------------------------------------------
#          Make sure all input parameters are filled
# ------------------------------------------------------------------

[[ -z "$HANAPASSWORD" ]]  && echo "input HANAPASSWORD missing" && usage;
[[ -z "$SID" ]]  && echo "input SID missing" && usage;
[[ -z "$MASTER_HOSTNAME" ]]  && echo "input MHOSTNAME missing" && usage;
[[ -z "$DOMAIN" ]]  && echo "input DOMAIN Name missing" && usage;
shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;

[ -e /root/install/config.sh ] && source /root/install/config.sh
[ -e /root/install/os.sh ] && source /root/install/os.sh




# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi


log() {
  echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}


log `date` BEGIN install-hana-worker


# ------------------------------------------------------------------
#          Helper functions
#          install_worker()
#          retry_mount()
# ------------------------------------------------------------------


retry_mount() {
  log `date` "Retrying /hana/share mount"
  service autofs restart
  if [ ! -e ${HDBLCM} ]; then
  	if (( ${USE_NEW_STORAGE} == 1 )); then
	     mount -t nfs $MASTER_HOSTNAME.$DOMAIN:/hana/shared /hana/shared
	 else
	     mount -t nfs $MASTER_HOSTNAME.$DOMAIN:/hana/shared /hana/shared
	 fi
     mount -t nfs $MASTER_HOSTNAME.$DOMAIN:/backup /backup
  log `date` "Hard mounted NFS mounts, consider adding to /etc/fstab"
  fi
}

if (( ${USE_NEW_STORAGE} == 1 )); then
	MISC_CFG_DIR=/hana/shared/$SID/aws/
	MISC_CFG_FILE=/hana/shared/$SID/aws/awscfg.sh
else
	MISC_CFG_DIR=/hana/shared/$SID/aws/
	MISC_CFG_FILE=/hana/shared/$SID/aws/awscfg.sh
fi

wait_until_shared_dir_ready() {
    while true
    do
        retry_mount
        log `date` "Waiting for shared dir ${MISC_CFG_DIR}"
        if [ ! -d "$MISC_CFG_DIR" ]; then
            /bin/sleep 10
        else
            echo "Shared dir ${MISC_CFG_DIR} is available "
            break
        fi
    done
}

wait_until_shared_cfg_ready() {
    #mount  -t nfs4  $MASTER_HOSTNAME.local:/hana/shared /hana/shared/
    while true
    do
        retry_mount
        log `date` "Waiting for shared file ${MISC_CFG_FILE}"
        if [ ! -f "$MISC_CFG_FILE" ]; then
            /bin/sleep 10
        else
            echo "Shared file ${MISC_CFG_FILE} is available "
            break
        fi
    done
    #
    source ${MISC_CFG_FILE}
    log `date` "Worker found Master used ${SAPSYS_GROUPID} as group id."
}


install_worker() {

	# loop until shared is available, then pick the gid, use below
    wait_until_shared_dir_ready
    wait_until_shared_cfg_ready
    # Use SAPSYS_GROUPID from master

	#if (( $(isRHEL) == 1 )); then
	  groupadd sapsys -g ${SAPSYS_GROUPID}
	#fi

	if (( ${USE_NEW_STORAGE} == 1 )); then
		HDBLCM=/hana/shared/$SID/hdblcm/hdblcm
	else
		HDBLCM=/hana/shared/$SID/hdblcm/hdblcm
	fi

	#fix permissions for install
	chmod 777 /hana/log/$SID /hana/data/$SID

	#Hostagent
	#if [ -e ${HOSTAGENT} ]; then
	#    log "Installing Host Agent"
	#    rpm -i ${HOSTAGENT}
	#    service sapinit start
	#fi

	sid=`echo ${SID} | tr '[:upper:]' '[:lower:]'}`
	if (( ${USE_NEW_STORAGE} == 1 )); then
		HOSTAGENT=/hana/shared/$SID/global/hdb/saphostagent_setup/saphostexec
	else
		HOSTAGENT=/hana/shared/$SID/global/hdb/saphostagent_setup/saphostexec
	fi
	if [ -e ${HOSTAGENT} ]; then
	    log `date` "Installing Host Agent"
	    ${HOSTAGENT} -install
	    service sapinit start
	fi

	if [ -e ${HDBLCM} ]; then
	#    ${HDBADDHOST} --role=worker --sapmnt=/hana/shared --password=$HANAPASSWORD --sid=$SID
		MYHOSTNAME=$(hostname)
		${HDBLCM} --action=add_hosts  --addhosts=${MYHOSTNAME} --password=$HANAPASSWORD --sapadm_password=$HANAPASSWORD --sid=$SID --batch
	    return 0
	  else
	    log `date` "${HDBLCM} program not available, ensure /hana/shared is mounted from $MASTER_HOSTNAME"
	    return 1
	 fi

	#Remove Password file
	#rm $PASSFILE

	#Fix permissions after install
	chmod 755 /hana/data/$SID /hana/log/$SID
}





# ------------------------------------------------------------------
#          Main install code
# ------------------------------------------------------------------


if install_worker; then
   log `date` "Host Added..."
 else
   if retry_mount; then
      if install_worker; then
         log `date` "Host Added..."
      fi
   else
      log `date` "Unable to mount /hana/shared filesystem from $MASTER_HOSTNAME"
   fi
fi

#log "$(date) __ changing the mode of the HANA folder..."
#hdb=`echo ${SID} | tr '[:upper:]' '[:lower:]'}`
#adm="${hdb}adm"

#chown ${adm}:sapsys -R /hana/data/${SID}
#chown ${adm}:sapsys -R /hana/log/${SID}

#set password for sapadm user
echo -e "$HANAPASSWORD\n$HANAPASSWORD" | (passwd --stdin sapadm)

#chmod 775 /usr/sap/hostctrl/work
#chmod 770 /usr/sap/hostctrl/work/sapccmsr

log `date` "Restarting host agent"
/usr/sap/hostctrl/exe/saphostexec -restart

log `date` END install-hana-worker

exit 0
