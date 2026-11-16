# Mayan EDMS on Railway

A Railway template for [Mayan EDMS](https://www.mayan-edms.com), the open-source document management system: upload, OCR, index, tag, version and route documents through workflows from a web UI or its REST API.

**Version:** Mayan EDMS 4.12.2, official image `mayanedms/mayanedms:v4.12.2`, pinned by digest in the [`Dockerfile`](Dockerfile).

## What it deploys

| Service | Source | Purpose |
|---|---|---|
| **Mayan EDMS** | this repo (`Dockerfile`) | Web UI and API (gunicorn), Celery workers (OCR, indexing, file parsing) and Celery beat, all in the upstream all-in-one image. Volume on `/var/lib/mayan` (documents, secret key, caches). Health check: `/authentication/login/`. |
| **Postgres** | Railway Postgres | Database |
| **Redis** | Railway Redis | Celery broker and results, locks and server-side events (databases 0–3) |

The wrapper ([`railway-start.sh`](railway-start.sh), [`railway-run.sh`](railway-run.sh)) only turns Railway's `DATABASE_URL` and `REDIS_URL` into Mayan's settings, sets smaller worker pools than upstream, trusts Railway's HTTPS proxy, and creates the first administrator from a generated password.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `MAYAN_ADMIN_PASSWORD` | `${{secret(24)}}` | Password of the first administrator (username `admin`), created on the first start only. Read it in the service's Variables tab. Changing it later does not change the account's password: change that in Mayan (user menu → Change password). |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Postgres connection. |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Redis connection. |
| `PORT` | `8000` | Port gunicorn listens on. |

Optional, not set by the template: `MAYAN_ADMIN_USERNAME` (default `admin`) and `MAYAN_ADMIN_EMAIL` for the first administrator, any upstream `MAYAN_*` setting (for example SMTP for mailing, `MAYAN_WORKER_B_CONCURRENCY` for more OCR throughput, `MAYAN_CSRF_TRUSTED_ORIGINS` when you add a custom domain). See [Mayan's settings docs](https://docs.mayan-edms.com/chapters/settings.html).

## Updates

The template builds from this repo's `main` branch. When a new Mayan release is pinned here, Railway shows deployers an "update available" notice; applying it rebuilds the service, and Mayan's upgrade step (database migrations) runs on the next start. Read [`CHANGELOG.md`](CHANGELOG.md) before applying an update.

## Local test

`docker compose -f compose.yml up --build`, then open http://localhost:42275 and log in as `admin` with the password from `compose.yml`.
