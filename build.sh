#!/bin/bash

# Source common functions
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

# Enable Debugging if required
if [ "$DEBUG" = true ]; then
  set -x
fi

# Upload Function (like upload.sh)
uploadFile() {
if [ "${ASSUME_ROLE}" == "true" ]; then
    if [ $# -lt 2 ]; then
        logErrorMessage "Error: ACCOUNT_ID and ROLE_NAME arguments are required when ASSUME_ROLE=true"
        logInfoMessage "Usage: $0 ACCOUNT_ID ROLE_NAME"
        exit 1
    fi

    getAssumeRole "${ACCOUNT_ID}" "${ROLE_NAME}"
else
    logInfoMessage "ASSUME_ROLE is not set to 'true', skipping role assumption"
fi
  logInfoMessage "Starting Upload Task"
  logInfoMessage "CODEBASE_LOCATION: ${WORKSPACE}/${CODEBASE_DIR}"
  sleep $SLEEP_DURATION
  cd "${WORKSPACE}/${CODEBASE_DIR}"

  if [ "$LIST" = true ]; then
    ls -ltr
  fi

  logInfoMessage "FILE NAME: $FILE_NAME"
  logInfoMessage "BUCKET NAME: $S3_BUCKET"
  logInfoMessage "DESTINATION DIR: $DESTINATION_DIR"
  logInfoMessage "AWS PROFILE: $PROFILE"

if [ -n "$PROFILE" ]; then
    aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --recursive --profile "$PROFILE"
else
    aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --recursive
fi
  TASK_STATUS=$?
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

# Rename & Upload Function (like build-rename.sh)
renameAndUpload() {
if [ "${ASSUME_ROLE}" == "true" ]; then
    if [ $# -lt 2 ]; then
        logInfoMessage "Error: ACCOUNT_ID and ROLE_NAME arguments are required when ASSUME_ROLE=true"
        logInfoMessage "Usage: $0 ACCOUNT_ID ROLE_NAME"
        exit 1
    fi
    getAssumeRole "${ACCOUNT_ID}" "${ROLE_NAME}"
else
    logInfoMessage "ASSUME_ROLE is not set to 'true', skipping role assumption"
fi
  logInfoMessage "Starting Rename & Upload Task"
  cd "${WORKSPACE}/${CODEBASE_DIR}"
  tag=$(cat version)

  logInfoMessage "Old Artifact Name: [$ARTIFACT_OLD_NAME]"
  logInfoMessage "New Artifact Name: [$ARTIFACT_NEW_NAME]"
  mv "$ARTIFACT_PATH/$ARTIFACT_OLD_NAME" "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME"
  logInfoMessage "Artifact renamed successfully to: [${tag}-$ARTIFACT_NEW_NAME]"

  logInfoMessage "Uploading to S3 Bucket: ${S3_BUCKET}"

if [ -n "$PROFILE" ]; then
  aws s3 cp "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME" "${S3_BUCKET}" --profile "$PROFILE"
else
  aws s3 cp "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME" "${S3_BUCKET}" 
fi

  TASK_STATUS=$?
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

# Sync Function (like build-sync.sh)
syncToS3() {
if [ "${ASSUME_ROLE}" == "true" ]; then
    if [ $# -lt 2 ]; then
        logErrorMessage "Error: ACCOUNT_ID and ROLE_NAME arguments are required when ASSUME_ROLE=true"
        logInfoMessage "Usage: $0 ACCOUNT_ID ROLE_NAME"
        exit 1
    fi

    getAssumeRole "${ACCOUNT_ID}" "${ROLE_NAME}"
else
    logInfoMessage "ASSUME_ROLE is not set to 'true', skipping role assumption"
fi
  logInfoMessage "Starting Sync Task"
  cd "${WORKSPACE}/${CODEBASE_DIR}"
  logInfoMessage "File/Folder to sync: ${FILE_TO_BE_UPLOADED}"
  logInfoMessage "S3 Bucket: ${S3_BUCKET}"

if [ -n "$PROFILE" ]; then
  aws s3 sync "${FILE_TO_BE_UPLOADED}" "${S3_BUCKET}" --profile "$PROFILE"
else
  aws s3 sync "${FILE_TO_BE_UPLOADED}" "${S3_BUCKET}"
fi
  TASK_STATUS=$?
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

# Main execution with case options
operation="${OPERATION}"
case "$operation" in
  recursive)
    uploadFile
    ;;
  rename)
    renameAndUpload
    ;;
  sync)
    syncToS3
    ;;
  *)
    logInfoMessage "Usage: set OPERATION={recursive|rename|sync}"
    exit 1
    ;;
esac

#Runing comamnd
# docker run -it --rm -e WORKSPACE=/workspace -e CODEBASE_DIR=app -e FILE_NAME=check -e S3_BUCKET=s3-bps-bucket -e DESTINATION_DIR=uploads -e PROFILE=default -e OPERATION=recursive -v $(pwd):/workspace/app -v ~/.aws:/home/buildpiper/.aws <imagename>

