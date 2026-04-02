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

# Initial Event
add_event "S3 OPERATION START" "Successful" \
            "${OPERATION} task initiated" \
            "Target Bucket: ${S3_BUCKET}"

logInfoMessage "CODEBASE_LOCATION: ${WORKSPACE}/${CODEBASE_DIR}"
cd "${WORKSPACE}/${CODEBASE_DIR}"

uploadSingleFile() {
  if [ "${ASSUME_ROLE}" == "true" ]; then
    if [ -z "$ACCOUNT_ID" ] || [ -z "$ROLE_NAME" ]; then
          add_event "AWS ROLE ERROR" "Failed" \
                      "Missing IAM credentials" \
                      "ACCOUNT_ID or ROLE_NAME not set"
          logErrorMessage "Error: ACCOUNT_ID and ROLE_NAME must be set as environment variables when ASSUME_ROLE=true"
          exit 1
    fi
      ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
      add_event "AWS ROLE ASSUME" "Successful" \
                  "Identity switching required" \
                  "Assuming: ${ROLE_ARN}"
      getAssumeRole "$ROLE_ARN"
  else
      logInfoMessage "ASSUME_ROLE is not set to 'true', skipping role assumption"
  fi
  logInfoMessage "Starting Upload Single File task"

  add_event "S3 TRANSFER START" "Successful" \
              "AWS CLI command triggered" \
              "Uploading $FILE_NAME to $S3_BUCKET"

  if [ -n "$PROFILE" ]; then
    aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}/" --profile "$PROFILE"
  else
    aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}/"
  fi

  if [ $? -eq 0 ]; then
     add_event "S3 TRANSFER SUCCESS" "Successful" \
                 "CLI exit code 0" \
                 "File uploaded successfully"
  else
     add_event "S3 TRANSFER FAILED" "Failed" \
                 "CLI exit code non-zero" \
                 "Upload failed for $FILE_NAME"
  fi
}


