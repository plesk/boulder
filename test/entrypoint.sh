#!/usr/bin/env bash

set -e -u

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Configure database URL symlinks
# This is required for `docker compose up` to work after commit 2197eeac7
# which reorganized database URL files into subdirectories.
# Without this, services fail with "no such file or directory" errors.
# NOTE: Added for Plesk deployment compatibility where test.sh is not used.
configure_database_endpoints() {
  local dburl_target_dir="proxysql"

  # Check if Vitess should be used instead of ProxySQL + MariaDB
  if [[ "${USE_VITESS:-false}" == "true" ]]; then
    dburl_target_dir="vitess"
    echo "Using Vitess + MySQL 8.4"
  else
    echo "Using ProxySQL + MariaDB"
  fi

  # List of database URL files that need symlinks
  local db_url_files=(
    badkeyrevoker_dburl
    cert_checker_dburl
    incidents_dburl
    revoker_dburl
    sa_dburl
    sa_ro_dburl
  )

  echo "Configuring database URL symlinks from dburls/${dburl_target_dir}/ ..."

  # Remove any existing symlinks to avoid conflicts
  rm -f "${DIR}/../test/secrets/"*_dburl 2>/dev/null || true

  # Create symlinks from the appropriate subdirectory
  for file in "${db_url_files[@]}"; do
    ln -sf "dburls/${dburl_target_dir}/${file}" "${DIR}/../test/secrets/${file}"
  done

  echo "Database URL symlinks configured successfully"
}

# Execute database endpoint configuration
configure_database_endpoints

# Start rsyslog. Note: Sometimes for unknown reasons /var/run/rsyslogd.pid is
# already present, which prevents the whole container from starting. We remove
# it just in case it's there.
rm -f /var/run/rsyslogd.pid
rsyslogd

# make sure we can reach mariadb and proxysql
./test/wait-for-it.sh boulder-mariadb 3306
./test/wait-for-it.sh boulder-proxysql 6033

# make sure we can reach vitess
./test/wait-for-it.sh boulder-vitess 33577

# make sure we can reach pkilint
./test/wait-for-it.sh bpkimetal 8080

# create the databases
MYSQL_CONTAINER=1 \
DB_HOST="boulder-mariadb" \
DB_PORT=3306 \
DB_CONFIG_FILE="${DIR}/../sa/db/dbconfig.mariadb.yml" \
SKIP_CREATE=0 \
SKIP_USERS=0 \
"$DIR/create_db.sh"

MYSQL_CONTAINER=1 \
DB_HOST="boulder-vitess" \
DB_PORT=33577 \
DB_CONFIG_FILE="${DIR}/../sa/db/dbconfig.mysql8.yml" \
SKIP_CREATE=1 \
SKIP_USERS=1 \
"$DIR/create_db.sh"

if [[ $# -eq 0 ]]; then
    exec python3 ./start.py
fi

exec "$@"
