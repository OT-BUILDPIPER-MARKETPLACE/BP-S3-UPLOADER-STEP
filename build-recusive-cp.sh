#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

# Optionally enable debugging
if [ "$DEBUG" = true ]; then
  set -x  
fi

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION

cd  "${CODEBASE_LOCATION}"

if [ "$LIST" = true ]; then
  ls -ltr  
fi

logInfoMessage "FILE NAME: $FILE_NAME"
logInfoMessage "BUCKET NAME: $S3_BUCKET"
logInfoMessage "DESTINATION DIR: $DESTINATION_DIR"
logInfoMessage "AWS PROFILE:${PROFILE}"
    
    # Update the Glue job
    aws s3 cp ${FILE_NAME} s3://${S3_BUCKET}/${DESTINATION_DIR} \
    --recursive \
    --profile "$PROFILE"

TASK_STATUS=$?
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}