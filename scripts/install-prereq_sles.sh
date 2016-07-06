#!/bin/bash

# ------------------------------------------------------------------
#         Global Variables 
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/
CLUSTERWATCH_SCRIPT=${SCRIPT_DIR}/ClusterWatchEngine.sh

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

check_issles12() {
    SUSE12=$(isSUSE12)
    SUSE12SP1=$(isSUSE12SP1)

    if [ "$SUSE12" -eq 1 -o "$SUSE12SP1" -eq 1 ]
    then
    	echo 1
    else
    	echo 0
    fi
}

check_zypper() {
    echo

}

check_instancetype() {
	INSTANCE_TYPE=$(curl http://169.254.169.254/latest/meta-data/instance-type 2> /dev/null )
	IS_IT_X1=$(echo $INSTANCE_TYPE | grep -i x1)    

	if [ "IS_IT_X1" ]
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

#   SUSE 12 installation fails with libnuma
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

    if [ "$X1" -eq 1 ]
    then
	    #Set c-state
	    cpupower frequency-set -g performance > /dev/null
	    echo "cpupower frequency-set -g performance" >> /etc/init.d/boot.local
	  
	    #Stay in c-state 2 (Best Performance)
	    cpupower idle-set -d 6 > /dev/null; cpupower idle-set -d 5 > /dev/null
	    cpupower idle-set -d 4 > /dev/null; cpupower idle-set -d 3 > /dev/null
	    echo "cpupower idle-set -d 6 > /dev/null; cpupower idle-set -d 5 > /dev/null" >> /etc/init.d/boot.local 
	    echo "cpupower idle-set -d 4 > /dev/null; cpupower idle-set -d 3 > /dev/null" >> /etc/init.d/boot.local 

	     echo "#END: This section inserted by AWS SAP HANA Quickstart" >> /etc/init.d/boot.local
	     echo "###################" >> /etc/init.d/boot.local
	fi

#error check and return
}



#



# ------------------------------------------------------------------
# In order to install SAP HANA on SLES 12 or SLES 12 for SAP Applications 
# please refer also to SAP note "1944799 SAP HANA Guidelines for SLES Operating System installation".
# For running SAP HANA you may need libopenssl version 0.9.8. 
# This version of libopenssl is provided with the so called Legacy Module of SLE 12. When you added the software repository as described above install you can install the libopenssl 0.9.8 via zypper, yast2 etc. e.g. by calling
# ------------------------------------------------------------------

#Why is this here? Same code twice???
#if (( $(isSUSE12) == 1 )); then
#	zypper -n in libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
#fi

#if (( $(isSUSE12SP1) == 1 )); then
#	zypper -n in libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
#fi


# ------------------------------------------------------------------
#          Create Volumes
# ------------------------------------------------------------------

#sh /root/install/configureVol.sh


# ------------------------------------------------------------------
#          Install unrar for media extraction
# ------------------------------------------------------------------

#    zypper -n install unrar  | tee -a ${HANA_LOG_FILE}

#***END Functions***

# ------------------------------------------------------------------
#         Code Body section 
# ------------------------------------------------------------------

#Call Functions

#Check if we are X1 instance type
X1=$(check_instancetype)

#Check the O.S. Version
SLES=$(check_issles12)

#Check to see if instance type is X1 and O.S. version is not SLES 12
if [ $(check_issles12) == 0 -a $(check_instancetype) == 1 ] 
then
    /root/install/signal-failure.sh
    echo "Instance Type = X1: $X1 and O.S. is not SLES 12: $SLES" | tee -a ${HANA_LOG_FILE}
    exit 1
fi

disable_dhcp

disable_hostname

install_prereq

start_ntp 

start_fs 

start_oss_configs

log "## Completed HANA Prerequisites installation ## "

exit 0 


:<<COMMENT

# ------------------------------------------------------------------
#         Karthik's original below 
# ------------------------------------------------------------------

# ------------------------------------------------------------------
#         Disable hostname reset via DHCP
# ------------------------------------------------------------------

if (( $(isRHEL) == 1 )); then
    sed -i '/HOSTNAME/ c\HOSTNAME='$(hostname) /etc/sysconfig/network
    yum install gcc
else
    sed -i '/DHCLIENT_SET_HOSTNAME/ c\DHCLIENT_SET_HOSTNAME="no"' /etc/sysconfig/network/dhcp
    #restart network
    service network restart

    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh  | tee -a ${HANA_LOG_FILE}
fi




# ------------------------------------------------------------------
#          Install all the pre-requisites for SAP HANA
# ------------------------------------------------------------------

log "## Installing HANA Prerequisites...## "

if (( $(isRHEL) == 1 )); then
    yum -y install xfsprogs | tee -a ${HANA_LOG_FILE}
else
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

#   SUSE 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}

    chkconfig boot.kdump  | tee -a ${HANA_LOG_FILE}
    chkconfig kdump off
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}
fi

