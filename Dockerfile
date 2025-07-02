FROM amazon/aws-cli

RUN yum update -y && \
    yum install -y jq shadow-utils && \
    useradd -m -s /bin/bash buildpiper

RUN mkdir -p /opt/buildpiper/shell-functions && \
    chown -R buildpiper:buildpiper /opt/buildpiper && \
    chown -R buildpiper:buildpiper /home/buildpiper


USER buildpiper

WORKDIR /home/buildpiper

COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
COPY --chown=buildpiper:buildpiper build.sh .

ENV SLEEP_DURATION="5s"
ENV VALIDATION_FAILURE_ACTION=""

RUN chmod +x /home/buildpiper/build.sh

ENTRYPOINT ["./build.sh"]
