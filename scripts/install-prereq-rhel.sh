#!/bin/bash

# ------------------------------------------------------------------
#         Global Variables 
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/
CLUSTERWATCH_SCRIPT=${SCRIPT_DIR}/ClusterWatchEngine.sh
MIN_KERN="310"
OSRELEASE="/etc/redhat-release"

# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
    if [ ! -d "/root/install/" ]; then
      mkdir -p "/root/install/"
    fi
    HANA_LOG_FILE=/root/install/install.log
fi

[ -e /root/install/config.sh ] && source /root/install/config.sh
[ -e /root/install/os.sh ] && source /root/install/os.sh

while getopts ":l:" o; do
    case "${o}" in
        l)
            HANA_LOG_FILE=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;


#***BEGIN Functions***

# ------------------------------------------------------------------
#
#          Install SAP HANA prerequisites (master node)
#
# ------------------------------------------------------------------


usage() {
    cat <<EOF
    Usage: $0 [options]
        -h print usage
        -l HANA_LOG_FILE [optional]
EOF
    exit 1
}

check_kernel() {

    KERNEL=$(uname -r | cut -c 1-4 | awk -F"." '{ print $1$2 }')

    if [ "$KERNEL" -gt "$MIN_KERN" ]
    then
    	echo 1
    else
    	echo 0
    fi
}

check_rhel() {

    RHEL=$(grep -i red "$OSRELEASE" )

    if [ "$RHEL" ]
    then
    	echo 1
    else
    	echo 0
    fi
}

check_yum() {
    
    YRM=$(yum -y remove gcc )
    YINST=$(yum -y install gcc | grep -i complete )

    if [ "$YINST" ]
    then
    	echo 1
    else
    	echo 0
    fi
}

check_instancetype() {
	INSTANCE_TYPE=$(curl http://169.254.169.254/latest/meta-data/instance-type 2> /dev/null )
	IS_IT_X1=$(echo $INSTANCE_TYPE | grep -i x1)    

	if [ "$IS_IT_X1" ]
	then
	    echo 1
	else
	    echo 0
	fi
}

# ------------------------------------------------------------------
#          Output log to HANA_LOG_FILE
# ------------------------------------------------------------------

log() {

    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}

#error check and return
}


# ------------------------------------------------------------------
#         Disable hostname reset via DHCP
# ------------------------------------------------------------------

disable_dhcp() {

    sed -i '/HOSTNAME/ c\HOSTNAME='$(hostname) /etc/sysconfig/network

#error check and return
}

# ------------------------------------------------------------------
#          Install all the pre-requisites for SAP HANA
# ------------------------------------------------------------------
install_prereq() {

    log "## Installing HANA Prerequisites...## "

    yum -y install xfsprogs 2>&1 | tee -a ${HANA_LOG_FILE}

    chkconfig nfs on
    service nfs restart

#error check and return
}

start_oss_configs() {

    #This section is from OSS #2247020 - SAP HANA DB: Recommended OS settings for RHEL 

    echo "###################" >> /etc/rc.d/rc.local 
    echo "#BEGIN: This section inserted by AWS SAP HANA Quickstart" >> /etc/rc.d/rc.local 

    #Disable THP
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.d/rc.local 

    echo 10 > /proc/sys/vm/swappiness
    echo "echo 10 > /proc/sys/vm/swappiness" >> /etc/rc.d/rc.local 

    #Disable KSM
    echo 0 > /sys/kernel/mm/ksm/run
    echo "echo 0 > /sys/kernel/mm/ksm/run" >> /etc/rc.d/rc.local 

    #NoHZ is not set

    #Disable SELINUX
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux 
    sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux

    #Disable AutoNUMA = N.A. for RHEL

    
    yum -y install gcc

    yum -y install compat-sap-c++

    X1=$(check_instancetype)

    if [ "$X1" -eq 1 ]
    then
	    #Set c-state
	    cpupower frequency-set -g performance > /dev/null
	    echo "cpupower frequency-set -g performance" >> /etc/init.d/boot.local
	  
	    #Stay in c-state 2 (Best Performance)
	    cpupower idle-set -d 6 > /dev/null; cpupower idle-set -d 5 > /dev/null
	    cpupower idle-set -d 4 > /dev/null; cpupower idle-set -d 3 > /dev/null
	    cpupower idle-set -d 2 > /dev/null; cpupower idle-set -d 1 > /dev/null
	    echo "cpupower idle-set -d 6 > /dev/null; cpupower idle-set -d 5 > /dev/null" >> /etc/init.d/boot.local 
	    echo "cpupower idle-set -d 4 > /dev/null; cpupower idle-set -d 3 > /dev/null" >> /etc/init.d/boot.local 
	    echo "cpupower idle-set -d 2 > /dev/null; cpupower idle-set -d 1 > /dev/null" >> /etc/init.d/boot.local 

	    echo "#END: This section inserted by AWS SAP HANA Quickstart" >> /etc/init.d/boot.local
	    echo "###################" >> /etc/init.d/boot.local
    fi

#error check and return
}

