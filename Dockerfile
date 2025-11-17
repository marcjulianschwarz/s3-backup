FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    aws-cli \
    tzdata \
    dcron

ENV TZ=UTC

RUN mkdir -p /data /logs /scripts

COPY backup.sh /scripts/backup.sh
RUN chmod +x /scripts/backup.sh

COPY entrypoint.sh /scripts/entrypoint.sh
RUN chmod +x /scripts/entrypoint.sh

WORKDIR /scripts

ENTRYPOINT ["/scripts/entrypoint.sh"]
