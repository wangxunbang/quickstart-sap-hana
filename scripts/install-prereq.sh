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


#***BEGIN Functions***

# ------------------------------------------------------------------
#          Output log to HANA_LOG_FILE
# ------------------------------------------------------------------

log() {

    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}

#error check and return
}


#***END Functions***

# ------------------------------------------------------------------
#         Code Body section 
# ------------------------------------------------------------------

#Execute the RHEL or SLES install pre-requisite script based on O.S. type
if (( $(isRHEL) == 1 )); then
     echo "Executing  /root/install/install-prereq-rhel.sh @ `date`" | tee -a ${HANA_LOG_FILE}
     /root/install/install-prereq-rhel.sh 
else
     echo "Executing  /root/install/install-prereq-sles.sh @ `date`" | tee -a ${HANA_LOG_FILE}
     /root/install/install-prereq-sles.sh 
fi

