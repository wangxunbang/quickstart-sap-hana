#!/bin/bash

# ------------------------------------------------------------------
#         Global Variables 
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/
CLUSTERWATCH_SCRIPT=${SCRIPT_DIR}/ClusterWatchEngine.sh
MIN_KERN="310"
OSRELEASE="/etc/os-release"

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

check_zypper() {
    
    ZRM=$(zypper -n remove cpupower )
    ZINST=$(zypper -n install cpupower | grep done )

    if [ "$ZINST" ]
    then
    	echo 1
    else
    	echo 0
    fi
}

check_slesforsap() {

    SLESFORSAP=$(grep -i sap "$OSRELEASE" )

    if [ "$SLESFORSAP" ]
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

    sed -i '/DHCLIENT_SET_HOSTNAME/ c\DHCLIENT_SET_HOSTNAME="no"' /etc/sysconfig/network/dhcp
    #restart network
    service network restart

    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh  | tee -a ${HANA_LOG_FILE}

#error check and return
}


disable_hostname() {

    sed -i '/preserve_hostname/ c\preserve_hostname: true' /etc/cloud/cloud.cfg

#error check and return
}

# ------------------------------------------------------------------
#          Install all the pre-requisites for SAP HANA
# ------------------------------------------------------------------
install_prereq() {

    log "## Installing HANA Prerequisites...## "

    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper se xulrunner  | tee -a ${HANA_LOG_FILE}
    zypper -n install ntp  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}


# ------------------------------------------------------------------
# In order to install SAP HANA on SLES 12 or SLES 12 for SAP Applications 
# please refer also to SAP note "1944799 SAP HANA Guidelines for SLES Operating System installation".
# For running SAP HANA you may need libopenssl version 0.9.8. 
# This version of libopenssl is provided with the so called Legacy Module of SLE 12. When you added the software repository as described above install you can install the libopenssl 0.9.8 via zypper, yast2 etc. e.g. by calling
# ------------------------------------------------------------------

    if [ $(isSLES12) == 1  -o  $(isSLES12SP1) == 1 ]
    then
	zypper -n in libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
    fi

# ------------------------------------------------------------------
#          Install unrar for media extraction
# ------------------------------------------------------------------

    zypper -n install unrar  | tee -a ${HANA_LOG_FILE}

#SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}

    chkconfig boot.kdump  | tee -a ${HANA_LOG_FILE}
    chkconfig kdump off
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

    #ipcs -l  | tee -a ${HANA_LOG_FILE}
    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}


#error check and return
}

# ------------------------------------------------------------------
#          Start ntp server
# ------------------------------------------------------------------

start_ntp() {

     echo "server 0.pool.ntp.org" >> /etc/ntp.conf
     echo "server 1.pool.ntp.org" >> /etc/ntp.conf
     echo "server 2.pool.ntp.org" >> /etc/ntp.conf
     echo "server 3.pool.ntp.org" >> /etc/ntp.conf
     service ntp start  | tee -a ${HANA_LOG_FILE}
     chkconfig ntp on  | tee -a ${HANA_LOG_FILE}

#error check and return
}

# ------------------------------------------------------------------
#          Issue: /hana/shared not getting mounted
# ------------------------------------------------------------------

start_fs() {

     chkconfig autofs on

#error check and return
}


