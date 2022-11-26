#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION

cd  "${CODEBASE_LOCATION}"

TASK_STATUS=0

if [ `isStrNonEmpty $S3_BUCKET` -ne 0 ]
then
    TASK_STATUS=1
    logErrorMessage "S3 buckets details are not provided please check"
elif [ `isStrNonEmpty ${FILE_TO_BE_UPLOADED}` -ne 0 ]
then
    TASK_STATUS=1
    logErrorMessage "File to be uploaded not provided please check"
elif [ `isFileExist ${FILE_TO_BE_UPLOADED}` -ne 0 ]
then
    TASK_STATUS=1
    logErrorMessage "File to be uploaded does not exists please check"
elif [ `bucketExist ${S3_BUCKET}` -ne 0 ]
then
    TASK_STATUS=1
    logErrorMessage "Unable to access S3 bucket either it doesn't exist or relevant permissions are not given please check!!!!"
elif [ `isStrNonEmpty ${FILE_KEY}` -ne 0 ]
then
    TASK_STATUS=1
    logErrorMessage "File key is not provided please check!!!!"
fi     

logInfoMessage "Received below arguments"
logInfoMessage "File to be uploaded: ${FILE_TO_BE_UPLOADED}"
logInfoMessage "S3 Bucket: ${S3_BUCKET}"
logInfoMessage "Location of file in S3 Bucket: ${FILE_KEY}"

copyFileToS3 ${FILE_TO_BE_UPLOADED} ${S3_BUCKET} ${FILE_KEY}
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}