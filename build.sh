#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

# ---------------------------------------------------------------
# NOTE: ACTIVITY_SUB_TASK_CODE is managed by the BuildPiper
#       environment. Do NOT override it here to ensure events
#       appear correctly in the UI.
# ---------------------------------------------------------------

if [ "$DEBUG" = true ]; then
  set -x
fi

# ---------------------------------------------------------------
# 1. Initialization
# ---------------------------------------------------------------
WORKSPACE="${WORKSPACE:-/bp/workspace}"
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

logInfoMessage "> Starting step: s3_uploader"
logInfoMessage "> Operation     : ${OPERATION}"
logInfoMessage "> Target bucket : ${S3_BUCKET}"
logInfoMessage "> Codebase      : ${CODEBASE_LOCATION}"

add_event "INITIALIZATION" "Successful" \
    "S3 operation step initialized" \
    "Operation: ${OPERATION} | Bucket: ${S3_BUCKET}"

if [ -n "$SLEEP_DURATION" ]; then
    logInfoMessage "> Sleeping for ${SLEEP_DURATION} second(s)..."
    sleep "${SLEEP_DURATION}"
fi

# ---------------------------------------------------------------
# 2. Workspace Navigation
# ---------------------------------------------------------------
logInfoMessage "> Navigating to codebase directory: ${CODEBASE_LOCATION}"

cd "${CODEBASE_LOCATION}" || {
    logErrorMessage "> Failed to navigate to codebase directory: ${CODEBASE_LOCATION}"
    add_event "WORKSPACE_NAVIGATION" "Failed" \
        "Failed to navigate to codebase directory" \
        "Path: ${CODEBASE_LOCATION} | Verify WORKSPACE and CODEBASE_DIR are set correctly"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
}

logInfoMessage "> Successfully navigated to: ${CODEBASE_LOCATION}"
add_event "WORKSPACE_NAVIGATION" "Successful" \
    "Navigated to codebase directory" \
    "Path: ${CODEBASE_LOCATION}"

# ---------------------------------------------------------------
# 3. Operation Validation
# ---------------------------------------------------------------
logInfoMessage "> Validating operation..."

if [[ -z "$OPERATION" ]]; then
    logErrorMessage "> OPERATION is not set — cannot proceed"
    add_event "OPERATION_VALIDATION" "Failed" \
        "OPERATION variable is not set" \
        "Allowed values: UploadSingle | UploadRecursive | UploadRename | UploadSync | DownloadSingle | DownloadRecursive | DownloadSync"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

logInfoMessage "> Operation validated: ${OPERATION}"
add_event "OPERATION_VALIDATION" "Successful" \
    "S3 operation validated" \
    "Operation: ${OPERATION} | Bucket: ${S3_BUCKET} | Destination: ${DESTINATION_DIR}"

# ---------------------------------------------------------------
# Helper: IAM Role Assumption
# ---------------------------------------------------------------
_assumeRoleIfRequired() {
    local context="$1"
    if [ "${ASSUME_ROLE}" == "true" ]; then
        if [ -z "$ACCOUNT_ID" ] || [ -z "$ROLE_NAME" ]; then
            logErrorMessage "> [${context}] ASSUME_ROLE=true but ACCOUNT_ID or ROLE_NAME is not set"
            add_event "IAM_ROLE_ASSUMPTION" "Failed" \
                "Missing IAM credentials for role assumption" \
                "Context: ${context} | Set ACCOUNT_ID and ROLE_NAME in pipeline config"
            saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
            exit 1
        fi
        ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
        logInfoMessage "> [${context}] Assuming IAM role: ${ROLE_ARN}"
        add_event "IAM_ROLE_ASSUMPTION" "Successful" \
            "Assuming IAM role for cross-account access" \
            "Role ARN: ${ROLE_ARN} | Context: ${context}"
        getAssumeRole "$ROLE_ARN"
    else
        logInfoMessage "> [${context}] ASSUME_ROLE not set — using default credentials"
    fi
}

# ---------------------------------------------------------------
# 4. Operation Functions
# ---------------------------------------------------------------

