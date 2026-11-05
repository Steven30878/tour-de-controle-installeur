#!/bin/bash
# Installeur de Tour de contrôle (Mac à puce Apple), en appli : des fenêtres macOS, sans Terminal.
# 1. Connexion à GitHub avec le compte de la personne (code à saisir sur github.com).
# 2. Téléchargement de la dernière version depuis le dépôt privé, vérification de son empreinte.
# 3. Installation par l'installeur du paquet (Applications, quarantaine retirée, signature locale).
# Aucun mot de passe ni accès n'est enregistré. Les réponses de GitHub sont lues avec plutil.
set -uo pipefail

CLIENT_ID='Ov23liBDVeFgmsICJVYN'
REPO='Steven30878/tour-de-controle-maj'
AGENT='tour-de-controle-installeur'
TITRE='Installer Tour de contrôle'
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fenêtres macOS (AppleScript). Les guillemets sont échappés pour AppleScript.
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
alerte() { osascript -e "display alert \"$(esc "$TITRE")\" message \"$(esc "$1")\" as critical buttons {\"OK\"}" >/dev/null 2>&1; }
info() { osascript -e "display notification \"$(esc "$1")\" with title \"$(esc "$TITRE")\"" >/dev/null 2>&1; }
fail() { alerte "$1"; exit 1; }
# Lit un champ d'un fichier JSON (plutil, livré avec macOS).
champ() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }

[ "$(uname -m)" = "arm64" ] || fail "Cette version est pour les Mac à puce Apple (M1 à M5)."

CHOIX=$(osascript -e "button returned of (display dialog \"L'installeur télécharge la dernière version de Tour de contrôle depuis le dépôt GitHub privé. Il faut un compte GitHub invité sur ce dépôt.

Quelle édition ?\" buttons {\"Annuler\", \"Édition perso\", \"Édition clé API\"} default button \"Édition clé API\" cancel button \"Annuler\" with title \"$TITRE\")" 2>/dev/null) || exit 0
if [ "$CHOIX" = "Édition perso" ]; then EDITION='perso'; else EDITION='vendable'; fi

# --- Connexion à GitHub --------------------------------------------------------------------
curl -fsS -X POST -H 'Accept: application/json' -A "$AGENT" -d "client_id=$CLIENT_ID&scope=repo" https://github.com/login/device/code -o "$WORK/code.json" || fail "GitHub ne répond pas. Vérifie ta connexion internet."
CODE=$(champ "$WORK/code.json" user_code)
URI=$(champ "$WORK/code.json" verification_uri)
DEVICE=$(champ "$WORK/code.json" device_code)
WAIT=$(champ "$WORK/code.json" interval); WAIT=${WAIT:-5}; [ "$WAIT" -ge 5 ] 2>/dev/null || WAIT=5
DUREE=$(champ "$WORK/code.json" expires_in); DUREE=${DUREE:-900}
[ -n "$CODE" ] && [ -n "$DEVICE" ] || fail "GitHub n'a pas donné de code de connexion. Réessaie dans un instant."
FIN=$(( $(date +%s) + DUREE ))
printf '%s' "$CODE" | pbcopy
open "${URI:-https://github.com/login/device}"
osascript -e "display dialog \"Sur la page GitHub qui vient de s'ouvrir, saisis ce code (il est déjà copié : Cmd+V), puis autorise Tour de contrôle :

        $CODE

Clique sur Continuer une fois que c'est fait.\" buttons {\"Annuler\", \"Continuer\"} default button \"Continuer\" cancel button \"Annuler\" with title \"$TITRE\"" >/dev/null 2>&1 || exit 0

TOKEN=''
while [ -z "$TOKEN" ] && [ "$(date +%s)" -lt "$FIN" ]; do
  curl -fsS -X POST -H 'Accept: application/json' -A "$AGENT" -d "client_id=$CLIENT_ID&device_code=$DEVICE&grant_type=urn:ietf:params:oauth:grant-type:device_code" https://github.com/login/oauth/access_token -o "$WORK/jeton.json" || { sleep "$WAIT"; continue; }
  TOKEN=$(champ "$WORK/jeton.json" access_token)
  ERR=$(champ "$WORK/jeton.json" error)
  rm -f "$WORK/jeton.json"
  if [ -z "$TOKEN" ]; then
    case "$ERR" in
      authorization_pending|'') sleep "$WAIT" ;;
      slow_down) WAIT=$((WAIT + 5)); sleep "$WAIT" ;;
      *) fail "Connexion refusée ou expirée ($ERR). Relance l'installeur." ;;
    esac
  fi
done
[ -n "$TOKEN" ] || fail "Le code a expiré. Relance l'installeur."

API() { curl -fsS -H "Authorization: Bearer $TOKEN" -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' -A "$AGENT" "$@"; }
API "https://api.github.com/repos/$REPO/releases/latest" -o "$WORK/version.json" || fail "Ton compte GitHub n'est pas invité sur le dépôt $REPO. Demande une invitation, accepte-la (mail de GitHub), puis relance."

# Télécharge un fichier de la publication : GitHub renvoie vers son stockage, sans l'accès.
fichier() {
  local i=0 nom url='' loc
  while nom=$(champ "$WORK/version.json" "assets.$i.name"); do
    if [ "$nom" = "$1" ]; then url=$(champ "$WORK/version.json" "assets.$i.url"); break; fi
    i=$((i + 1))
  done
  [ -n "$url" ] || fail "$1 est absent de la dernière version."
  loc=$(curl -sS -o /dev/null -w '%{redirect_url}' -H "Authorization: Bearer $TOKEN" -H 'Accept: application/octet-stream' -A "$AGENT" "$url")
  [ -n "$loc" ] || fail "Téléchargement de $1 refusé par GitHub."
  curl -fsSL -A "$AGENT" -o "$2" "$loc" || fail "Téléchargement de $1 interrompu."
}

info "Recherche de la dernière version…"
fichier "manifest-mac-$EDITION.json" "$WORK/manifeste.json"
NOM=$(champ "$WORK/manifeste.json" file)
SHA=$(champ "$WORK/manifeste.json" sha256 | tr 'A-F' 'a-f')
VERSION=$(champ "$WORK/manifeste.json" version)
TAILLE=$(champ "$WORK/manifeste.json" size); TAILLE=${TAILLE:-0}
[ -n "$NOM" ] && [ ${#SHA} -eq 64 ] || fail "Les informations de la version sont illisibles."

info "Téléchargement de Tour de contrôle $VERSION ($(( TAILLE / 1000000 )) Mo), quelques minutes…"
fichier "$NOM" "$WORK/$NOM"
[ "$(shasum -a 256 "$WORK/$NOM" | cut -d' ' -f1)" = "$SHA" ] || fail "Le paquet téléchargé est abîmé ou modifié (empreinte différente). Relance l'installeur."

info "Installation…"
mkdir -p "$WORK/paquet"
tar -xzf "$WORK/$NOM" -C "$WORK/paquet" || fail "Décompression impossible."
bash "$WORK/paquet/Installer Tour de controle.command" >"$WORK/installation.log" 2>&1 || fail "L'installation a échoué : $(tail -3 "$WORK/installation.log")"

osascript -e "display dialog \"Tour de contrôle $VERSION est installé dans Applications et vient de s'ouvrir.

Dans l'appli : Paramètres > Version et mises à jour > Se connecter à GitHub, pour recevoir les mises à jour.\" buttons {\"OK\"} default button \"OK\" with title \"$TITRE\"" >/dev/null 2>&1
exit 0
