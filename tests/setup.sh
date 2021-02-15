#!/bin/bash

set -e
set -x

# Build Docker image
docker build -t selfhostingtools/nsd:latest .

# Create test container
docker run \
    -d \
    --name nsd \
    --read-only \
    --tmpfs /tmp --tmpfs /var/db/nsd \
    -v "$(pwd)/tests/resources/conf":/etc/nsd:ro \
    -v "$(pwd)/tests/resources/zones":/zones \
    -v "$(pwd)/tests/resources/keys":/keys \
    -t selfhostingtools/nsd:latest

sleep 2

exit 0