uploadSingleFile() {
    logInfoMessage "> [UploadSingle] Starting single file upload..."
    _assumeRoleIfRequired "UploadSingle"

    echo ""
    echo "> Upload Single File Summary"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Parameter" "Value"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "File" "${FILE_NAME}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Bucket" "${S3_BUCKET}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Destination" "${DESTINATION_DIR}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    echo ""

    add_event "S3_TRANSFER_START" "Successful" \
        "Uploading single file to S3" \
        "File: ${FILE_NAME} | Bucket: s3://${S3_BUCKET}/${DESTINATION_DIR}/"

    if [ -n "$PROFILE" ]; then
        aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}/" --profile "$PROFILE"
    else
        aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}/"
    fi
    TASK_STATUS=$?

    if [ "$TASK_STATUS" -eq 0 ]; then
        logInfoMessage "> [UploadSingle] File uploaded successfully (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Successful" \
            "Single file uploaded successfully" \
            "File: ${FILE_NAME} | Destination: s3://${S3_BUCKET}/${DESTINATION_DIR}/"
    else
        logErrorMessage "> [UploadSingle] Upload failed (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Failed" \
            "Single file upload failed — check AWS credentials and bucket permissions" \
            "File: ${FILE_NAME} | Bucket: ${S3_BUCKET} | Exit Code: ${TASK_STATUS}"
    fi
    saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
}

uploadRecursiveFile() {
    logInfoMessage "> [UploadRecursive] Starting recursive file upload..."
    _assumeRoleIfRequired "UploadRecursive"

    if [ "$LIST" = true ]; then
        logInfoMessage "> [UploadRecursive] Listing files..."
        ls -ltr
    fi

    echo ""
    echo "> Upload Recursive Summary"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Parameter" "Value"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Source" "${FILE_NAME}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Bucket" "${S3_BUCKET}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Destination" "${DESTINATION_DIR}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    echo ""

    add_event "S3_TRANSFER_START" "Successful" \
        "Uploading files recursively to S3" \
        "Source: ${FILE_NAME} | Bucket: s3://${S3_BUCKET}/${DESTINATION_DIR}"

    if [ -n "$PROFILE" ]; then
        aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --recursive --profile "$PROFILE"
    else
        aws s3 cp "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --recursive
    fi
    TASK_STATUS=$?

    if [ "$TASK_STATUS" -eq 0 ]; then
        logInfoMessage "> [UploadRecursive] Recursive upload completed successfully (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Successful" \
            "Recursive upload completed successfully" \
            "Source: ${FILE_NAME} | Destination: s3://${S3_BUCKET}/${DESTINATION_DIR}"
    else
        logErrorMessage "> [UploadRecursive] Recursive upload failed (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Failed" \
            "Recursive upload failed — check AWS credentials and bucket permissions" \
            "Source: ${FILE_NAME} | Bucket: ${S3_BUCKET} | Exit Code: ${TASK_STATUS}"
    fi
    saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
}

