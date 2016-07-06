#
# ------------------------------------------------------------------
#         Signal PreCheck Failure
# ------------------------------------------------------------------


SCRIPT_DIR=/root/install/
if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

usage() {
    cat <<EOF
    Usage: $0
EOF
    exit 0
}

source /root/install/config.sh


# ------------------------------------------------------------------
#          Read all inputs
# ------------------------------------------------------------------


[[ $# -ne 0 ]] && usage;


log `date` signal-precheck-failure

curl -X PUT -H 'Content-Type:' --data-binary '{"Status" : "FAILURE","Reason" : "HANA Precheck failed. Possible reasons: Unable to connect to internet or OS repo is not reachable.","UniqueId" : "HANAMaster","Data" : "Failure"}' "${PreCheckValidationHandle}"
echo curl -X PUT -H 'Content-Type:' --data-binary '{"Status" : "FAILURE","Reason" : "HANA Precheck failed. Possible reasons: Unable to connect to intenet or OS repo could not be reached.","UniqueId" : "HANAMaster","Data" : "Failure"}' "${PreCheckValidationHandle}"

log `date` END signal-precheck-failure

exit 0








