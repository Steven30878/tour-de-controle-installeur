# Installer Tour de contrôle

Tour de contrôle fait travailler des équipes d’agents Claude sur tes projets. L’appli elle-même est privée : ce dépôt ne contient que les **installeurs**. Ils la téléchargent pour toi depuis le dépôt privé où tu as été invité.

## Avant de commencer

1. Un compte GitHub (gratuit).
2. Une **invitation** au dépôt privé, envoyée par la personne qui partage l’appli. Accepte-la : GitHub t’envoie un mail, ou va sur github.com/notifications.

## Windows

1. Dans [la dernière version](../../releases/latest), télécharge **Installer-Tour-de-controle-Windows.zip**, puis décompresse-le.
2. Double-clique sur **Installer Tour de controle.exe**.
   - Si Windows affiche « Windows a protégé votre ordinateur » : « Informations complémentaires », puis « Exécuter quand même ». (L’installeur n’est pas signé par un éditeur payant.)
3. Choisis l’édition, clique sur « Se connecter à GitHub et installer », saisis sur la page GitHub le code affiché (il est déjà copié : Ctrl+V) et autorise Tour de contrôle. L’installeur télécharge, vérifie et installe l’appli, puis l’ouvre.

## Mac (puces Apple M1 à M5)

1. Dans [la dernière version](../../releases/latest), télécharge **Installer-Tour-de-controle-Mac.tar.gz**, puis double-clique dessus pour le décompresser.
2. Double-clique sur **Installer Tour de contrôle**.
   - La première fois, macOS refuse de l’ouvrir (il n’est pas signé par un compte développeur Apple, payant). Ouvre **Réglages Système > Confidentialité et sécurité**, descends jusqu’au message sur « Installer Tour de contrôle » et clique sur **Ouvrir quand même**. Relance-le.
3. Choisis l’édition, saisis sur la page GitHub le code affiché (il est déjà copié : Cmd+V), autorise Tour de contrôle, puis clique sur Continuer. L’appli s’installe dans Applications et s’ouvre.

## Ensuite

Dans l’appli : **Paramètres > Version et mises à jour > Se connecter à GitHub**. Les mises à jour arrivent alors toutes seules, et tes notes « Problèmes et idées » sont partagées.

## Sécurité

- L’installeur n’enregistre aucun mot de passe ni accès : la connexion GitHub sert seulement au téléchargement.
- Le paquet est vérifié avec son empreinte avant l’installation. Chaque mise à jour suivante est vérifiée par l’appli avec la signature de la personne qui la publie : une mise à jour qui n’est pas signée par elle est refusée.
- GitHub te demande l’accès « repo » : c’est la seule permission qui permet de lire un dépôt privé. Elle n’est utilisée que pour ce dépôt.

## Pour la personne qui publie

- Windows : `windows-exe\construire.cmd` (compilateur C# livré avec Windows), puis `node construire.cjs`.
- Les fichiers à publier sont dans `dist/`.
