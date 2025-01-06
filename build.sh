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

# Checking versions# Log received arguments
logInfoMessage "Received arguments:"
logInfoMessage "S3 Bucket: ${S3_BUCKET}"
logInfoMessage "Location of file in S3 Bucket: ${FILE_KEY}"
logInfoMessage "SEARCH_DIR: ${SEARCH_DIR}"
logInfoMessage "SEARCH_PATTERN: ${SEARCH_PATTERN}"

logInfoMessage "Checking versions..." && aws --version

logInfoMessage "Starting processing at [$CODEBASE_LOCATION]"
sleep $SLEEP_DURATION

# Change to codebase location
cd "${CODEBASE_LOCATION}" || {
    logErrorMessage "Failed to navigate to $CODEBASE_LOCATION. Directory does not exist."
    TASK_STATUS=1
    saveTaskStatus $TASK_STATUS "${ACTIVITY_SUB_TASK_CODE}"
}

# Function to assume an AWS role
assume_role() {
    local account_id="$1"
    local role_name="$2"
    local session_name="$3"

    logInfoMessage "Attempting to assume role: arn:aws:iam::${account_id}:role/${role_name}"
    local role_output
    role_output=$(aws sts assume-role --role-arn "arn:aws:iam::${account_id}:role/${role_name}" --role-session-name "${session_name}" 2>&1)

    if [ $? -ne 0 ]; then
        logErrorMessage "Failed to assume role: arn:aws:iam::${account_id}:role/${role_name}. Error: $role_output"
        TASK_STATUS=1
        saveTaskStatus $TASK_STATUS "${ACTIVITY_SUB_TASK_CODE}"
        return $TASK_STATUS
    fi

    export AWS_ACCESS_KEY_ID=$(echo "$role_output" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$role_output" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$role_output" | jq -r '.Credentials.SessionToken')

    logInfoMessage "Assumed role successfully."
}

# Function to unset AWS role credentials
unset_role() {
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    logInfoMessage "Unset AWS credentials."
}


# Check if SEARCH_DIR is provided
if [ -n "${SEARCH_DIR}" ]; then
    SEARCH_LOCATION="${CODEBASE_LOCATION}/${SEARCH_DIR}"
    logInfoMessage "SEARCH_LOCATION is ${SEARCH_LOCATION} directory. Files in this directory are:"
    ls -ltr ${SEARCH_LOCATION}

else
    SEARCH_LOCATION="${CODEBASE_LOCATION}"
    logInfoMessage "SEARCH_DIR not provided. Defaulting to CODEBASE_LOCATION."
    logInfoMessage "SEARCH_LOCATION is ${SEARCH_LOCATION}"
    ls -ltr ${SEARCH_LOCATION}
fi

# Find files if a search pattern is provided
if [ -n "${SEARCH_PATTERN}" ]; then
    search_dir="${SEARCH_LOCATION}"
    pattern="${SEARCH_PATTERN}"

    logInfoMessage "Searching for files matching [$pattern] in directory [$search_dir]"
    files_to_upload=$(find "$search_dir" -type f -name "$pattern" 2>/dev/null)

    if [ -z "$files_to_upload" ]; then
        logErrorMessage "No files matching [$pattern] found in [$search_dir]"
        logInfoMessage "Contents of directory [$search_dir]:"
        ls -ltr "$search_dir"
        echo ""
        TASK_STATUS=1
    else
        logInfoMessage "Files found: $(echo "$files_to_upload" | tr '\n' ', ')"
        echo "$files_to_upload"
    fi
else
    logErrorMessage "No search pattern provided. Exiting."
    TASK_STATUS=1
fi

# Validate input parameters
if ! isStrNonEmpty "${S3_BUCKET}" > /dev/null; then
    logErrorMessage "S3 bucket details are missing. Please check."
    TASK_STATUS=1
elif ! bucketExist "${S3_BUCKET}" > /dev/null; then
    logErrorMessage "Unable to access S3 bucket ${S3_BUCKET}. Check if it exists and permissions are correct."
    TASK_STATUS=1
elif ! isStrNonEmpty "${FILE_KEY}" > /dev/null; then
    logErrorMessage "File key is not provided. Please check."
    TASK_STATUS=1
fi

# Save task status if validation failed
if [ $TASK_STATUS -ne 0 ]; then
    saveTaskStatus $TASK_STATUS "${ACTIVITY_SUB_TASK_CODE}"
fi

# Assume AWS Role if required
if [ "${ASSUME_OTHER_ROLE}" == true ]; then
    assume_role "${ACCOUNT_ID}" "${ROLE_NAME}" "${ROLE_SESSION_NAME}"
fi

# Upload each file to S3
for file in $files_to_upload; do
    file_name=$(basename "$file")
    s3_key="${FILE_KEY}/${file_name}"
    logInfoMessage "Uploading file [$file] to S3 bucket [$S3_BUCKET] at [$s3_key]"
    logInfoMessage "aws s3 cp $file s3://${S3_BUCKET}/${s3_key}"

    aws s3 cp "$file" "s3://${S3_BUCKET}/${s3_key}"
    TASK_STATUS=$?

    if [ $TASK_STATUS -eq 0 ]; then
        logInfoMessage "Upload done of [$file] to S3."
        TASK_STATUS=0
    else
        logErrorMessage "Failed to upload [$file] to S3."
        if [ "${ASSUME_OTHER_ROLE}" == true ]; then
            unset_role
        fi
        saveTaskStatus $TASK_STATUS "${ACTIVITY_SUB_TASK_CODE}"
    fi
done


if [ "${ASSUME_OTHER_ROLE}" == true ]; then
            unset_role
        fi
saveTaskStatus $TASK_STATUS "${ACTIVITY_SUB_TASK_CODE}"