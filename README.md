## BP-S3-UPLOADER-STEP
I'll let people to upload file in s3 bucket via this step

### Setup
* Clone the code available at [BP-S3-UPLOADER-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-S3-UPLOADER-STEP)
* Build the docker image

```shell
git submodule init
```
```shell
git submodule update
```
```shell
docker build -t registry.buildpiper.in/s3-uploader:multiple_push-0.8 .
```

* Do local testing via image only

```shell
# upload with default 
docker run -it --rm -v $PWD:/src -e WORKSPACE=/src -e CODEBASE_DIR=/ registry.buildpiper.in/s3-uploader:multiple_push-0.8
```

```shell
# upload with specific bucket name and file to be uploaded
docker run -it --rm -v $PWD:/src \
 -e WORKSPACE=/src -e CODEBASE_DIR=/ \
 -e CSV_DATA="" \
 -e VALIDATION_FAILURE_ACTION="" \
 -e ASSUME_OTHER_ROLE="" \
 -e S3_BUCKET="" \
 -e JSON_FILEPATH="" \
 -e ENV="dev" \
 registry.buildpiper.in/s3-uploader:multiple_push-0.8
```

```shell
#debug
docker run -it --rm -v $PWD:/src \
 -e WORKSPACE=/src -e CODEBASE_DIR=/ \
 -e CSV_DATA="" \
 -e VALIDATION_FAILURE_ACTION="" \
 -e ASSUME_OTHER_ROLE="" \
 -e S3_BUCKET="" \
 -e JSON_FILEPATH="" \
 -e ENV="dev" \
 -e entrypoint bash registry.buildpiper.in/s3-uploader:multiple_push-0.8
```