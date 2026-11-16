# Mayan EDMS for Railway: the official all-in-one image (gunicorn + Celery
# workers + Celery beat under supervisord), pinned by version and digest.
FROM mayanedms/mayanedms:v4.12.2@sha256:03f7f43a686433e7dfc1151c3df37d8c376149e59b026008a5e846e578f03747

COPY railway-start.sh railway-run.sh /usr/local/bin/
RUN chmod 0755 /usr/local/bin/railway-start.sh /usr/local/bin/railway-run.sh

# Documents, the secret key and caches live in /var/lib/mayan: mount a
# Railway volume there (Railway rejects the Dockerfile VOLUME instruction).
EXPOSE 8000

ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
