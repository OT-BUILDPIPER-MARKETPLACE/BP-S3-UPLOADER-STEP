# bp_s3uploader_step
I'll let people to upload file in s3 bucket via this step

## Setup
* Clone the code available at [BP-S3-UPLOADER-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-S3-UPLOADER-STEP)
* Build the docker image

```
git submodule init
git submodule update
docker build -t ot/s3-uploader-step:0.1 .
```

* Do local testing via image only

```
# upload with default 
docker run -it --rm -v $PWD:/src -e WORKSPACE=/src -e CODEBASE_DIR=/ ot/s3-uploader-step:0.1

# upload with specific bucket name and file to be uploaded
docker run -it --rm -v $PWD:/src  -e FILE_TO_BE_UPLOADED=build.sh -e S3_BUCKET=test -e WORKSPACE=/src -e CODEBASE_DIR=/ ot/s3-uploader-step:0.0.1

#debug
docker run -it --rm -v $PWD:/src -e WORKSPACE=/src -e CODEBASE_DIR=/ -e entrypoint bash ot/s3-uploader-step:0.1 
```