renameAndUpload() {
    logInfoMessage "> [UploadRename] Starting rename and upload..."
    _assumeRoleIfRequired "UploadRename"

    local tag
    tag=$(cat version)
    local renamed_artifact="${ARTIFACT_PATH}/${tag}-${ARTIFACT_NEW_NAME}"

    logInfoMessage "> [UploadRename] Renaming: ${ARTIFACT_OLD_NAME} → ${tag}-${ARTIFACT_NEW_NAME}"

    echo ""
    echo "> Rename and Upload Summary"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Parameter" "Value"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Original Name" "${ARTIFACT_OLD_NAME}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Renamed To" "${tag}-${ARTIFACT_NEW_NAME}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Bucket" "${S3_BUCKET}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Destination" "${DESTINATION_DIR}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    echo ""

    add_event "ARTIFACT_RENAME" "Successful" \
        "Artifact versioning applied — renaming before upload" \
        "From: ${ARTIFACT_OLD_NAME} | To: ${tag}-${ARTIFACT_NEW_NAME}"

    mv "${ARTIFACT_PATH}/${ARTIFACT_OLD_NAME}" "${renamed_artifact}"

    add_event "S3_TRANSFER_START" "Successful" \
        "Uploading renamed artifact to S3" \
        "Artifact: ${tag}-${ARTIFACT_NEW_NAME} | Bucket: s3://${S3_BUCKET}/${DESTINATION_DIR}"

    if [ -n "$PROFILE" ]; then
        aws s3 cp "${renamed_artifact}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --profile "$PROFILE"
    else
        aws s3 cp "${renamed_artifact}" "s3://${S3_BUCKET}/${DESTINATION_DIR}"
    fi
    TASK_STATUS=$?

    if [ "$TASK_STATUS" -eq 0 ]; then
        logInfoMessage "> [UploadRename] Renamed artifact uploaded successfully (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Successful" \
            "Renamed artifact uploaded successfully" \
            "Artifact: ${tag}-${ARTIFACT_NEW_NAME} | Destination: s3://${S3_BUCKET}/${DESTINATION_DIR}"
    else
        logErrorMessage "> [UploadRename] Renamed artifact upload failed (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Failed" \
            "Renamed artifact upload failed — check AWS credentials and bucket permissions" \
            "Artifact: ${tag}-${ARTIFACT_NEW_NAME} | Bucket: ${S3_BUCKET} | Exit Code: ${TASK_STATUS}"
    fi
    saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
}

syncToS3() {
    logInfoMessage "> [UploadSync] Starting S3 sync..."
    _assumeRoleIfRequired "UploadSync"

    echo ""
    echo "> Sync to S3 Summary"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Parameter" "Value"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Source" "${FILE_NAME}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Bucket" "${S3_BUCKET}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Destination" "${DESTINATION_DIR}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    echo ""

    add_event "S3_TRANSFER_START" "Successful" \
        "Syncing files to S3" \
        "Source: ${FILE_NAME} | Bucket: s3://${S3_BUCKET}/${DESTINATION_DIR}"

    if [ -n "$PROFILE" ]; then
        aws s3 sync "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}" --profile "$PROFILE"
    else
        aws s3 sync "${FILE_NAME}" "s3://${S3_BUCKET}/${DESTINATION_DIR}"
    fi
    TASK_STATUS=$?

    if [ "$TASK_STATUS" -eq 0 ]; then
        logInfoMessage "> [UploadSync] S3 sync completed successfully (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Successful" \
            "S3 sync completed successfully" \
            "Source: ${FILE_NAME} | Destination: s3://${S3_BUCKET}/${DESTINATION_DIR}"
    else
        logErrorMessage "> [UploadSync] S3 sync failed (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Failed" \
            "S3 sync failed — check AWS credentials and bucket permissions" \
            "Source: ${FILE_NAME} | Bucket: ${S3_BUCKET} | Exit Code: ${TASK_STATUS}"
    fi
    saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
}

downloadSingleFile() {
    logInfoMessage "> [DownloadSingle] Starting single file download..."
    _assumeRoleIfRequired "DownloadSingle"

    mkdir -p "${DESTINATION_DIR}"

    echo ""
    echo "> Download Single File Summary"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Parameter" "Value"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Source" "s3://${S3_BUCKET}/${FILE_NAME}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Destination" "${DESTINATION_DIR}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    echo ""

    add_event "S3_TRANSFER_START" "Successful" \
        "Downloading single file from S3" \
        "Source: s3://${S3_BUCKET}/${FILE_NAME} | Destination: ${DESTINATION_DIR}"

    if [ -n "$PROFILE" ]; then
        aws s3 cp "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}" --profile "$PROFILE"
    else
        aws s3 cp "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}"
    fi
    TASK_STATUS=$?

    if [ "$TASK_STATUS" -eq 0 ]; then
        logInfoMessage "> [DownloadSingle] File downloaded successfully (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Successful" \
            "Single file downloaded successfully" \
            "Source: s3://${S3_BUCKET}/${FILE_NAME} | Destination: ${DESTINATION_DIR}"
    else
        logErrorMessage "> [DownloadSingle] Download failed (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Failed" \
            "Single file download failed — check S3 path and credentials" \
            "Source: s3://${S3_BUCKET}/${FILE_NAME} | Exit Code: ${TASK_STATUS}"
    fi
    saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
}

