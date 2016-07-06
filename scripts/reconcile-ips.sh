#!/bin/bash


source /root/install/config.sh
source /root/install/os.sh


# ------------------------------------------------------------------
#     Front to python code
# ------------------------------------------------------------------

usage() { 
    cat <<EOF
    Usage: $0 <HostCount>
EOF
    exit 1
}

[[ $# -ne 1 ]] && usage;

SCRIPT_DIR=/root/install/
if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

nWorkers=$1

log "Enter reconcile-ips.sh "
#Check if SIG_FLAG_FILE is present

if [ $(issignal_check) == 1 ]
then
    #Exit since there is a signal file
    log "Exiting $0 script at `date` because $SIG_FLAG_FILE exists"
    exit 1
fi

echo "" >> /etc/hosts
/usr/local/aws/bin/python /root/install/reconcile-ips.py -c ${nWorkers}
echo "" >> /etc/hosts

log "Exit reconcile-ips.sh "
