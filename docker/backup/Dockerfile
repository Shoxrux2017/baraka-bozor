# The backup container (DL-104 (6)): pg_dump of the database and restic of the
# dump and the product images, nightly, plus a weekly integrity check. Alpine
# keeps it small; its postgresql17-client matches the server (postgres:17).
FROM alpine:3.24

# postgresql17-client: pg_dump and psql; restic: encrypted, deduplicated copies;
# supercronic: a cron that runs unprivileged and logs to stdout; tzdata: so TZ
# below means Tashkent.
RUN apk add --no-cache postgresql17-client restic supercronic tzdata \
    && adduser -D -u 10001 backup \
    && mkdir -p /backup/db /backup/images /status \
    && chown backup:backup /backup/db /status

ENV TZ=Asia/Tashkent

COPY --chmod=0755 backup.sh check.sh /usr/local/bin/
COPY --chmod=0644 lib.sh /usr/local/bin/
COPY crontab /etc/backup/crontab

USER backup

CMD ["supercronic", "/etc/backup/crontab"]
