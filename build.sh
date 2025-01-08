#!/bin/bash

# Load required functions
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

source /opt/buildpiper/shell-functions/upload_files_from_csv_to_s3.sh
source /opt/buildpiper/shell-functions/upload_json_components_to_s3.sh

# Variables
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
TASK_STATUS=0

# Checking versions# Log received arguments

# Change to codebase location
cd "${CODEBASE_LOCATION}" || {
    logErrorMessage "Failed to navigate to $CODEBASE_LOCATION. Directory does not exist."
    TASK_STATUS="1"
    saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
}

logInfoMessage "Checking versions..." && aws --version

logInfoMessage "Starting processing at [$CODEBASE_LOCATION]" 
ls -ltr
sleep $SLEEP_DURATION

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

# Main script execution
input_data="${CSV_DATA}"
json_filepath="${JSON_FILEPATH}"

if [[ -z "$input_data" && -z "$json_filepath" ]]; then
    logErrorMessage "Either CSV_DATA or JSON_FILEPATH is required. Please provide at least one."
    TASK_STATUS=1
    saveTaskStatus $TASK_STATUS "${ACTIVITY_SUB_TASK_CODE}"
fi

# Assume AWS Role if required
if [ "${ASSUME_OTHER_ROLE}" == true ]; then
    assume_role "${ACCOUNT_ID}" "${ROLE_NAME}" "${ROLE_SESSION_NAME}"
fi

# Call functions only if variables are not empty
if [[ -n "$input_data" ]]; then
    logInfoMessage "Calling upload_files_from_csv_to_s3 with: $input_data"
    upload_files_from_csv_to_s3 "$input_data"
    TASK_STATUS=$?
else
    logInfoMessage "CSV_DATA is empty. Skipping upload_files_from_csv_to_s3."
fi

if [[ -n "$json_filepath" ]]; then
    logInfoMessage "Calling upload_json_components_to_s3 with: $json_filepath"
    upload_json_components_to_s3 "$json_filepath"
    TASK_STATUS=$?
else
    logInfoMessage "JSON_FILEPATH is empty. Skipping upload_json_components_to_s3."
fi

if [ "${ASSUME_OTHER_ROLE}" == true ]; then
            unset_role
fi

saveTaskStatus $TASK_STATUS "${ACTIVITY_SUB_TASK_CODE}"
