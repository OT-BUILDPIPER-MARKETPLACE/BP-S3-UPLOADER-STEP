#!/bin/bash

# Function to upload files to S3 from a CSV string
upload_files_from_csv_to_s3() {
    local csv_data=$1
    local warning_flag="0"

    # Check if the CSV data is provided and not empty
    if [[ -z "$csv_data" ]]; then
        logErrorMessage "CSV data is required."
        return 1
    fi
    logInfoMessage "Expected CSV format: <TARGET_S3_BUCKET>,<S3_KEY_PREFIX>,<LOCAL_ROOT_DIR>,<LOCAL_FILE_NAME>" > /dev/null 2>&1

    # Read and process each line of CSV data without subshell
    while IFS=',' read -r TARGET_S3_BUCKET S3_KEY_PREFIX LOCAL_ROOT_DIR LOCAL_FILE_NAME; do
        # Skip empty or commented lines
        [[ -z "$TARGET_S3_BUCKET" || "$TARGET_S3_BUCKET" =~ ^# ]] && continue

        # Check if all required fields are provided
        if [[ -z "$TARGET_S3_BUCKET" || -z "$S3_KEY_PREFIX" || -z "$LOCAL_ROOT_DIR" || -z "$LOCAL_FILE_NAME" ]]; then
            logWarningMessage "Missing required fields in CSV line: $TARGET_S3_BUCKET, $S3_KEY_PREFIX, $LOCAL_ROOT_DIR, $LOCAL_FILE_NAME" > /dev/null 2>&1
            warning_flag="1"
            continue
        fi

        if ! bucketExist "${TARGET_S3_BUCKET}"; then
            logErrorMessage "Unable to access S3 bucket ${TARGET_S3_BUCKET}. Check if it exists and permissions are correct."
            warning_flag="1"
            continue
        fi

        # Construct the full path of the local file and the S3 object key
        local_file_path="${LOCAL_ROOT_DIR}/${LOCAL_FILE_NAME}"
        s3_object_key="${S3_KEY_PREFIX}/${LOCAL_FILE_NAME}"

        # Log which file is being uploaded
        logInfoMessage "Uploading file: $local_file_path to S3 bucket: $TARGET_S3_BUCKET with S3 object key: $s3_object_key"

        # Perform the upload
        aws s3 cp "$local_file_path" "s3://${TARGET_S3_BUCKET}/${s3_object_key}"
        if [ $? -ne 0 ]; then
            logWarningMessage "Failed to upload $local_file_path"
            warning_flag="1"
            continue
        fi
    done <<< "$(echo "$csv_data" | tr ' ' '\n')"

    # Check warning flag and return appropriate status
    if [[ $warning_flag -ne 0 ]]; then
        logWarningMessage "Some files upload failed. Please check."
        return 1
    else
        logInfoMessage "All files uploaded successfully."
        return 0
    fi
}