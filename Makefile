# ApptainerROS - Makefile pour build/run de l'image archi these
# Workspace catkin attendu dans le parent : ../src ../build ../devel

VERSION   ?= noetic
APPTAINER ?= apptainer

WS_HOST   := $(realpath $(shell pwd)/..)
WS_BIND   := --bind $(WS_HOST):/ws

# --nv = OPT-IN (NV=1) ; il casse les Qt GUI a cause d'un mismatch GLIBC
# entre les libs NVIDIA host (GLIBC 2.34) et le container Focal (2.31).
# Active uniquement quand tu as un node qui utilise vraiment le GPU.
NV_FLAG   := $(if $(NV),--nv,)

# X11 forwarding (RViz, ontoloGUI, rqt_*, etc.) -- bind socket si dispo
X11_BIND  := $(if $(wildcard /tmp/.X11-unix),--bind /tmp/.X11-unix:/tmp/.X11-unix,)
# Allow root container access to current X server (one-shot, idempotent)
XHOST_OK  := xhost +si:localuser:$$USER >/dev/null 2>&1 || true;

BASE_SIF  := $(VERSION).sif
ARCHI_DIR := archi-sandbox
ARCHI_SIF := archi.sif

# Source ROS + WS dans toute commande exec : evite les pb de PATH inherits
# Export aussi BULLET_INSTALL_PATH (overworld) si bullet3 est dispo
SOURCE_ROS := source /opt/ros/noetic/setup.bash 2>/dev/null; \
              [ -f /ws/devel/setup.bash ] && source /ws/devel/setup.bash; \
              [ -d /opt/bullet3/install ] && export BULLET_INSTALL_PATH=/opt/bullet3/install \
                && export LD_LIBRARY_PATH=/opt/bullet3/install/lib:$$LD_LIBRARY_PATH;

.DEFAULT_GOAL := help
.PHONY: help all build base archi rebuild-archi shell dev exec exec-root rosdep compile freeze clean clean-all info ensure-ws

help:
	@echo "ApptainerROS - cibles disponibles :"
	@echo ""
	@echo "  make build              build base ($(BASE_SIF)) + sandbox writable ($(ARCHI_DIR))"
	@echo "  make base               build seulement la base immutable"
	@echo "  make archi              build seulement la sandbox writable"
	@echo "  make shell              entrer en --fakeroot --writable (pour apt install)"
	@echo "  make dev                lancer tmux dans la sandbox (mode dev)"
	@echo "  make exec ARGS=...      executer une commande (read-only)"
	@echo "  make exec-root ARGS=... executer une commande en --fakeroot --writable (apt, etc.)"
	@echo "  make rosdep             rosdep update + install (root, EOL noetic active)"
	@echo "  make compile            catkin_make dans le conteneur"
	@echo "  make freeze             produire $(ARCHI_SIF) immutable (archive these)"
	@echo "  make clean              supprimer $(ARCHI_DIR)"
	@echo "  make clean-all          supprimer toutes les images"
	@echo "  make info               afficher les chemins"
	@echo ""
	@echo "Workspace bindé : $(WS_HOST) -> /ws"

all: build
build: base archi
base: $(BASE_SIF)
archi: $(ARCHI_DIR)

$(BASE_SIF): ros.def
	@echo "==> Build base $@ (immutable)"
	$(APPTAINER) build --build-arg version=$(VERSION) $@ $<

# Note : archi.def n'est PAS une dependance pour eviter de rebuild la sandbox
# (et perdre les apt installs / bullet3) a chaque modif du .def.
# Pour rebuilder explicitement : make rebuild-archi (ou make clean && make build).
$(ARCHI_DIR): $(BASE_SIF) tmux.conf
	@echo "==> Build sandbox writable $@ depuis $(BASE_SIF)"
	$(APPTAINER) build --sandbox --fakeroot --force $@ archi.def

rebuild-archi:
	@echo "==> Rebuild forcé de la sandbox (depuis archi.def actuel)"
	$(APPTAINER) build --sandbox --fakeroot --force $(ARCHI_DIR) archi.def

# Idempotent : cree /ws dans la sandbox si manquant (necessaire pour --bind avec --writable)
ensure-ws: $(ARCHI_DIR)
	@if [ ! -d "$(ARCHI_DIR)/ws" ]; then \
		echo "==> Creation de /ws dans la sandbox"; \
		$(APPTAINER) exec --fakeroot --writable $(ARCHI_DIR) mkdir -p /ws; \
	fi

shell: ensure-ws
	@echo "==> Shell --fakeroot --writable (mode install/apt)"
	$(APPTAINER) shell --fakeroot --writable $(WS_BIND) $(ARCHI_DIR)

dev: $(ARCHI_DIR)
	@./start_dev.sh

exec: $(ARCHI_DIR)
	@if [ -z "$(ARGS)" ]; then \
		echo "Usage: make exec ARGS='rosrun pkg node'"; exit 1; \
	fi
	@$(XHOST_OK)
	$(APPTAINER) exec $(NV_FLAG) $(WS_BIND) $(X11_BIND) $(ARCHI_DIR) \
		bash -c '$(SOURCE_ROS) $(ARGS)'

exec-root: ensure-ws
	@if [ -z "$(ARGS)" ]; then \
		echo "Usage: make exec-root ARGS='apt install -y libxxx'"; exit 1; \
	fi
	$(APPTAINER) exec --fakeroot --writable $(WS_BIND) $(ARCHI_DIR) \
		bash -c 'apt-get update -qq >/dev/null 2>&1; $(SOURCE_ROS) $(ARGS)'

rosdep: ensure-ws
	@echo "==> apt-get update + rosdep update + rosdep install (--fakeroot --writable)"
	$(APPTAINER) exec --fakeroot --writable $(WS_BIND) $(ARCHI_DIR) \
		bash -c 'set -e; \
		         source /opt/ros/noetic/setup.bash; \
		         apt-get update; \
		         rosdep update --include-eol-distros; \
		         cd /ws; \
		         rosdep install --from-paths src --ignore-src -r -y --rosdistro noetic'

compile: $(ARCHI_DIR)
	@echo "==> catkin_make dans le conteneur (pas de --nv : GLIBC mismatch host/container)"
	$(APPTAINER) exec $(WS_BIND) $(ARCHI_DIR) \
		bash -c '$(SOURCE_ROS) cd /ws && catkin_make $(CATKIN_ARGS)'

freeze: $(ARCHI_DIR)
	@echo "==> Freeze sandbox -> $(ARCHI_SIF) (immutable)"
	$(APPTAINER) build --force $(ARCHI_SIF) $(ARCHI_DIR)

clean:
	@echo "==> Suppression $(ARCHI_DIR)"
	@rm -rf $(ARCHI_DIR)

clean-all: clean
	@echo "==> Suppression $(BASE_SIF) et $(ARCHI_SIF)"
	@rm -f $(BASE_SIF) $(ARCHI_SIF)

info:
	@echo "VERSION   = $(VERSION)"
	@echo "WS_HOST   = $(WS_HOST)"
	@echo "BASE_SIF  = $(BASE_SIF)"
	@echo "ARCHI_DIR = $(ARCHI_DIR)"
	@echo "ARCHI_SIF = $(ARCHI_SIF)"
