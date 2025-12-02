#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION

if [ "$ASSUME_OTHER_ROLE" == true ]
then
    role_output=$(aws sts assume-role --role-arn arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME --role-session-name $ROLE_SESSION_NAME)
    if [ $? -ne 0 ]; then
        echo "Failed to assume role."
        exit 1
    fi
    AWS_ACCESS_KEY_ID=$(echo $role_output | jq -r '.Credentials.AccessKeyId')
    AWS_SECRET_ACCESS_KEY=$(echo $role_output | jq -r '.Credentials.SecretAccessKey')
    AWS_SESSION_TOKEN=$(echo $role_output | jq -r '.Credentials.SessionToken')
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN
fi

cd "${CODEBASE_LOCATION}"

TASK_STATUS=0

if [ `isStrNonEmpty $S3_BUCKET` -ne 0 ]
then
    TASK_STATUS=1
    logErrorMessage "S3 buckets details are not provided please check"
elif [ `isStrNonEmpty ${FOLDER_TO_BE_UPLOADED}` -ne 0 ]
then
    TASK_STATUS=1
    logErrorMessage "Folder to be uploaded not provided please check"
elif [ `isFolderExist ${FOLDER_TO_BE_UPLOADED}` -ne 0 ]
then
    TASK_STATUS=1
    logErrorMessage "Folder to be uploaded does not exist please check"
elif [ `bucketExist ${S3_BUCKET}` -ne 0 ]
then
    TASK_STATUS=1
    logErrorMessage "Unable to access S3 bucket either it doesn't exist or relevant permissions are not given please check!!!!"
fi

logInfoMessage "Received below arguments"
logInfoMessage "File to be uploaded: ${FOLDER_TO_BE_UPLOADED}"
logInfoMessage "S3 Bucket: ${S3_BUCKET}"

# Persistent Build Number Storage in S3
BUILD_NUMBER_FILE="build_number.txt"
S3_BUILD_NUMBER_PATH="s3://${S3_BUCKET}/$BUILD_NUMBER_FILE"

# Check if build_number.txt exists in S3
aws s3 cp "$S3_BUILD_NUMBER_PATH" . 2>/dev/null
if [ $? -ne 0 ]; then
    echo 1 > "$BUILD_NUMBER_FILE"
else
    BUILD_NUMBER=$(cat "$BUILD_NUMBER_FILE")
    BUILD_NUMBER=$((BUILD_NUMBER + 1))
    echo "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"
fi

# Upload updated build number back to S3
aws s3 cp "$BUILD_NUMBER_FILE" "$S3_BUILD_NUMBER_PATH"

CURRENT_TIME=$(date +"%Y-%m-%d-%H%M%S")
REPO_TAG="${BUILD_NUMBER}-${CURRENT_TIME}"

logInfoMessage "Generated repository tag: $REPO_TAG"

# Define zip file name
ZIP_FILE="${FOLDER_TO_BE_UPLOADED}_${REPO_TAG}.zip"
logInfoMessage "Creating zip file: $ZIP_FILE"

# Zip the specified folder
zip -r "$ZIP_FILE" "$FOLDER_TO_BE_UPLOADED"
if [ $? -ne 0 ]; then
    logErrorMessage "Failed to create zip file."
    exit 1
fi
logInfoMessage "Zip file created successfully: $ZIP_FILE"

# Upload the zip file to S3
logInfoMessage "Uploading $ZIP_FILE to S3 bucket: $S3_BUCKET"
copyFileToS3 "$ZIP_FILE" "$S3_BUCKET"
if [ $? -eq 0 ]; then
    logInfoMessage "Successfully uploaded $ZIP_FILE to S3."
else
    logErrorMessage "Failed to upload $ZIP_FILE to S3."
    exit 1
fi
