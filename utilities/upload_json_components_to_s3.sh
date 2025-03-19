#!/bin/bash
#!/bin/bash

# Function to upload files to S3 bucket for all components in a JSON file
upload_json_components_to_s3() {
    local json_filepath=$1
    local warning_flag="0"

# Check S3_BUCKET
    if [[ -z "$S3_BUCKET" ]]; then
        logErrorMessage "S3_BUCKET environment variable is not set."
        return 1
    fi
    if ! bucketExist "${S3_BUCKET}"; then
        logErrorMessage "Unable to access S3 bucket ${S3_BUCKET}. Check if it exists and permissions are correct."
        return 1
    fi

 # Get all component names from the JSON file
    components=$(jq -r 'keys[]' "$json_filepath")

    # Loop through each component
    for component in $components; do
        logInfoMessage "Processing component: $component"

        # Extract data for the current component
        files=$(jq -r ".\"$component\".files[]" "$json_filepath")
        s3_app_folder_name=$(jq -r ".\"$component\".s3_app_folder_name" "$json_filepath")
        dag_files=$(jq -r ".\"$component\".dag_files[]" "$json_filepath")

        # Upload files to the S3 application folder
        logInfoMessage "Uploading files for component '$component' to S3 bucket '$S3_BUCKET/$s3_app_folder_name'..."
        for file in $files; do

            if [[ "$file" == "spark_config" || "$file" == "snowflake_config" ]];then
                filename="${file}_${ENV}.json"
            else
                filename="${file}"
            fi

            if [[ "$ENV" == "dev" ]];then
                if [[ "$file" == "snowflake_config" ]]; then
                    aws s3 cp "${component}/$filename" "s3://${S3_BUCKET}/${FILE_KEY}/${s3_app_folder_name}/$snowflake_config.json"
                    if [ $? -ne 0 ]; then
                        logWarningMessage "Failed to upload $filename"
                        warning_flag="1"
                        continue
                    fi
                else
                    aws s3 cp "${component}/$filename" "s3://${S3_BUCKET}/${FILE_KEY}/${s3_app_folder_name}/"
                    if [ $? -ne 0 ]; then
                        logWarningMessage "Failed to upload $filename"
                        warning_flag="1"
                        continue
                    fi
                fi
            else
                if [[ "$file" == "snowflake_config" ]]; then
                    aws s3 cp "${component}/$filename" "s3://${S3_BUCKET}/${FILE_KEY}/${s3_app_folder_name}_${ENV}/$snowflake_config.json"
                    if [ $? -ne 0 ]; then
                        logWarningMessage "Failed to upload $filename"
                        warning_flag="1"
                        continue
                    fi
                elif [[ "$component" == "common_files" ]];then
                    aws s3 cp "${component}/$filename" "s3://${S3_BUCKET}/${FILE_KEY}/${s3_app_folder_name}/"
                    if [ $? -ne 0 ]; then
                        logWarningMessage "Failed to upload $filename"
                        warning_flag="1"
                        continue
                    fi
                else
                    aws s3 cp "${component}/$filename" "s3://${S3_BUCKET}/${FILE_KEY}/${s3_app_folder_name}_${ENV}/"
                    if [ $? -ne 0 ]; then
                        logWarningMessage "Failed to upload $filename"
                        warning_flag="1"
                        continue
                    fi
                fi
            fi
        done

        # Upload DAG files to S3/dags/ folder, if they exist
        if [[ -n "$dag_files" ]]; then
            logInfoMessage "Uploading DAG files for component '$component' to S3 bucket '$S3_BUCKET/dags'..."
            for dag_file in $dag_files; do
                aws s3 cp "${component}/$dag_file" "s3://$S3_BUCKET/${FILE_KEY}/dags/$dag_file"
                if [ $? -ne 0 ]; then
                    logWarningMessage "Failed to upload $dag_file"
                    warning_flag="1"
                    continue
                fi
            done
        fi
    logInfoMessage "Upload complete for $component."
    done

# Check warning flag and return appropriate status
if [[ $warning_flag -ne 0 ]]; then
    logWarningMessage "Some files upload failed. Please check."
    return 1
else
    logInfoMessage "Upload complete for all json components."
    return 0
fi

}