#ipcs -l  | tee -a ${HANA_LOG_FILE}
#echo "kernel.shmmni=65536" >> /etc/sysctl.conf
#sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

# ------------------------------------------------------------------
#          Start ntp server
# ------------------------------------------------------------------

echo "server 0.pool.ntp.org" >> /etc/ntp.conf
echo "server 1.pool.ntp.org" >> /etc/ntp.conf
echo "server 2.pool.ntp.org" >> /etc/ntp.conf
echo "server 3.pool.ntp.org" >> /etc/ntp.conf
service ntp start  | tee -a ${HANA_LOG_FILE}
chkconfig ntp on  | tee -a ${HANA_LOG_FILE}

# ------------------------------------------------------------------
#          Issue: /hana/shared not getting mounted
# ------------------------------------------------------------------

chkconfig autofs on

if (( $(isRHEL) == 1 )); then
    chkconfig nfs on
    service nfs restart
fi

# ------------------------------------------------------------------
#          We need ntfs-3g to mount Windows drive
# ------------------------------------------------------------------
if (( $(isRHEL) == 1 )); then
    yum group install "Development Tools"
#    wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/media/ntfs-3g-2014.2.15-8.el6.x86_64.rpm

#   rpm -ivh ntfs-3g-2014.2.15-8.el6.x86_64.rpm
#    rm -rf ntfs-3g-2014.2.15-8.el6.x86_64.rpm
    wget http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
    rpm -ivh epel-release-6-8.noarch.rpm
    yum -y --enablerepo=epel install ntfs-3g
else
    zypper -n install ntfs-3g  | tee -a ${HANA_LOG_FILE}
    zypper install libgcc_s1 libstdc++6
    zypper remove ulimit
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/init.d/boot.local
fi

log "## Completed HANA Prerequisites installation ## "

if (( $(isSUSE) == 1 )); then
    #USE_OPENSUSE_NTFS=1
    if [ -z "${USE_OPENSUSE_NTFS}" ] ; then
    	zypper -n install gcc
    ##	wget http://tuxera.com/opensource/ntfs-3g_ntfsprogs-2014.2.15.tgz
    	wget https://s3.amazonaws.com/quickstart-reference/sap/hana/latest/media/ntfs-3g_ntfsprogs-2014.2.15.tgz
    	tar -zxvf ntfs-3g_ntfsprogs-2014.2.15.tgz
    	(cd ntfs-3g_ntfsprogs-2014.2.15 && ./configure)
    	(cd ntfs-3g_ntfsprogs-2014.2.15 && make)
    	(cd ntfs-3g_ntfsprogs-2014.2.15 && make install)
    	rm -rf ntfs-3g_ntfsprogs-2014.2.15*
    else
    	###Need to check the best way to install ntfs
    	zypper ar "http://download.opensuse.org/repositories/filesystems/SLE_11_SP2/" "filesystems"
    	zypper  install ntfs-3g
    fi

    sed -i '/preserve_hostname/ c\preserve_hostname: true' /etc/cloud/cloud.cfg
fi


# ------------------------------------------------------------------
#          Install unrar for media extraction
# ------------------------------------------------------------------

if (( $(isRHEL) == 1 )); then
    yum install unrar
else
    zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
fi


# ------------------------------------------------------------------
# In order to install SAP HANA on SLES 12 or SLES 12 for SAP Applications 
# please refer also to SAP note "1944799 SAP HANA Guidelines for SLES Operating System installation".
# For running SAP HANA you may need libopenssl version 0.9.8. 
# This version of libopenssl is provided with the so called Legacy Module of SLE 12. When you added the software repository as described above install you can install the libopenssl 0.9.8 via zypper, yast2 etc. e.g. by calling
# ------------------------------------------------------------------

if (( $(isSUSE12) == 1 )); then
	zypper -n in libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
fi

if (( $(isSUSE12SP1) == 1 )); then
	zypper -n in libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
fi


# ------------------------------------------------------------------
#          Create Volumes
# ------------------------------------------------------------------

sh /root/install/configureVol.sh



exit 0

COMMENT
