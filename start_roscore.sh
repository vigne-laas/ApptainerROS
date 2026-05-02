#!/usr/bin/env bash
# Lance roscore dans le conteneur archi en arrière-plan (host).
# Tous les nodes lances ensuite via ros1exec / make exec / tmux le verront
# automatiquement (Apptainer utilise le reseau du host par defaut, donc
# ROS_MASTER_URI=http://localhost:11311 fonctionne entre tous les exec).

set -eu

APPTAINER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${APPTAINER_ROOT}/../logs"
mkdir -p "$LOG_DIR"

PIDFILE="${LOG_DIR}/roscore.pid"
LOGFILE="${LOG_DIR}/roscore.log"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "roscore tourne deja (PID $(cat "$PIDFILE"))"
    echo "  Log : $LOGFILE"
    exit 0
fi

# Lance roscore via ros1exec en background, redirige les logs
"${APPTAINER_ROOT}/ros1exec" roscore > "$LOGFILE" 2>&1 &
echo $! > "$PIDFILE"

# Petit delai pour verifier que roscore demarre bien
sleep 2
if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "roscore a fail a demarrer. Verifie $LOGFILE" >&2
    rm -f "$PIDFILE"
    exit 1
fi

echo "roscore lance"
echo "  PID  : $(cat "$PIDFILE")"
echo "  Log  : $LOGFILE"
echo "  Stop : ./stop_roscore.sh"
