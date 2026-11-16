#!/bin/sh
# Final target of the upstream entrypoint: set up or upgrade, hide the
# "automatic credentials" card, then start supervisord (web + workers + beat).
set -e

if [ ! -f /var/lib/mayan/system/SECRET_KEY ]; then
    echo "First start: running Mayan's initial setup."
    runuser --user mayan -- "${MAYAN_BIN}" common_initial_setup --force --no-dependencies
else
    echo "Existing installation: running Mayan's upgrade step."
    runuser --user mayan -- "${MAYAN_BIN}" common_perform_upgrade --no-dependencies
fi

# The admin password comes from MAYAN_ADMIN_PASSWORD, so never show it on the
# public login page.
runuser --user mayan -- "${MAYAN_BIN}" shell -c "from mayan.apps.autoadmin.models import AutoAdminSingleton; AutoAdminSingleton.objects.update(account=None, password=None, password_hash=None)"

exec /usr/local/bin/run_all.sh
