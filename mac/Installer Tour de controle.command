#!/bin/bash
# Installeur de Tour de contrôle (Mac à puce Apple), depuis le dépôt GitHub privé des mises à jour.
# 1. Connexion à GitHub avec TON compte (un code à saisir sur github.com) : il faut avoir été
#    invité sur le dépôt par la personne qui partage l'appli.
# 2. Téléchargement de la dernière version, vérification de son empreinte, installation dans
#    Applications (le script d'installation du paquet retire la quarantaine et signe l'appli
#    localement, car elle n'est pas signée par un compte développeur Apple).
# Aucun mot de passe ni jeton n'est enregistré par cet installeur.
# Lancement : dans le Terminal, tape « bash » suivi d'un espace, glisse ce fichier, Entrée.
set -euo pipefail

CLIENT_ID='Ov23liBDVeFgmsICJVYN'
REPO='Steven30878/tour-de-controle-maj'
AGENT='tour-de-controle-installeur'

fail() { echo; echo "ERREUR : $*"; exit 1; }
# Lit un champ d'un JSON avec le JavaScript intégré à macOS (rien à installer).
jget() { osascript -l JavaScript -e 'function run(a){try{const o=JSON.parse(a[0]);const v=eval("o"+a[1]);return v===undefined||v===null?"":String(v)}catch(e){return ""}}' "$1" "$2"; }

[ "$(uname -m)" = "arm64" ] || fail "cette version est pour les Mac à puce Apple (M1 à M5)."

echo
echo "=== Installation de Tour de contrôle ==="
echo
echo "Quelle édition ?"
echo "  1) Édition clé API : pour tout le monde (tu utiliseras ta propre clé API Anthropic)"
echo "  2) Édition perso   : réservée à la personne qui fait les mises à jour"
read -r -p "Ton choix [1] : " choice
if [ "${choice:-1}" = "2" ]; then EDITION='perso'; else EDITION='vendable'; fi

# --- Connexion à GitHub --------------------------------------------------------------------
D=$(curl -fsS -X POST -H 'Accept: application/json' -A "$AGENT" -d "client_id=$CLIENT_ID&scope=repo" https://github.com/login/device/code) || fail "GitHub ne répond pas. Vérifie ta connexion internet."
CODE=$(jget "$D" '.user_code'); URI=$(jget "$D" '.verification_uri'); DEVICE=$(jget "$D" '.device_code')
WAIT=$(jget "$D" '.interval'); WAIT=${WAIT:-5}; [ "$WAIT" -lt 5 ] && WAIT=5
EXPIRES=$(( $(date +%s) + $(jget "$D" '.expires_in') ))
echo
echo "Connexion à GitHub :"
echo "  1. Sur la page qui s'ouvre ($URI), saisis ce code :"
echo
echo "        $CODE"
echo
echo "  2. Autorise Tour de contrôle. Cette fenêtre continue toute seule ensuite."
printf '%s' "$CODE" | pbcopy && echo "  (Le code est déjà copié : colle-le avec Cmd+V.)"
open "$URI"

TOKEN=''
while [ -z "$TOKEN" ] && [ "$(date +%s)" -lt "$EXPIRES" ]; do
  sleep "$WAIT"
  T=$(curl -fsS -X POST -H 'Accept: application/json' -A "$AGENT" -d "client_id=$CLIENT_ID&device_code=$DEVICE&grant_type=urn:ietf:params:oauth:grant-type:device_code" https://github.com/login/oauth/access_token) || continue
  TOKEN=$(jget "$T" '.access_token')
  ERR=$(jget "$T" '.error')
  if [ -z "$TOKEN" ]; then
    case "$ERR" in
      authorization_pending|'') ;;
      slow_down) WAIT=$((WAIT + 5)) ;;
      *) fail "connexion refusée ou expirée ($ERR). Relance l'installeur." ;;
    esac
  fi
done
[ -n "$TOKEN" ] || fail "le code a expiré. Relance l'installeur."
echo "Connecté à GitHub."

API() { curl -fsS -H "Authorization: Bearer $TOKEN" -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' -A "$AGENT" "$@"; }
REL=$(API "https://api.github.com/repos/$REPO/releases/latest") || fail "ton compte GitHub n'est pas invité sur le dépôt $REPO. Demande une invitation, accepte-la (mail de GitHub), puis relance."
TAG=$(jget "$REL" '.tag_name')

# Télécharge un fichier de la publication : GitHub renvoie vers son stockage, sans l'accès.
asset() {
  local url
  url=$(jget "$REL" ".assets.find(a=>a.name==='$1').url")
  [ -n "$url" ] || fail "$1 absent de la version $TAG."
  local loc
  loc=$(curl -sS -o /dev/null -w '%{redirect_url}' -H "Authorization: Bearer $TOKEN" -H 'Accept: application/octet-stream' -A "$AGENT" "$url")
  [ -n "$loc" ] || fail "téléchargement de $1 refusé par GitHub."
  curl -fSL --progress-bar -A "$AGENT" -o "$2" "$loc" || fail "téléchargement de $1 interrompu."
}

WORK="$(mktemp -d)/tour-de-controle"
mkdir -p "$WORK"
echo "Version $TAG : lecture des informations..."
asset "manifest-mac-$EDITION.json" "$WORK/manifest.json"
M=$(cat "$WORK/manifest.json")
FILE=$(jget "$M" '.file'); SHA=$(jget "$M" '.sha256'); VERSION=$(jget "$M" '.version'); SIZE=$(jget "$M" '.size')
echo "Téléchargement de $FILE ($(( SIZE / 1000000 )) Mo), patiente quelques minutes..."
asset "$FILE" "$WORK/$FILE"
GOT=$(shasum -a 256 "$WORK/$FILE" | cut -d' ' -f1)
[ "$GOT" = "$(echo "$SHA" | tr 'A-F' 'a-f')" ] || fail "le paquet téléchargé est abîmé ou modifié (empreinte différente). Relance l'installeur."
echo "Paquet vérifié."

echo "Décompression..."
mkdir -p "$WORK/paquet"
tar -xzf "$WORK/$FILE" -C "$WORK/paquet"
echo "Installation..."
bash "$WORK/paquet/Installer Tour de controle.command"
rm -rf "$WORK"

echo
echo "Tour de contrôle $VERSION est installé dans Applications."
echo "Dans l'appli : Paramètres > Version et mises à jour > Se connecter à GitHub, pour recevoir les mises à jour."
