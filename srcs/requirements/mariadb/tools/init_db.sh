#!/bin/sh

set -e

envsubst '$DB_PORT,$DB_USER,$DB_DATADIR' < /etc/mariadb-server.cnf.template > /etc/my.cnf.d/mariadb-server.cnf

DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_PASSWORD=$(cat /run/secrets/db_password)

if [ ! -d "$DB_DATADIR/mysql" ]; then
	echo "Initializing MariaDB configuration"

	mariadb-install-db --user=mysql --datadir="$DB_DATADIR"
	TMP_FILE="/tmp/init_db.sql"

	cat << EOF > $TMP_FILE
FLUSH PRIVILEGES;

ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
CREATE USER IF NOT EXISTS 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON  *.* TO 'root'@'localhost' WITH GRANT OPTION;

CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

	mariadbd --user=mysql --datadir="$DB_DATADIR" --bootstrap < $TMP_FILE
	rm -f $TMP_FILE

	echo "MariaDB configuration completed"
else
	echo "Mariadb storage already initialized"
fi

exec mariadbd --defaults-file="/etc/my.cnf.d/mariadb-server.cnf" --console
