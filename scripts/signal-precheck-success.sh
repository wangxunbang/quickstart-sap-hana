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


log `date` signal-precheck-success

curl -X PUT -H 'Content-Type:' --data-binary '{"Status" : "SUCCESS","Reason" : "HANA PreCheck validation complete!","UniqueId" : "HANAMaster","Data" : "Complete"}' "${PreCheckValidationHandle}"
echo curl -X PUT -H 'Content-Type:' --data-binary '{"Status" : "SUCCESS","Reason" : "HANA PreCheck validation complete!","UniqueId" : "HANAMaster","Data" : "Complete"}' "${PreCheckValidationHandle}"

log `date` END signal-precheck-success

exit 0








