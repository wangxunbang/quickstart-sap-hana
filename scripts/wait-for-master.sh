#!/bin/bash


# ------------------------------------------------------------------
# Wait until Master node updates it's status as MASTER_NODE_COMPLETE
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/
if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

log "WAITING FOR MASTER_NODE_COMPLETE..START"
sh /root/install/cluster-watch-engine.sh -w "MASTER_NODE_COMPLETE=1"
log "WAITING FOR MASTER_NODE_COMPLETE..END"
