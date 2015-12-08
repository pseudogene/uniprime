#!/bin/sh

USER="$1"
DB="uniprime"
PSQL="psql -q -n -A -t"

if [ -z "$1" ]; then
        echo No name given
        exit
fi

echo "-- Granting rights on $DB to $USER"

Q="SELECT 'GRANT ALL ON TABLE '||tablename||' TO \"$USER\";' FROM pg_tables WHERE schemaname IN ('public');"

$PSQL -c "$Q" "$DB";

