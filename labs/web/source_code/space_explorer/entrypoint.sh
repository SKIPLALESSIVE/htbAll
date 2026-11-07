#!/bin/bash
set -e

cleanup() {
    kill -TERM "$GUNICORN_PID" "$GOAPP_PID" 2>/dev/null
}
trap cleanup TERM INT

python -m gunicorn --workers 4 -b 127.0.0.1:8081 app:app &
GUNICORN_PID=$!

docker-gs-ping &
GOAPP_PID=$!

wait -n "$GUNICORN_PID" "$GOAPP_PID"
cleanup
wait
