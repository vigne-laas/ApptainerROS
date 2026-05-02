#!/usr/bin/env bash
set -eu

APPTAINER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDFILE="${APPTAINER_ROOT}/../logs/roscore.pid"

if [ ! -f "$PIDFILE" ]; then
    echo "Pas de PIDfile ($PIDFILE) -- roscore n'est pas suivi par ce script."
    exit 0
fi

PID="$(cat "$PIDFILE")"
if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    sleep 1
    if kill -0 "$PID" 2>/dev/null; then
        kill -9 "$PID"
    fi
    echo "roscore stoppe (PID $PID)"
else
    echo "PID $PID deja mort"
fi
rm -f "$PIDFILE"
