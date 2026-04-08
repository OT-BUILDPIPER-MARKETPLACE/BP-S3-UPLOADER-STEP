FROM amazon/aws-cli


RUN yum update -y && \
    yum install -y jq vim nano shadow-utils

RUN yum install -y shadow-utils && \
    groupadd -g 65522 buildpiper && \
    useradd -u 65522 -g buildpiper -d /home/buildpiper -m buildpiper && \
    mkdir -p /home/buildpiper && chown -R buildpiper:buildpiper /home/buildpiper

RUN mkdir -p \
    /src/reports \
    /bp/data \
    /bp/execution_dir \
    /opt/buildpiper/shell-functions \
    /opt/buildpiper/data \
    /bp/workspace && \
    chown -R buildpiper:buildpiper /src /bp /opt


ENV SLEEP_DURATION 5s
ENV ACTIVITY_SUB_TASK_CODE S3_BUCKET_UPLOADER


COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/


RUN chmod +x /home/buildpiper/build.sh && \
    chown -R buildpiper:buildpiper /bp/workspace && \
    mkdir -p /home/buildpiper/reports && \
    chown -R buildpiper:buildpiper /home/buildpiper


USER buildpiper


WORKDIR /home/buildpiper


ENTRYPOINT ["./build.sh"]
CMD ["upload"]
