#!/bin/bash

echo "Step 0: Building and starting containers..."
cd "$(dirname "$0")/.." || exit
docker compose down -v
docker compose build
docker compose up -d

echo "Waiting for cluster to initialize (30 seconds)..."
sleep 60

echo "Step 1: Checking cluster status..."
CLUSTER_STATUS=$(curl -s http://localhost:8008/cluster)
echo "$CLUSTER_STATUS" | jq .

# Get initial leader info
LEADER_INFO=$(echo "$CLUSTER_STATUS" | jq -r '.members[] | select(.role=="leader")')
LEADER_NAME=$(echo "$LEADER_INFO" | jq -r '.name')
LEADER_PORT=$(docker port "$LEADER_NAME" 5432/tcp | cut -d ':' -f2)

echo "\nInitial leader is: $LEADER_NAME on host port $LEADER_PORT"

echo "\nStep 2: Creating test database and table on leader..."
PGPASSWORD=postgres psql -h localhost -p "$LEADER_PORT" -U postgres -c "CREATE DATABASE test_db;"
PGPASSWORD=postgres psql -h localhost -p "$LEADER_PORT" -U postgres -d test_db -c "CREATE TABLE test_table (id serial PRIMARY KEY, name VARCHAR(50));"
PGPASSWORD=postgres psql -h localhost -p "$LEADER_PORT" -U postgres -d test_db -c "INSERT INTO test_table (name) VALUES ('test_data');"

echo "\nStep 3: Verifying data on replicas..."

# Get replica info
REPLICA_INFO=$(echo "$CLUSTER_STATUS" | jq -r '.members | map(select(.role == "replica")) | first')
REPLICA_NAME=$(echo "$REPLICA_INFO" | jq -r '.name')
REPLICA_PORT=$(docker port "$REPLICA_NAME" 5432/tcp | cut -d ':' -f2)

echo "Found replica: $REPLICA_NAME on port $REPLICA_PORT"
echo "Verifying replicated data:"
PGPASSWORD=postgres psql -h localhost -p "$REPLICA_PORT" -U postgres -d test_db -c "SELECT * FROM test_table;"

echo "\nStep 4: Simulating failover by stopping leader..."
docker stop "$LEADER_NAME"

echo "\nStep 5: Waiting for failover (10 seconds)..."
sleep 30

echo "\nStep 6: Checking new cluster status..."
NEW_CLUSTER_STATUS=$(curl -s http://localhost:8008/cluster)
echo "$NEW_CLUSTER_STATUS" | jq .

# Get new leader info
NEW_LEADER_INFO=$(echo "$NEW_CLUSTER_STATUS" | jq -r '.members[] | select(.role=="leader")')
NEW_LEADER_NAME=$(echo "$NEW_LEADER_INFO" | jq -r '.name')
NEW_LEADER_PORT=$(docker port "$NEW_LEADER_NAME" 5432/tcp | cut -d ':' -f2)

echo "\nStep 7: Verifying data consistency after failover..."
PGPASSWORD=postgres psql -h localhost -p "$NEW_LEADER_PORT" -U postgres -d test_db -c "SELECT * FROM test_table;"

echo "\nStep 8: Inserting new data into new leader..."
PGPASSWORD=postgres psql -h localhost -p "$NEW_LEADER_PORT" -U postgres -d test_db -c "INSERT INTO test_table (name) VALUES ('post_failover_data');"

echo "\nStep 9: Verifying replication on remaining replicas..."

# Get new replica info
NEW_REPLICA_INFO=$(echo "$NEW_CLUSTER_STATUS" | jq -r '.members | map(select(.role == "replica")) | first')
NEW_REPLICA_NAME=$(echo "$NEW_REPLICA_INFO" | jq -r '.name')
NEW_REPLICA_PORT=$(docker port "$NEW_REPLICA_NAME" 5432/tcp | cut -d ':' -f2)

echo "Found replica: $NEW_REPLICA_NAME on port $NEW_REPLICA_PORT"
echo "Verifying replicated data:"
PGPASSWORD=postgres psql -h localhost -p "$NEW_REPLICA_PORT" -U postgres -d test_db -c "SELECT * FROM test_table ORDER BY id;"

echo "\nStep 10: Cleaning up..."
docker compose down -v
rm -rf pg_data*

echo "\nTest completed successfully!"