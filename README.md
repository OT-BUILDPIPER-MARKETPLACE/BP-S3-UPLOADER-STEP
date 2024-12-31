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
docker build -t registry.buildpiper.in/s3-uploader:<image_tag> .
```

* Do local testing via image only

```shell
# upload with default 
docker run -it --rm -v $PWD:/src -e WORKSPACE=/src -e CODEBASE_DIR=/ registry.buildpiper.in/s3-uploader:<image_tag>
```

```shell
# upload with specific bucket name and file to be uploaded
docker run -it --rm -v $PWD:/src  -e FILE_TO_BE_UPLOADED=build.sh -e S3_BUCKET=test -e WORKSPACE=/src -e CODEBASE_DIR=/ registry.buildpiper.in/s3-uploader:<image_tag>
```

```shell
#debug
docker run -it --rm -v $PWD:/src -e WORKSPACE=/src -e CODEBASE_DIR=/ -e entrypoint bash registry.buildpiper.in/s3-uploader:<image_tag> 
```