downloadRecursive() {
    logInfoMessage "> [DownloadRecursive] Starting recursive download..."
    _assumeRoleIfRequired "DownloadRecursive"

    echo ""
    echo "> Download Recursive Summary"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Parameter" "Value"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Source" "s3://${S3_BUCKET}/${FILE_NAME}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Destination" "${DESTINATION_DIR}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    echo ""

    add_event "S3_TRANSFER_START" "Successful" \
        "Downloading files recursively from S3" \
        "Source: s3://${S3_BUCKET}/${FILE_NAME} | Destination: ${DESTINATION_DIR}"

    if [ -n "$PROFILE" ]; then
        aws s3 cp "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}" --recursive --profile "$PROFILE"
    else
        aws s3 cp "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}" --recursive
    fi
    TASK_STATUS=$?

    if [ "$TASK_STATUS" -eq 0 ]; then
        logInfoMessage "> [DownloadRecursive] Recursive download completed successfully (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Successful" \
            "Recursive download completed successfully" \
            "Source: s3://${S3_BUCKET}/${FILE_NAME} | Destination: ${DESTINATION_DIR}"
    else
        logErrorMessage "> [DownloadRecursive] Recursive download failed (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Failed" \
            "Recursive download failed — check S3 path and credentials" \
            "Source: s3://${S3_BUCKET}/${FILE_NAME} | Exit Code: ${TASK_STATUS}"
    fi
    saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
}

downloadSync() {
    logInfoMessage "> [DownloadSync] Starting S3 sync download..."
    _assumeRoleIfRequired "DownloadSync"

    echo ""
    echo "> Download Sync Summary"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Parameter" "Value"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Source" "s3://${S3_BUCKET}/${FILE_NAME}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Destination" "${DESTINATION_DIR}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    echo ""

    add_event "S3_TRANSFER_START" "Successful" \
        "Syncing files from S3" \
        "Source: s3://${S3_BUCKET}/${FILE_NAME} | Destination: ${DESTINATION_DIR}"

    if [ -n "$PROFILE" ]; then
        aws s3 sync "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}" --profile "$PROFILE"
    else
        aws s3 sync "s3://${S3_BUCKET}/${FILE_NAME}" "${DESTINATION_DIR}"
    fi
    TASK_STATUS=$?

    if [ "$TASK_STATUS" -eq 0 ]; then
        logInfoMessage "> [DownloadSync] Sync download completed successfully (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Successful" \
            "S3 sync download completed successfully" \
            "Source: s3://${S3_BUCKET}/${FILE_NAME} | Destination: ${DESTINATION_DIR}"
    else
        logErrorMessage "> [DownloadSync] Sync download failed (exit: ${TASK_STATUS})"
        add_event "S3_TRANSFER_COMPLETE" "Failed" \
            "S3 sync download failed — check S3 path and credentials" \
            "Source: s3://${S3_BUCKET}/${FILE_NAME} | Exit Code: ${TASK_STATUS}"
    fi
    saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"
}

# ---------------------------------------------------------------
# 5. Operation Dispatch
# ---------------------------------------------------------------
logInfoMessage "> Dispatching operation: ${OPERATION}"

case "$OPERATION" in
    UploadSingle)    uploadSingleFile ;;
    UploadRecursive) uploadRecursiveFile ;;
    UploadRename)    renameAndUpload ;;
    UploadSync)      syncToS3 ;;
    DownloadSingle)  downloadSingleFile ;;
    DownloadRecursive) downloadRecursive ;;
    DownloadSync)    downloadSync ;;
    *)
        logErrorMessage "> Unsupported operation: '${OPERATION}'"
        add_event "OPERATION_DISPATCH" "Failed" \
            "Unsupported operation: '${OPERATION}'" \
            "Allowed: UploadSingle | UploadRecursive | UploadRename | UploadSync | DownloadSingle | DownloadRecursive | DownloadSync"
        saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
        exit 1
        ;;
esac