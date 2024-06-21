#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh

sleep  "$SLEEP_DURATION"
#logInfoMessage "I'll upload [$FILE] to the [$S3_BUCKET] bucket and have mounted at [${CODEBASE_DIR}/$FILE_DIR}]"

if [ -f $FILE ]
then 
elif [ $S3_BUCKET ]
else logInfoMessage "Failure."
fi
fi



# if [ $? -eq 0 ]
# then
#     logInfoMessage "Congratulations file is uploaded successfully to s3 bucket!!!"
#     generateOutput ${ACTIVITY_SUB_TASK_CODE} build true "Congratulations ami created sucessfully "
# elif [ "${VALIDATION_FAILURE_ACTION}" == "FAILURE" ]
#     then
#     logErrorMessage "Please check upload failed!!!"
#     generateOutput ${ACTIVITY_SUB_TASK_CODE} false "Please check upload failed!!!"
#     exit 1
#     else
#     logWarningMessage "Please check upload failed!!!"
#     generateOutput ${ACTIVITY_SUB_TASK_CODE} true "Please check upload failed!!!"
# fi 