# Upload Function (like upload.sh)
uploadRecursiveFile() {
if [ "${ASSUME_ROLE}" == "true" ]; then
    if [ -z "$ACCOUNT_ID" ] || [ -z "$ROLE_NAME" ]; then
          add_event "AWS ROLE ERROR" "Failed" \
                      "Missing IAM credentials" \
                      "ACCOUNT_ID or ROLE_NAME not set"
          exit 1
    fi
      ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
      add_event "AWS ROLE ASSUME" "Successful" \
                  "Identity switching required" \
                  "Assuming: ${ROLE_ARN}"
      getAssumeRole "$ROLE_ARN"
fi
  logInfoMessage "Starting Upload Recursive File Task"

  if [ "$LIST" = true ]; then
    ls -ltr
  fi

  add_event "S3 TRANSFER START" "Successful" \
              "AWS CLI command triggered" \
              "Recursive upload of $FILE_NAME"

if [ -n "$PROFILE" ]; then
    aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --recursive --profile "$PROFILE"
else
    aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --recursive
fi
  TASK_STATUS=$?
  
  if [ $TASK_STATUS -eq 0 ]; then
     add_event "S3 TRANSFER SUCCESS" "Successful" \
                 "CLI exit code 0" \
                 "Recursive upload completed"
  else
     add_event "S3 TRANSFER FAILED" "Failed" \
                 "CLI exit code non-zero" \
                 "Recursive upload failed"
  fi
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

# Rename & Upload Function (like build-rename.sh)
renameAndUpload() {
if [ "${ASSUME_ROLE}" == "true" ]; then
    if [ -z "$ACCOUNT_ID" ] || [ -z "$ROLE_NAME" ]; then
          add_event "AWS ROLE ERROR" "Failed" \
                      "Missing IAM credentials" \
                      "ACCOUNT_ID or ROLE_NAME not set"
          exit 1
    fi
      ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
      add_event "AWS ROLE ASSUME" "Successful" \
                  "Identity switching required" \
                  "Assuming: ${ROLE_ARN}"
      getAssumeRole "$ROLE_ARN"
fi
  logInfoMessage "Starting Rename & Upload Task"
  tag=$(cat version)

  add_event "ARTIFACT RENAME" "Successful" \
              "Artifact versioning applied" \
              "Renaming to ${tag}-$ARTIFACT_NEW_NAME"

  mv "$ARTIFACT_PATH/$ARTIFACT_OLD_NAME" "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME"
  
  add_event "S3 TRANSFER START" "Successful" \
              "AWS CLI command triggered" \
              "Uploading renamed artifact"

if [ -n "$PROFILE" ]; then
  aws s3 cp "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --profile "$PROFILE"
else
  aws s3 cp "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME" "s3://${S3_BUCKET}/${DESTINATION_DIR}" 
fi

  TASK_STATUS=$?
  if [ $TASK_STATUS -eq 0 ]; then
     add_event "S3 TRANSFER SUCCESS" "Successful" \
                 "CLI exit code 0" \
                 "Renamed file uploaded"
  else
     add_event "S3 TRANSFER FAILED" "Failed" \
                 "CLI exit code non-zero" \
                 "Renamed file upload failed"
  fi
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

# Sync Function (like build-sync.sh)
syncToS3() {
if [ "${ASSUME_ROLE}" == "true" ]; then
    if [ -z "$ACCOUNT_ID" ] || [ -z "$ROLE_NAME" ]; then
          add_event "AWS ROLE ERROR" "Failed" \
                      "Missing IAM credentials" \
                      "ACCOUNT_ID or ROLE_NAME not set"
          exit 1
    fi
      ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
      add_event "AWS ROLE ASSUME" "Successful" \
                  "Identity switching required" \
                  "Assuming: ${ROLE_ARN}"
      getAssumeRole "$ROLE_ARN"
fi
  logInfoMessage "Starting Sync Task"

  add_event "S3 TRANSFER START" "Successful" \
              "AWS CLI command triggered" \
              "Syncing $FILE_NAME to $S3_BUCKET"

if [ -n "$PROFILE" ]; then
  aws s3 sync "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --profile "$PROFILE"
else
  aws s3 sync "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}"
fi
  TASK_STATUS=$?
  if [ $TASK_STATUS -eq 0 ]; then
     add_event "S3 TRANSFER SUCCESS" "Successful" \
                 "CLI exit code 0" \
                 "Sync completed"
  else
     add_event "S3 TRANSFER FAILED" "Failed" \
                 "CLI exit code non-zero" \
                 "Sync failed"
  fi
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

downloadSingleFile() {
  if [ "${ASSUME_ROLE}" == "true" ]; then
      ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
      add_event "AWS ROLE ASSUME" "Successful" \
                  "Identity switching required" \
                  "Assuming: ${ROLE_ARN}"
      getAssumeRole "$ROLE_ARN"
  fi

  logInfoMessage "Starting Single File Download"
  mkdir -p "${DESTINATION_DIR}"

  add_event "S3 TRANSFER START" "Successful" \
              "AWS CLI command triggered" \
              "Downloading $FILE_NAME from $S3_BUCKET"

  if [ -n "$PROFILE" ]; then
    aws s3 cp "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}" --profile "$PROFILE"
  else
    aws s3 cp "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}"
  fi

  TASK_STATUS=$?
  if [ $TASK_STATUS -eq 0 ]; then
     add_event "S3 TRANSFER SUCCESS" "Successful" \
                 "CLI exit code 0" \
                 "Download successful"
  else
     add_event "S3 TRANSFER FAILED" "Failed" \
                 "CLI exit code non-zero" \
                 "Download failed"
  fi
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}


downloadRecursive() {
  if [ "${ASSUME_ROLE}" == "true" ]; then
      ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
      add_event "AWS ROLE ASSUME" "Successful" \
                  "Identity switching required" \
                  "Assuming: ${ROLE_ARN}"
      getAssumeRole "$ROLE_ARN"
  fi

  logInfoMessage "Starting Recursive Download"
  
  add_event "S3 TRANSFER START" "Successful" \
              "AWS CLI command triggered" \
              "Recursive download from $S3_BUCKET"

  if [ -n "$PROFILE" ]; then
    aws s3 cp "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}" --recursive --profile "$PROFILE"
  else
    aws s3 cp "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}" --recursive
  fi

  TASK_STATUS=$?
  if [ $TASK_STATUS -eq 0 ]; then
     add_event "S3 TRANSFER SUCCESS" "Successful" \
                 "CLI exit code 0" \
                 "Recursive download completed"
  else
     add_event "S3 TRANSFER FAILED" "Failed" \
                 "CLI exit code non-zero" \
                 "Recursive download failed"
  fi
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}


downloadSync() {
  if [ "${ASSUME_ROLE}" == "true" ]; then
      ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
      add_event "AWS ROLE ASSUME" "Successful" \
                  "Identity switching required" \
                  "Assuming: ${ROLE_ARN}"
      getAssumeRole "$ROLE_ARN"
  fi

  logInfoMessage "Starting Sync Download"

  add_event "S3 TRANSFER START" "Successful" \
              "AWS CLI command triggered" \
              "Sync download from $S3_BUCKET"

  if [ -n "$PROFILE" ]; then
    aws s3 sync "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}" --profile "$PROFILE"
  else
    aws s3 sync "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}"
  fi

  TASK_STATUS=$?
  if [ $TASK_STATUS -eq 0 ]; then
     add_event "S3 TRANSFER SUCCESS" "Successful" \
                 "CLI exit code 0" \
                 "Sync download completed"
  else
     add_event "S3 TRANSFER FAILED" "Failed" \
                 "CLI exit code non-zero" \
                 "Sync download failed"
  fi
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

operation="${OPERATION}"

if [[ -z "$operation" ]]; then
  add_event "INVALID OPERATION" "Failed" \
              "OPERATION is not set" \
              "Check environment configuration"
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
    add_event "INVALID OPERATION" "Failed" \
                "Unsupported operation: $operation" \
                "Use allowed values in script documentation"
    exit 1
    ;;
esac