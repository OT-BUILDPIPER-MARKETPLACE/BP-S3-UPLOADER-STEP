FROM amazon/aws-cli

RUN yum update -y 
RUN yum install jq -y

ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
ADD utilities /opt/buildpiper/shell-functions/

COPY build.sh .

ENV SLEEP_DURATION="5s" 
ENV VALIDATION_FAILURE_ACTION=""
ENV ASSUME_OTHER_ROLE=""
ENV CSV_DATA=""

ENTRYPOINT [ "./build.sh" ]