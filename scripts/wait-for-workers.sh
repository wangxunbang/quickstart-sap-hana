#!/bin/bash


# ------------------------------------------------------------------
# Wait until Worker nodes to complete "WORKER_NODES_COMPLETE" state
# Input total number of HANA hosts. We take 1 for master away
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
let nWorkers=nWorkers-1

[[ ${nWorkers} -eq 0 ]] && exit 0;


log "WAITING FOR ALL WORKER_NODE_COMPLETE..START"
sh /root/install/cluster-watch-engine.sh -w "WORKER_NODE_COMPLETE=${nWorkers}"
log "WAITING FOR ALL WORKER_NODE_COMPLETE..END"
