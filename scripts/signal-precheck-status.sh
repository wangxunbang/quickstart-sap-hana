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
[ -e /root/install/os.sh ] && source /root/install/os.sh

# ------------------------------------------------------------------
#	For debug purpose disable validation
# ------------------------------------------------------------------

sh /root/install/signal-precheck-success.sh


# ------------------------------------------------------------------
#	Check S3 media is accessible and if it contains RAR/EXE files
#	Check zypper works and can pull from suse repo
#	If anyof these fail, signal failure to the CloudFormation
# ------------------------------------------------------------------


S3MEDIA=$(/usr/local/bin/aws cloudformation describe-stacks --stack-name  ${MyStackId}  --region ${REGION} \
	 	| /root/install/jq '.Stacks[0].Parameters' \
	 	| /root/install/jq '.[] | select(.ParameterKey == "HANAInstallMedia")' \
	 	| /root/install/jq '.ParameterValue' \
	 	| sed 's/"//g')

EXE_COUNT=$(/usr/local/bin/aws s3 ls ${S3MEDIA} | grep exe |wc -l)
RAR_COUNT=$(/usr/local/bin/aws s3 ls ${S3MEDIA} | grep rar |wc -l)

if [ $EXE_COUNT -eq 0 ]; 
then
	sh /root/install/signal-precheck-failure.sh
fi

if [ $RAR_COUNT -eq 0 ]; 
then
	sh /root/install/signal-precheck-failure.sh
fi


if (( $(isSLES12) == 1 )); then
	ZYPPER_WORKS=$(zypper lr | grep SLES12 | wc -l)
	if [ $ZYPPER_WORKS -eq 0 ]; 
	then
		sh /root/install/signal-precheck-failure.sh
	fi
elif (( $(isSLES12SP1) == 1 )); then
	ZYPPER_WORKS=$(zypper lr | grep SLES12 | wc -l)
	if [ $ZYPPER_WORKS -eq 0 ]; 
	then
		sh /root/install/signal-precheck-failure.sh
	fi
elif (( $(isSLES) == 1 )); then
	ZYPPER_WORKS=$(zypper lr | grep SLES11 | wc -l)
	if [ $ZYPPER_WORKS -eq 0 ]; 
	then
		sh /root/install/signal-precheck-failure.sh
	fi
fi

sh /root/install/signal-precheck-success.sh









