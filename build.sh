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

# Role assumption function
assumeRole() {
  if [ "$ASSUME_OTHER_ROLE" == true ]; then
    role_output=$(aws sts assume-role --role-arn arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME --role-session-name $ROLE_SESSION_NAME)
    if [ $? -ne 0 ]; then
      echo "Failed to assume role."
      exit 1
    fi
    export AWS_ACCESS_KEY_ID=$(echo $role_output | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $role_output | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo $role_output | jq -r '.Credentials.SessionToken')
  fi
}

# Upload Function (like upload.sh)
uploadFile() {
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

  aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --recursive --profile "$PROFILE"
  TASK_STATUS=$?
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

# Rename & Upload Function (like build-rename.sh)
renameAndUpload() {
  assumeRole
  logInfoMessage "Starting Rename & Upload Task"
  cd "${WORKSPACE}/${CODEBASE_DIR}"
  tag=$(cat version)

  logInfoMessage "Old Artifact Name: [$ARTIFACT_OLD_NAME]"
  logInfoMessage "New Artifact Name: [$ARTIFACT_NEW_NAME]"
  mv "$ARTIFACT_PATH/$ARTIFACT_OLD_NAME" "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME"
  logInfoMessage "Artifact renamed successfully to: [${tag}-$ARTIFACT_NEW_NAME]"

  logInfoMessage "Uploading to S3 Bucket: ${S3_BUCKET}"
  aws s3 cp "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME" "${S3_BUCKET}"
  TASK_STATUS=$?
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

# Sync Function (like build-sync.sh)
syncToS3() {
  assumeRole
  logInfoMessage "Starting Sync Task"
  cd "${WORKSPACE}/${CODEBASE_DIR}"
  logInfoMessage "File/Folder to sync: ${FILE_TO_BE_UPLOADED}"
  logInfoMessage "S3 Bucket: ${S3_BUCKET}"

  aws s3 sync "${FILE_TO_BE_UPLOADED}" "${S3_BUCKET}"
  TASK_STATUS=$?
  saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

# Main execution with case options
case "$1" in
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
    echo "Usage: $0 {recursive|rename|sync}"
    exit 1
    ;;
esac
