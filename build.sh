#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh

sleep  "$SLEEP_DURATION"
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
fi     

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}