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

if [ -n "$SLEEP_DURATION" ]; then
logInfoMessage "set sleep $SLEEP_DURATION"
sleep "${SLEEP_DURATION}"
fi

logInfoMessage "CODEBASE_LOCATION: ${WORKSPACE}/${CODEBASE_DIR}"
cd "${WORKSPACE}/${CODEBASE_DIR}"

uploadSingleFile() {
  if [ "${ASSUME_ROLE}" == "true" ]; then
    if [ -z "$ACCOUNT_ID" ] || [ -z "$ROLE_NAME" ]; then
          logErrorMessage "Error: ACCOUNT_ID and ROLE_NAME must be set as environment variables when ASSUME_ROLE=true"
          exit 1
    fi

      getAssumeRole "${ACCOUNT_ID}" "${ROLE_NAME}"
  else
      logInfoMessage "ASSUME_ROLE is not set to 'true', skipping role assumption"
  fi
  logInfoMessage "Starting Upload Single File task"

  logInfoMessage "FILE NAME: $FILE_NAME"
  logInfoMessage "BUCKET NAME: $S3_BUCKET"
  logInfoMessage "DESTINATION DIR: $DESTINATION_DIR"

  if [ -n "$PROFILE" ]; then
    logInfoMessage "aws s3 cp ${FILE_NAME} s3://${S3_BUCKET}/${DESTINATION_DIR}/ --profile $PROFILE"
    aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}/" --profile "$PROFILE"
  else
    logInfoMessage "aws s3 cp ${FILE_NAME} s3://${S3_BUCKET}/${DESTINATION_DIR}/"
    aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}/"
  fi
}


# Upload Function (like upload.sh)
uploadRecursiveFile() {
if [ "${ASSUME_ROLE}" == "true" ]; then
    if [ -z "$ACCOUNT_ID" ] || [ -z "$ROLE_NAME" ]; then
          logErrorMessage "Error: ACCOUNT_ID and ROLE_NAME must be set as environment variables when ASSUME_ROLE=true"
          exit 1
    fi
    getAssumeRole "${ACCOUNT_ID}" "${ROLE_NAME}"
else
    logInfoMessage "ASSUME_ROLE is not set to 'true', skipping role assumption"
fi
  logInfoMessage "Starting Upload Recursive File Task"

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
    if [ -z "$ACCOUNT_ID" ] || [ -z "$ROLE_NAME" ]; then
          logErrorMessage "Error: ACCOUNT_ID and ROLE_NAME must be set as environment variables when ASSUME_ROLE=true"
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
    if [ -z "$ACCOUNT_ID" ] || [ -z "$ROLE_NAME" ]; then
          logErrorMessage "Error: ACCOUNT_ID and ROLE_NAME must be set as environment variables when ASSUME_ROLE=true"
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

downloadSingleFile() {
  if [ "${ASSUME_ROLE}" == "true" ]; then
    getAssumeRole "${ACCOUNT_ID}" "${ROLE_NAME}"
  fi

  logInfoMessage "Starting Single File Download"
  logInfoMessage "S3 FILE: s3://${S3_BUCKET}/${S3_KEY}"
  logInfoMessage "DESTINATION: ${DESTINATION_DIR}"

  mkdir -p "${DESTINATION_DIR}"

  if [ -n "$PROFILE" ]; then
    aws s3 cp "s3://${S3_BUCKET}/${S3_KEY}" "${DESTINATION_DIR}/" --profile "$PROFILE"
  else
    aws s3 cp "s3://${S3_BUCKET}/${S3_KEY}" "${DESTINATION_DIR}/"
  fi

  TASK_STATUS=$?
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}


downloadRecursive() {
  if [ "${ASSUME_ROLE}" == "true" ]; then
    getAssumeRole "${ACCOUNT_ID}" "${ROLE_NAME}"
  fi

  logInfoMessage "Starting Recursive Download"
  logInfoMessage "S3 PATH: s3://${S3_BUCKET}/${S3_PREFIX}"
  logInfoMessage "DESTINATION: ${DESTINATION_DIR}"

  if [ -n "$PROFILE" ]; then
    aws s3 cp "s3://${S3_BUCKET}/${S3_PREFIX}" "${DESTINATION_DIR}" --recursive --profile "$PROFILE"
  else
    aws s3 cp "s3://${S3_BUCKET}/${S3_PREFIX}" "${DESTINATION_DIR}" --recursive
  fi

  TASK_STATUS=$?
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}


downloadSync() {
  if [ "${ASSUME_ROLE}" == "true" ]; then
    getAssumeRole "${ACCOUNT_ID}" "${ROLE_NAME}"
  fi

  logInfoMessage "Starting Sync Download"
  logInfoMessage "S3 PATH: s3://${S3_BUCKET}/${S3_PREFIX}"
  logInfoMessage "DESTINATION: ${DESTINATION_DIR}"


  if [ -n "$PROFILE" ]; then
    aws s3 sync "s3://${S3_BUCKET}/${S3_PREFIX}" "${DESTINATION_DIR}" --profile "$PROFILE"
  else
    aws s3 sync "s3://${S3_BUCKET}/${S3_PREFIX}" "${DESTINATION_DIR}"
  fi

  TASK_STATUS=$?
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

operation="${OPERATION}"

if [[ -z "$operation" ]]; then
  logErrorMessage "OPERATION is not set. Allowed values:
  UploadSingle | UploadRecursive | UploadRename | UploadSync |
  DownloadSingle | DownloadRecursive | DownloadSync"
  exit 1
fi

logInfoMessage "OPERATION is set to: ${operation}"

case "$operation" in

  UploadSingle)
    uploadSingleFile
    ;;

  UploadRecursive)
    uploadRecursiveFile
    ;;

  UploadRename)
    renameAndUpload
    ;;

  UploadSync)
    syncToS3
    ;;

  DownloadSingle)
    downloadSingleFile
    ;;

  DownloadRecursive)
    downloadRecursive
    ;;

  DownloadSync)
    downloadSync
    ;;

  *)
    logErrorMessage "Invalid OPERATION: ${operation}"
    logInfoMessage "Allowed values: UploadSingle | UploadRecursive | UploadRename | UploadSync | DownloadSingle | DownloadRecursive | DownloadSync"
    exit 1
    ;;
esac

#Runing comamnd
# docker run -it --rm -e WORKSPACE=/workspace -e CODEBASE_DIR=app -e FILE_NAME=check -e S3_BUCKET=s3-bps-bucket -e DESTINATION_DIR=uploads -e PROFILE=default -e OPERATION=recursive -v $(pwd):/workspace/app -v ~/.aws:/home/buildpiper/.aws <imagename>

