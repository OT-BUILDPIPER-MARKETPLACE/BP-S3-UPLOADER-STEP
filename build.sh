#!/bin/bash

# Source common functions
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh


if [ "$DEBUG" = true ]; then
  set -x
fi

sleep "${SLEEP_DURATION}"

if [ -n "$SLEEP_DURATION" ]; then
logInfoMessage "set sleep $SLEEP_DURATION "
fi

logInfoMessage "Chnage the dir ${WORKSPACE}/${CODEBASE_DIR}"
cd "${WORKSPACE}/${CODEBASE_DIR}"

uploadSingleFile() {
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
  logInfoMessage "Starting Upload single file task"
  logInfoMessage "CODEBASE_LOCATION: ${WORKSPACE}/${CODEBASE_DIR}"

  if [ -n "$PROFILE" ]; then
    logInfoMessage "aws s3 cp ${FILE_NAME} s3://${S3_BUCKET}/${DESTINATION_DIR}/ --profile $PROFILE"
    aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}/" --profile "$PROFILE"
  else
    logInfoMessage "aws s3 cp ${FILE_NAME} s3://${S3_BUCKET}/${DESTINATION_DIR}/"
    aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}/"
  fi
}


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

  if [ "$LIST" = true ]; then
    ls -ltr
  fi

  logInfoMessage "FILE NAME: $FILE_NAME"
  logInfoMessage "BUCKET NAME: $S3_BUCKET"
  logInfoMessage "DESTINATION DIR: $DESTINATION_DIR"

if [ -n "$PROFILE" ]; then
    logInfoMessage "AWS PROFILE: $PROFILE"
    logInfoMessage "aws s3 cp ${FILE_NAME} s3://${S3_BUCKET}/${DESTINATION_DIR} --recursive --profile $PROFILE"
    aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --recursive --profile "$PROFILE"
else
    logInfoMessage "aws s3 cp ${FILE_NAME} s3://${S3_BUCKET}/${DESTINATION_DIR} --recursive"
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
  tag=$(cat version)

  logInfoMessage "Old Artifact Name: [$ARTIFACT_OLD_NAME]"
  logInfoMessage "New Artifact Name: [$ARTIFACT_NEW_NAME]"
  logInfoMessage "Move from $ARTIFACT_PATH/$ARTIFACT_OLD_NAME to $ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME"
  mv "$ARTIFACT_PATH/$ARTIFACT_OLD_NAME" "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME"
  logInfoMessage "Artifact renamed successfully to: [${tag}-$ARTIFACT_NEW_NAME]"
  logInfoMessage "DESTINATION DIR: $DESTINATION_DIR"
  logInfoMessage "Uploading to S3 Bucket: ${S3_BUCKET}"

if [ -n "$PROFILE" ]; then
  logInfoMessage "AWS PROFILE: $PROFILE"
  logInfoMessage "aws s3 cp $ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME s3://${S3_BUCKET}/${DESTINATION_DIR} --profile $PROFILE"
  aws s3 cp "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --profile "$PROFILE"
else
  logInfoMessage "aws s3 cp $ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME s3://${S3_BUCKET}/${DESTINATION_DIR}"
  aws s3 cp "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME" "s3://${S3_BUCKET}/${DESTINATION_DIR}" 
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
  logInfoMessage "File/Folder to sync: ${FILE_TO_BE_UPLOADED}"
  logInfoMessage "S3 Bucket: ${S3_BUCKET}"
  logInfoMessage "DESTINATION DIR: $DESTINATION_DIR"

if [ -n "$PROFILE" ]; then
  logInfoMessage "AWS PROFILE: $PROFILE"
  logInfoMessage "aws s3 sync ${FILE_TO_BE_UPLOADED} s3://${S3_BUCKET}/${DESTINATION_DIR} --profile $PROFILE"
  aws s3 sync "${FILE_TO_BE_UPLOADED}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --profile "$PROFILE"
else
  logInfoMessage "aws s3 sync ${FILE_TO_BE_UPLOADED} s3://${S3_BUCKET}/${DESTINATION_DIR}"
  aws s3 sync "${FILE_TO_BE_UPLOADED}" "s3://${S3_BUCKET}/${DESTINATION_DIR}"
fi
  TASK_STATUS=$?
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

operation="${OPERATION}"
if [[ -z "$operation" ]]; then
  logErrorMessage "OPERATION is not set. Allowed values: recursive | rename | sync"
  exit 1
else
  logInfoMessage "OPERATION is set ${OPERATION}"
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
      logErrorMessage "Invalid OPERATION: $operation. Allowed values: recursive | rename | sync"
      exit 1
      ;;
  esac
fi

#Runing comamnd
# docker run -it --rm -e WORKSPACE=/workspace -e CODEBASE_DIR=app -e FILE_NAME=check -e S3_BUCKET=s3-bps-bucket -e DESTINATION_DIR=uploads -e PROFILE=default -e OPERATION=recursive -v $(pwd):/workspace/app -v ~/.aws:/home/buildpiper/.aws <imagename>

