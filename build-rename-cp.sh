#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

sleep  $SLEEP_DURATION

if [ "$ASSUME_OTHER_ROLE" == true ]
then 
	role_output=$(aws sts assume-role --role-arn arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME --role-session-name $ROLE_SESSION_NAME)

	# Check if the assume-role command was successful
	if [ $? -ne 0 ]; then
	  echo "Failed to assume role."
	  exit 1
	fi

    

	# Parse the JSON output and set environment variables
	AWS_ACCESS_KEY_ID=$(echo $role_output | jq -r '.Credentials.AccessKeyId')
	AWS_SECRET_ACCESS_KEY=$(echo $role_output | jq -r '.Credentials.SecretAccessKey')
	AWS_SESSION_TOKEN=$(echo $role_output | jq -r '.Credentials.SessionToken')

	# Export the variables
	export AWS_ACCESS_KEY_ID
	export AWS_SECRET_ACCESS_KEY
	export AWS_SESSION_TOKEN
fi 

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"

cd  "${CODEBASE_LOCATION}"


tag=$(cat version)

logInfoMessage "Received below arguments"
logInfoMessage "Tag Version: [$tag]"
logInfoMessage "Artifact Path: [$ARTIFACT_PATH]"
logInfoMessage "Old Artifact Name: [$ARTIFACT_OLD_NAME]"
logInfoMessage "New Artifact Name: [$ARTIFACT_NEW_NAME]"

mv "$ARTIFACT_PATH/$ARTIFACT_OLD_NAME" "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME"

logInfoMessage "Artifact Name successfully changed: [${tag}-$ARTIFACT_NEW_NAME]"

logInfoMessage "S3 Bucket: ${S3_BUCKET}"

logInfoMessage "Running AWS upload command: aws s3 cp \"$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME\" \"$S3_BUCKET\""

aws s3 cp "$ARTIFACT_PATH/${tag}-$ARTIFACT_NEW_NAME" "${S3_BUCKET}"

TASK_STATUS=$?
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}