#***END Functions***

# ------------------------------------------------------------------
#         Code Body section 
# ------------------------------------------------------------------

#Call Functions

#Check if we are X1 instance type
X1=$(check_instancetype)

#Check the O.S. Version
KV=$(uname -r)

#Check to see if instance type is X1 and RHEL version is supported 
if [ $(check_kernel) == 0 -a $(check_instancetype) == 1 -a "$MyOS" == "RHEL66SAPHVM" ] 
then
    log "Calling signal-failure.sh from $0 @ `date` with INCOMPATIBLE_RHEL parameter"
    log "Instance Type = X1: $X1 and RHEL 6.6 is not supported with X1: $KV" 
    /root/install/signal-failure.sh "INCOMPATIBLE_RHEL" 
    touch "$SIG_FLAG_FILE"
    sleep 300
    exit 1
fi
# Check to see if RHEL 6.x is used with X1 scale out. 
if [ "$MyOS" == "RHEL67SAPHVM" -a $(check_instancetype) == 1 -a $HostCount -gt 1 ] 
then
    log "Calling signal-failure.sh from $0 @ `date` with INCOMPATIBLE_RHEL_SCALEOUT parameter"
    log "Instance Type = X1: $X1 and RHEL 6.7 is not supported with X1 Scaleout: $KV" 
    /root/install/signal-failure.sh "INCOMPATIBLE_RHEL_SCALEOUT" 
    touch "$SIG_FLAG_FILE"
    sleep 300
    exit 1
fi

#Check to see if yum repository is registered 
if [ $(check_yum) == 0 ] 
then
    log "Calling signal-failure.sh from $0 @ `date` with YUM parameter"
    log "Instance Type = X1: $X1 and yum repository is not correct." 
    /root/install/signal-failure.sh "YUM" 
    touch "$SIG_FLAG_FILE"
    sleep 300
    exit 1
fi

#Check to see if we are on RHEL 
if [ $(check_rhel) == 1 ] 
then
    log "Instance Type = X1: $X1 and Operating System is RHEL for SAP." 
    #Install unrar and exit
    # ------------------------------------------------------------------
    #   At the time of writing, marketplace RHEL and marketplace SUSE
    #   did not have unrar package. As a workaround, we download as below
    #   TODO: This is a temporary workaround and needs to be fixed in AMI
    # ------------------------------------------------------------------
    log "WARNING: Downloading from repoforge. Prefer prebaked AMIs"


    mkdir -p /root/install/misc
    wget http://www.rarlab.com/rar/unrar-5.0-RHEL5x64.tar.gz -O /root/install/misc/unrar-5.0-RHEL5x64.tar.gz
    (cd /root/install/misc && tar xvf /root/install/misc/unrar-5.0-RHEL5x64.tar.gz && chmod 755 /root/install/misc/unrar)

    disable_dhcp

    install_prereq

    start_oss_configs

    log "## Completed HANA Prerequisites installation ## "

    exit 0 
fi
