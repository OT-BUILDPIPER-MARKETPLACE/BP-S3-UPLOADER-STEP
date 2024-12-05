#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION

cd  "${WORKSPACE}"
TAG=$(tail -n 1 data.properties)
FILE_TO_BE_UPLOADED="${CODEBASE_DIR}"-"${TAG}".zip
FILE_KEY="${CODEBASE_DIR}"-"${TAG}".zip

logInfoMessage "Received below arguments"
logInfoMessage "File to be uploaded: ${FILE_TO_BE_UPLOADED}"
logInfoMessage "S3 Bucket: ${S3_BUCKET}"
logInfoMessage "Location of file in S3 Bucket: ${FILE_KEY}"

copyFileToS3 ${FILE_TO_BE_UPLOADED} ${S3_BUCKET} ${FILE_KEY}
#aws s3 cp "${FILE_TO_BE_UPLOADED}" s3://"${S3_BUCKET}"/"${FILE_KEY}"
TASK_STATUS=$?
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}