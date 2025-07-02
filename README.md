## BP-S3-UPLOADER-STEP
I'll let people to upload file in s3 bucket via this step

### Setup
* Clone the code available at [BP-S3-UPLOADER-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-S3-UPLOADER-STEP)

---

````markdown
# Dockerfile Change Log (New Version)

This file documents the changes introduced in the **new Dockerfile** compared to the previous version.

---

## Changes Introduced

### 1. Installed additional package and created non-root user
```dockerfile
yum install -y jq shadow-utils && \
useradd -m -s /bin/bash buildpiper
````

* `shadow-utils` added to enable `useradd`
* Created user `buildpiper` with home directory and bash shell

---

### 2. Created and changed ownership of directories

```dockerfile
RUN mkdir -p /opt/buildpiper/shell-functions && \
    chown -R buildpiper:buildpiper /opt/buildpiper && \
    chown -R buildpiper:buildpiper /home/buildpiper
```

* Ensures non-root user has write access to needed directories

---

### 3. Switched to non-root user

```dockerfile
USER buildpiper
```

* Improves container security

---

### 4. Set working directory

```dockerfile
WORKDIR /home/buildpiper
```

* Specifies the working directory for all following commands

---

### 5. Used `--chown` for file copying
#
```dockerfile
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
COPY --chown=buildpiper:buildpiper build.sh .
```

* Ensures correct file ownership during image build

---

* Build the docker image

```shell
docker build -t non-root
```

* Do local testing via image only

```shell
# upload with default 
docker run -it --rm -v $PWD:/src -v ~/.aws:/home/buildpiper/.aws  -e S3_BUCKET=buildpiper-impl-kt-v1 -e DESTINATION_DIR=test -e FILE_NAME=/src -e PROFILE=default non-root
```

```shell
#debug
docker run -it --rm -v $PWD:/src -v ~/.aws:/home/buildpiper/.aws -e S3_BUCKET=buildpiper-impl-kt-v1 -e DESTINATION_DIR=test -e FILE_NAME=/src -e PROFILE=default -e DEBUG=true non-root
```
---

### Docker Imgae Tag

old Docker images tag:- `registry.buildpiper.in/s3-uploader-step:solv-0.0.1`

new Docker images tag:- `pending`


