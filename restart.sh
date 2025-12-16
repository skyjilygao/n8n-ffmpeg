#!/bin/bash

echo "stop..."
docker compose down
sleep 1
echo "start..."
docker compose up -d
