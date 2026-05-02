#!/usr/bin/env bash
# Entre dans le conteneur archi et lance tmux (session 'dev').
# Si la session existe deja, on s'y attache.
# Le tmux.conf est dans /etc/tmux.conf de l'image (souris activee).

set -eu

APPTAINER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHI_DIR="${APPTAINER_ROOT}/archi-sandbox"
WS_HOST="$(cd "${APPTAINER_ROOT}/.." && pwd)"

if [ ! -d "$ARCHI_DIR" ]; then
    echo "Erreur: $ARCHI_DIR introuvable. Lance 'make build' d'abord." >&2
    exit 1
fi

# X11 (au cas ou tu veux lancer rqt_console / rviz depuis tmux)
if [ -n "${DISPLAY:-}" ]; then
    xhost +si:localuser:"$USER" >/dev/null 2>&1 || true
fi

NV_FLAG="${NV_FLAG:-}"
[ "${NV:-}" = "1" ] && NV_FLAG="--nv"

X11_BIND=""
[ -d /tmp/.X11-unix ] && X11_BIND="--bind /tmp/.X11-unix:/tmp/.X11-unix"

exec apptainer exec \
    $NV_FLAG \
    --bind "${WS_HOST}:/ws" \
    $X11_BIND \
    "$ARCHI_DIR" \
    bash -c 'source /opt/ros/noetic/setup.bash 2>/dev/null; [ -f /ws/devel/setup.bash ] && source /ws/devel/setup.bash; [ -d /opt/bullet3/install ] && export BULLET_INSTALL_PATH=/opt/bullet3/install && export LD_LIBRARY_PATH=/opt/bullet3/install/lib:$LD_LIBRARY_PATH; cd /ws && tmux -f /etc/tmux.conf new-session -A -s dev'
