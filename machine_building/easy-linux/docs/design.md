# Conception interne — Ledger

## Expérience visée

La machine enseigne une chaîne web courte : injection SQL, injection de commande,
réutilisation d'un secret opérationnel, puis mauvaise utilisation de jokers par
une commande privilégiée. Aucun secret n'exige de deviner une valeur et aucune
action ne doit faire tomber un service.

## Univers narratif

Le site raconte une migration d'archive : l'ancien pratique « Northwind » laisse
une archive bande encore réconciliée par une équipe de night-operations, et le
partenaire comptable Bridgewater héberge certaines pages de group sur le
domaine `nbridged.co` (jamais hébergé sur la box). Cette matière prépare les
découvertes sans les donner :

- la page `/careers` renvoie vers le portail partenaire (pas un service local) ;
- `/api/v1/legacy/status` expose un état de santé legacy et renvoie vers l'API
  d'annuaire utilisée par le login ;
- une notice décrit la promotion des rapports vers la file de rotation, et une autre
  le gel de fermeture qui laisse les diagnostics actifs ;
- les entrées d'audit mentionnent le repack de nuit et la réconciliation
  d'archive par les opérateurs de nuit.

Ces éléments enrichissent le scénario sans créer de branche morte : le portail
partenaire est explicitement annoncé hors machine et le statut legacy ramène au
chemin prévu. La notice de rotation prépare logiquement le privesc final basé
sur `tar`.

## Services exposés

| Port | Service | Rôle |
|---|---|---|
| 22/tcp | OpenSSH | Accès utilisateur après récupération des identifiants |
| 80/tcp | nginx | Reverse proxy vers l'application Flask locale |
| 8000/tcp | gunicorn | Écoute uniquement sur `127.0.0.1` |

## Comptes

| Compte | Usage | Connexion interactive |
|---|---|---|
| `mira` | analyste, détenteur du user flag | oui, SSH |
| `ledger` | service applicatif | non |
| `root` | administration, détenteur du root flag | non via SSH |

Les secrets de laboratoire sont centralisés dans `provision/install.sh` pour la
phase de construction. Le secret d'import de `mira` est injecté dans le service
via `/etc/ledger/ledger.env`. Ils devront être changés avant le gel et consignés
par l'auteur dans son document privé.

## Vulnérabilités intentionnelles

### Injection SQL dans l'annuaire

Le formulaire `/login` utilise une requête paramétrée, mais son JavaScript appelle
une ancienne API d'autocomplétion, `/api/v1/directory/search`. Cette API interpole
le terme dans une requête SQLite à deux colonnes. Une injection `UNION` permet
d'extraire le hash SHA-256 de `reports-admin`. Son mot de passe est présent dans
`rockyou.txt` et doit se casser largement sous la limite HTB de cinq minutes.

### Injection de commande et passage à `mira`

La page `/admin/diagnostics` passe l'hôte fourni à une commande `ping` via un
shell. L'injection donne une exécution de commande sous `ledger`. La variable
`MIRA_IMPORT_PASSWORD`, justifiée par un ancien connecteur d'import, est visible
dans l'environnement du processus. Elle permet une connexion SSH comme `mira`.

Garde-fous : gunicorn est non privilégié, la commande a un timeout, sa sortie est
limitée, et le secret ne donne accès qu'au compte utilisateur intermédiaire.

### Sauvegarde privilégiée

`mira` peut exécuter uniquement `/usr/local/sbin/ledger-backup` via sudo, sans
mot de passe. Le script charge un profil root dans `/etc/ledger/archive.conf`.
Le groupe secondaire `archive-ops` permet à Mira de lire ce profil et d'écrire
dans la file `/var/spool/ledger/nightly`, sans pouvoir modifier la configuration.
Le répertoire `/etc/ledger` est listable, tandis que chaque secret reste protégé
par ses propres permissions : `archive.conf` est lisible par `archive-ops` et
`ledger.env` uniquement par le compte de service `ledger`.
Le script exécute `tar czf ... *` depuis cette file. GNU tar interprète alors des
noms de fichiers commençant par `--` comme des options. Le joueur doit donc
énumérer les groupes et suivre le profil avant d'exploiter le joker.

Garde-fous : la destination est recréée à chaque exécution, le script ne dépend
pas d'un état unique, et aucun service critique n'est arrêté. L'en-tête du
script, le rapport et la notice « Nightly archive rotation » justifient la file
de rotation auprès du joueur avant même qu'il ne regarde `sudo -l`.

## Mesures de stabilité

- application supervisée par systemd, avec une petite base SQLite locale ;
- base utilisée en lecture seule pendant le jeu, sans état destructible requis ;
- rapports restaurés par le provisionnement ;
- pas de suppression requise pour l'exploitation ;
- SSH root et authentification root désactivés ;
- pas de cron agressif ni de traitement concurrent fragile.

Le provisionnement lance `provision/ledger-scrub` une seule fois à la fin de
l'installation. Il restaure les espaces de travail et la file nocturne depuis
une copie canonique root, supprime les payloads du home et des emplacements
temporaires, puis supprime cette copie. Il préserve le compte, `user.txt` et les
fichiers de connexion. Aucun timer périodique n'interrompt une session joueur.

## Pare-feu

UFW refuse les connexions entrantes par défaut et autorise uniquement `22/tcp`
et `80/tcp`. Gunicorn écoute seulement sur `127.0.0.1:8000` et n'est donc jamais
directement exposé au joueur.

nginx utilise un vhost par défaut qui redirige les requêtes par IP vers
`http://ledger.htb`. Le reverse proxy applicatif n'est associé qu'au vhost
`ledger.htb`, ce qui oblige le joueur à ajouter le domaine à son fichier hosts.

## Calibration de difficulté

La chaîne contient quatre actions techniques, mais chacune est classique et la
navigation indique la suivante. Avec des indices clairs, elle vise un niveau
Easy soutenu. Si l'injection SQL ou la variable d'environnement sont masquées,
la machine devra plutôt être proposée en Medium.