start_oss_configs() {

    #This section is from OSS #2205917 - SAP HANA DB: Recommended OS settings for SLES 12 / SLES for SAP Applications 12
    #and OSS #2292711 - SAP HANA DB: Recommended OS settings for SLES 12 SP1 / SLES for SAP Applications 12 SP1 

    zypper remove ulimit > /dev/null
   

    echo "###################" >> /etc/init.d/boot.local
    echo "#BEGIN: This section inserted by AWS SAP HANA Quickstart" >> /etc/init.d/boot.local

    #Disable THP
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/init.d/boot.local

    echo 10 > /proc/sys/vm/swappiness
    echo "echo 10 > /proc/sys/vm/swappiness" >> /etc/init.d/boot.local

    #Disable KSM
    echo 0 > /sys/kernel/mm/ksm/run
    echo "echo 0 > /sys/kernel/mm/ksm/run" >> /etc/init.d/boot.local

    #NoHZ is not set

    #Disable AutoNUMA
    echo 0 > /proc/sys/kernel/numa_balancing
    echo "echo 0 > /proc/sys/kernel/numa_balancing" >> /etc/init.d/boot.local

    
    zypper -n install gcc

    zypper install libgcc_s1 libstdc++6

    X1=$(check_instancetype)

    # if [ "$X1" -eq 1 ]
    # then
	   #  #Set c-state
	   #  cpupower frequency-set -g performance > /dev/null
	   #  echo "cpupower frequency-set -g performance" >> /etc/init.d/boot.local
	  
	   #  #Stay in c-state 2 (Best Performance)
	   #  cpupower idle-set -d 6 > /dev/null; cpupower idle-set -d 5 > /dev/null
	   #  cpupower idle-set -d 4 > /dev/null; cpupower idle-set -d 3 > /dev/null
	   #  cpupower idle-set -d 2 > /dev/null; cpupower idle-set -d 1 > /dev/null
	   #  echo "cpupower idle-set -d 6 > /dev/null; cpupower idle-set -d 5 > /dev/null" >> /etc/init.d/boot.local 
	   #  echo "cpupower idle-set -d 4 > /dev/null; cpupower idle-set -d 3 > /dev/null" >> /etc/init.d/boot.local 
	   #  echo "cpupower idle-set -d 2 > /dev/null; cpupower idle-set -d 1 > /dev/null" >> /etc/init.d/boot.local 

	   #  echo "#END: This section inserted by AWS SAP HANA Quickstart" >> /etc/init.d/boot.local
	   #  echo "###################" >> /etc/init.d/boot.local
    # fi

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

#Check to see if instance type is X1 and Kernel version is supported 
if [ $(check_kernel) == 0 -a $(check_instancetype) == 1 ] 
then
    log "Calling signal-failure.sh from $0 @ `date` with INCOMPATIBLE parameter"
    log "Instance Type = X1: $X1 and O.S. is not supported with X1: $KV" 
    /root/install/signal-failure.sh "INCOMPATIBLE" 
    touch "$SIG_FLAG_FILE"
    sleep 300
    exit 1
fi

#Check to see if zypper repository is registered 
if [ $(check_zypper) == 0 ] 
then
    log "Calling signal-failure.sh from $0 @ `date` with ZYPPER parameter"
    log "Instance Type = X1: $X1 and zypper repository is not correct." 
    /root/install/signal-failure.sh "ZYPPER" 
    touch "$SIG_FLAG_FILE"
    sleep 300
    exit 1
fi

#Check to see if we are on SLESFORSAP 
if [ $(check_slesforsap) == 1 ] 
then
    log "Instance Type = X1: $X1 and Operating System is SLES for SAP." 
    #Install unrar and exit
    # ------------------------------------------------------------------
    #   At the time of writing, marketplace RHEL and marketplace SLES
    #       did not have unrar package. As a workaround, we download as below
    #   TODO: This is a temporary workaround and needs to be fixed in AMI
    # ------------------------------------------------------------------
    log "WARNING: Downloading from repoforge. Prefer prebaked AMIs"


    mkdir -p /root/install/misc
    wget http://www.rarlab.com/rar/unrar-5.0-RHEL5x64.tar.gz -O /root/install/misc/unrar-5.0-RHEL5x64.tar.gz
    (cd /root/install/misc && tar xvf /root/install/misc/unrar-5.0-RHEL5x64.tar.gz && chmod 755 /root/install/misc/unrar)
    exit 0
fi

disable_dhcp

disable_hostname

install_prereq

start_ntp 

start_fs 

start_oss_configs

log "## Completed HANA Prerequisites installation ## "

exit 0 
