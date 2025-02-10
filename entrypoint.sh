#!/bin/sh

# Set correct permissions on PostgreSQL data directory
chown -R postgres:postgres /var/lib/postgresql/data
chmod -R 700 /var/lib/postgresql/data

# Process the config template
envsubst < /etc/patroni/config.template.yml > /etc/patroni/config.yml

# Execute Patroni
exec patroni /etc/patroni/config.yml