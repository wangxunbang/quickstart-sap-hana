#!/bin/bash

# ------------------------------------------------------------------
#          This script extracts media from /media/compressed
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

usage() {
    cat <<EOF
    Usage: $0 [options]
        -h print usage
EOF
    exit 1
}

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

command_exists () {
    type "$1" &> /dev/null ;
}

EXTRACT_DIR=/media/extracted/
COMPRESS_DIR=/media/compressed/
source /root/install/config.sh
EXE=$(/usr/bin/find ${COMPRESS_DIR}  -name '*.exe')

mkdir -p ${EXTRACT_DIR}

if command_exists unrar ; then
	/usr/bin/unrar x ${EXE} ${EXTRACT_DIR}
else

# ------------------------------------------------------------------
#   At the time of writing, marketplace RHEL and marketplace SLES 
#	did not have unrar package. As a workaround, we download as below
#   TODO: This is a temporary workaround and needs to be fixed in AMI
# ------------------------------------------------------------------
	log "WARNING: Downloading from repoforge. Prefer prebaked AMIs"


	mkdir -p /root/install/misc
	wget http://www.rarlab.com/rar/unrar-5.0-RHEL5x64.tar.gz -O /root/install/misc/unrar-5.0-RHEL5x64.tar.gz 
	(cd /root/install/misc && tar xvf /root/install/misc/unrar-5.0-RHEL5x64.tar.gz && chmod 755 /root/install/misc/unrar)
	/root/install/misc/unrar x ${EXE} ${EXTRACT_DIR}

	#wget http://pkgs.repoforge.org/unrar/unrar-5.0.3-1.el6.rf.x86_64.rpm -O /root/install/misc/unrar-5.0.3-1.el6.rf.x86_64.rpm
	#rpm -i /root/install/misc/unrar-5.0.3-1.el6.rf.x86_64.rpm
	#/usr/bin/unrar x ${EXE} ${EXTRACT_DIR}
fi
