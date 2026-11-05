# Installer Tour de contrôle

Tour de contrôle fait travailler des équipes d’agents Claude sur tes projets. L’appli elle-même est privée : ce dépôt ne contient que les **installeurs**, qui la téléchargent pour toi depuis le dépôt privé où tu as été invité.

## Avant de commencer

1. Un compte GitHub (gratuit).
2. Une **invitation** au dépôt privé des mises à jour, envoyée par la personne qui partage l’appli. Accepte-la : GitHub t’envoie un mail, ou va sur github.com/notifications.

## Windows

1. Télécharge **Installeur-Windows.zip** dans la page [Releases](../../releases/latest), puis décompresse-le.
2. Double-clique sur **Installer Tour de controle.cmd**.
   - Si Windows affiche « Windows a protégé votre ordinateur » : clique sur « Informations complémentaires », puis « Exécuter quand même ».
3. Choisis l’édition, saisis sur la page GitHub le code affiché (il est déjà copié : Ctrl+V), autorise Tour de contrôle. L’installeur télécharge, vérifie et installe l’appli, puis l’ouvre.

## Mac (puces Apple M1 à M5)

1. Télécharge **Installeur-Mac.zip** dans la page [Releases](../../releases/latest), puis décompresse-le.
2. Ouvre l’app **Terminal**, tape `bash ` (avec l’espace), glisse le fichier **Installer Tour de controle.command** dans la fenêtre, puis Entrée.
3. Choisis l’édition, saisis sur la page GitHub le code affiché (il est déjà copié : Cmd+V), autorise Tour de contrôle. L’appli s’installe dans Applications et s’ouvre.

## Ensuite

Dans l’appli : **Paramètres > Version et mises à jour > Se connecter à GitHub**. Les mises à jour arrivent alors toutes seules, et tes notes « Problèmes et idées » sont partagées avec tout le monde.

## Sécurité

- L’installeur n’enregistre aucun mot de passe ni accès : la connexion GitHub sert seulement au téléchargement.
- Le paquet est vérifié avec son empreinte avant l’installation, et chaque mise à jour suivante est vérifiée par l’appli avec la signature de la personne qui la publie : une mise à jour qui n’est pas signée par elle est refusée.
- GitHub te demande l’accès « repo » : c’est la seule permission qui permet de lire un dépôt privé. Elle n’est utilisée que pour ce dépôt.
