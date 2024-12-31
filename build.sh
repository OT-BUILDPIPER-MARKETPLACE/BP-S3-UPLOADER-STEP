#!/bin/bash

# Load required functions
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

# Variables
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
TASK_STATUS=0

logInfoMessage "Starting processing at [$CODEBASE_LOCATION]"
sleep $SLEEP_DURATION

# Change to codebase location
cd "${CODEBASE_LOCATION}" || {
    logErrorMessage "Failed to navigate to $CODEBASE_LOCATION. Directory does not exist."
    exit 1
}

# Log received arguments
logInfoMessage "Received arguments:"
logInfoMessage "File to be uploaded: ${FILE_TO_BE_UPLOADED}"
logInfoMessage "S3 Bucket: ${S3_BUCKET}"
logInfoMessage "Location of file in S3 Bucket: ${FILE_KEY}"

# Assume AWS Role if required
if [ "${ASSUME_OTHER_ROLE}" == true ]; then
    role_output=$(aws sts assume-role --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" --role-session-name "${ROLE_SESSION_NAME}")

    if [ $? -ne 0 ]; then
        logErrorMessage "Failed to assume role: arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
        exit 1
    fi

    # Export AWS credentials
    export AWS_ACCESS_KEY_ID=$(echo "$role_output" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$role_output" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$role_output" | jq -r '.Credentials.SessionToken')
    logInfoMessage "Assumed role successfully."
fi

# Validate input parameters
if ! isStrNonEmpty "${S3_BUCKET}" > /dev/null; then
    logErrorMessage "S3 bucket details are missing. Please check."
    TASK_STATUS=1
elif ! isStrNonEmpty "${FILE_TO_BE_UPLOADED}" > /dev/null; then
    logErrorMessage "File to be uploaded is not provided. Please check."
    TASK_STATUS=1
elif ! isFileExist "${FILE_TO_BE_UPLOADED}" > /dev/null; then
    logErrorMessage "File ${FILE_TO_BE_UPLOADED} does not exist. Please check."
    TASK_STATUS=1
elif ! bucketExist "${S3_BUCKET}" > /dev/null; then
    logErrorMessage "Unable to access S3 bucket ${S3_BUCKET}. Check if it exists and permissions are correct."
    TASK_STATUS=1
elif ! isStrNonEmpty "${FILE_KEY}" > /dev/null; then
    logErrorMessage "File key is not provided. Please check."
    TASK_STATUS=1
fi

# Exit if any validation failed
if [ $TASK_STATUS -ne 0 ]; then
    saveTaskStatus $TASK_STATUS "${ACTIVITY_SUB_TASK_CODE}"
    exit $TASK_STATUS
fi

# Upload file to S3
logInfoMessage "Uploading file to S3: ${FILE_TO_BE_UPLOADED} to s3://${S3_BUCKET}/${FILE_KEY}"
aws s3 cp "${FILE_TO_BE_UPLOADED}" "s3://${S3_BUCKET}/${FILE_KEY}"
TASK_STATUS=$?

# Save task status and exit
saveTaskStatus $TASK_STATUS "${ACTIVITY_SUB_TASK_CODE}"