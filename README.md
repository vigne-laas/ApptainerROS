# ApptainerROS

Conteneurisation Apptainer du code de thèse ROS1 Noetic, exécuté sur host
Ubuntu 22.04 / ROS2 Humble.

## Architecture en 2 couches

```
ros.def    -->  noetic.sif       (immutable, base)
archi.def  -->  archi-sandbox/   (writable, dev)
              -->  archi.sif     (immutable, archive these)
```

- **noetic.sif** : base ROS Noetic + outils d'init (vcstool, rosdep, tmux,
  tmuxinator, build-essential). Stable, rebuilde rarement.
- **archi-sandbox/** : surcouche writable. C'est là qu'on installe les deps
  spécifiques de l'archi à la volée (`apt install` interne) et qu'on dev.
- **archi.sif** : produit final immutable, généré quand on veut figer un état
  reproductible (archive thèse).

## Layout repo

```
ws/
├── archithese.repos          (vcs file, ~35 repos)
├── src/                      (workspace catkin, peuple par vcs import)
├── build/, devel/            (generes par catkin_make dans le conteneur)
├── tmuxinator/
│   └── example.yml           (template scenario)
├── logs/                     (roscore, nodes -- runtime)
└── ApptainerROS/
    ├── ros.def
    ├── archi.def
    ├── tmux.conf             (souris activee)
    ├── Makefile
    ├── ros1exec              (wrapper apptainer exec, pour dispatcher web)
    ├── start_roscore.sh
    ├── stop_roscore.sh
    ├── start_dev.sh          (lance tmux dans le conteneur)
    └── README.md
```

Le workspace catkin (`src/`, `build/`, `devel/`) vit **sur le host** et est
bindé en `/ws` dans le conteneur. Conséquence : la compile lourde survit aux
rebuilds d'image.

## Workflow premier setup

```bash
# 1. Build base + sandbox archi
cd ws/ApptainerROS
make build

# 2. Cote host : recuperer les sources
sudo apt install python3-vcstool
cd .. && vcs import src < archithese.repos
cd ApptainerROS

# 3. Compile du workspace catkin DANS le conteneur
make exec ARGS='cd /ws && rosdep install --from-paths src --ignore-src -r -y'
make exec ARGS='cd /ws && catkin_make'
```

## Phase dev : ajouter une dep systeme

```bash
make shell                     # entre en --fakeroot --writable
apt install -y libxxx-dev      # installe a la volee
exit
```

**Discipline** : chaque `apt install` fait dans le sandbox doit aussi etre
ajoute dans `archi.def` pour preserver la repro from-scratch. Le sandbox =
pratique, le `.def` = source de verite.

## Lancement des nodes

### Mode dev : tmux + tmuxinator (interactif)

```bash
./start_roscore.sh             # roscore en arriere-plan (host)
make dev                       # entre dans tmux dans le conteneur
# Dans tmux :
tmuxinator start example       # lance ton scenario
```

Souris activee : scroll, click pour changer de pane, drag pour resize.
Broadcast input sur tous les panes : `Ctrl-b B` (toggle).

### Mode dispatcher web (production)

Le dispatcher web (Flask/FastAPI cote host) lance chaque node via :

```bash
./ros1exec rosrun mon_pkg mon_node
```

En Python :

```python
import subprocess
proc = subprocess.Popen(
    ["./ros1exec", "rosrun", "mon_pkg", "mon_node"],
    stdout=open(f"logs/{node_name}.log", "w"),
    stderr=subprocess.STDOUT,
)
# tracking par PID, restart en cas de crash, etc.
```

## Cibles Makefile

| Cible | Effet |
|---|---|
| `make` ou `make help` | afficher l'aide |
| `make build` | base + sandbox archi |
| `make base` | seulement la base immutable |
| `make archi` | seulement la sandbox writable |
| `make shell` | entrer en `--fakeroot --writable` |
| `make dev` | tmux dans la sandbox |
| `make exec ARGS='...'` | commande one-shot (sans writable) |
| `make freeze` | generer `archi.sif` immutable |
| `make clean` | supprimer le sandbox |
| `make clean-all` | tout supprimer |
| `make info` | afficher les chemins resolus |

## Prerequis host

- Apptainer >= 1.x
- Driver NVIDIA (verifier avec `nvidia-smi`)
- `python3-vcstool` (pour `vcs import`)
- Cles SSH GitHub configurees (pour cloner les repos prives)

## Note Apptainer setuid (config LAAS)

Si erreur de setuid au build (sessions distantes Ubuntu 22.04) :
```bash
sudo usermod -v 79750000-797599999 <username>
sudo usermod -w 79750000-797599999 <username>
```
