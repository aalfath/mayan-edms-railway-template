#!/bin/sh
# Railway wrapper for the official Mayan EDMS image.
# Turns Railway's DATABASE_URL and REDIS_URL into Mayan's settings, sets
# sensible defaults for a small container, then hands over to the upstream
# entrypoint, which runs railway-run.sh as its final target.
set -e

: "${DATABASE_URL:?DATABASE_URL is not set (reference your Postgres service)}"
: "${REDIS_URL:?REDIS_URL is not set (reference your Redis service)}"

# Parse the URLs with the image's own Python and export Mayan's settings.
eval "$(/opt/mayan-edms/bin/python3 -I - <<'PY'
import json, os, shlex
from urllib.parse import urlsplit, unquote

db = urlsplit(os.environ["DATABASE_URL"])
databases = {"default": {
    "ENGINE": "django.db.backends.postgresql",
    "NAME": unquote(db.path.lstrip("/")) or "railway",
    "USER": unquote(db.username or ""),
    "PASSWORD": unquote(db.password or ""),
    "HOST": db.hostname,
    "PORT": str(db.port or 5432),
    "CONN_MAX_AGE": 0,
}}
r = urlsplit(os.environ["REDIS_URL"])
base = "{}://{}".format(r.scheme, r.netloc)

def out(k, v):
    print("export {}={}".format(k, shlex.quote(v)))

out("MAYAN_DATABASES", json.dumps(databases))
out("MAYAN_CELERY_BROKER_URL", base + "/0")
out("MAYAN_CELERY_RESULT_BACKEND", base + "/1")
out("MAYAN_LOCK_MANAGER_BACKEND", "mayan.apps.lock_manager.backends.redis_lock.RedisLock")
out("MAYAN_LOCK_MANAGER_BACKEND_ARGUMENTS", json.dumps({"redis_url": base + "/2"}))
out("MAYAN_SERVER_SIDE_EVENTS_BACKEND", "mayan.apps.server_side_events.sse_backends.redis.RedisServerEventStreamBackend")
out("MAYAN_SERVER_SIDE_EVENTS_BACKEND_ARGUMENTS", json.dumps({"url": base + "/3"}))
out("MAYAN_DOCKER_WAIT_DEFAULT", "{}:{} {}:{}".format(db.hostname, db.port or 5432, r.hostname, r.port or 6379))
PY
)"
export MAYAN_DOCKER_WAIT="${MAYAN_DOCKER_WAIT:-$MAYAN_DOCKER_WAIT_DEFAULT}"

# First administrator: created once, on the first start, from these values.
# The upstream image would otherwise show a random password on the public
# login page; railway-run.sh hides that card after setup.
: "${MAYAN_ADMIN_PASSWORD:?MAYAN_ADMIN_PASSWORD is not set}"
export MAYAN_AUTOADMIN_USERNAME="${MAYAN_ADMIN_USERNAME:-admin}"
export MAYAN_AUTOADMIN_EMAIL="${MAYAN_ADMIN_EMAIL:-admin@example.com}"
export MAYAN_AUTOADMIN_PASSWORD="$MAYAN_ADMIN_PASSWORD"

# Railway's proxy terminates HTTPS and sends X-Forwarded-Proto.
export MAYAN_SECURE_PROXY_SSL_HEADER="${MAYAN_SECURE_PROXY_SSL_HEADER:-['HTTP_X_FORWARDED_PROTO', 'https']}"
if [ -n "$RAILWAY_PUBLIC_DOMAIN" ] && [ -z "$MAYAN_CSRF_TRUSTED_ORIGINS" ]; then
    export MAYAN_CSRF_TRUSTED_ORIGINS="['https://${RAILWAY_PUBLIC_DOMAIN}']"
fi

# Listen on Railway's PORT, on IPv4 and IPv6.
export MAYAN_GUNICORN_BIND_ADDRESS="${MAYAN_GUNICORN_BIND_ADDRESS:-[::]:${PORT:-8000}}"
export MAYAN_GUNICORN_WORKERS="${MAYAN_GUNICORN_WORKERS:-2}"

# Smaller worker pools than upstream (23 processes) so the container fits a
# few GB of RAM. Raise them with variables for heavy OCR loads.
export MAYAN_WORKER_A_CONCURRENCY="${MAYAN_WORKER_A_CONCURRENCY:-2}"
export MAYAN_WORKER_B_CONCURRENCY="${MAYAN_WORKER_B_CONCURRENCY:-2}"
export MAYAN_WORKER_C_CONCURRENCY="${MAYAN_WORKER_C_CONCURRENCY:-1}"
export MAYAN_WORKER_D_CONCURRENCY="${MAYAN_WORKER_D_CONCURRENCY:-1}"
export MAYAN_WORKER_E_CONCURRENCY="${MAYAN_WORKER_E_CONCURRENCY:-1}"
export MAYAN_WORKER_F_CONCURRENCY="${MAYAN_WORKER_F_CONCURRENCY:-1}"

# Restart a crashed worker instead of leaving it down.
export MAYAN_SUPERVISOR_AUTORESTART="${MAYAN_SUPERVISOR_AUTORESTART:-true}"

exec /usr/local/bin/entrypoint.sh /usr/local/bin/railway-run.sh
