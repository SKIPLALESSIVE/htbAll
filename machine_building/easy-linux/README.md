# HTB Easy Linux — projet de travail

Ce dossier amorce une machine Linux de difficulté **Easy** nommée provisoirement
`Ledger`. Le contenu sert à construire et tester la VM. Il ne constitue pas le
write-up de soumission : les règles HTB interdisent la documentation générée par
IA dans une soumission. L'auteur doit refaire le parcours, prendre ses propres
captures et rédiger le document final.

## Concept

Une petite société utilise `ledger.htb` pour exporter des rapports. Le portail
SQLite présente une injection SQL dans l'API d'annuaire utilisée par la connexion.
Le hash administrateur extrait se casse avec `rockyou.txt`. Une fonction de diagnostic
réservée aux administrateurs contient ensuite une injection de commande donnant
une RCE sous le compte `ledger`. Le mot de passe du job d'import de `mira` est
présent dans l'environnement du service. Enfin, `mira` peut lancer un outil de
sauvegarde avec `sudo`; l'utilisation non sécurisée de `tar` permet d'obtenir root.

Parcours prévu :

1. extraire puis casser le hash administrateur via une injection SQL `UNION` ;
2. exploiter l'injection de commande du diagnostic pour obtenir une RCE `ledger`, puis récupérer le secret de migration dans l'environnement et accéder à `mira` ;
3. suivre le profil du groupe `archive-ops` jusqu'à la file nocturne, puis exploiter le glob non protégé du script de sauvegarde autorisé par `sudo` pour devenir root.

## Arborescence

- `app/` : application Flask vulnérable et templates ;
- `provision/` : script d'installation à exécuter dans une Ubuntu Server 26.04.1 minimale ;
- `tests/` : contrôles statiques et checklist de recette ;
- `docs/` : conception, exigences HTB, choix d'installation et procédure de construction ;
- `submission/` : modèle à compléter manuellement par l'auteur.

## Démarrage

Créer d'abord une VM VirtualBox Ubuntu Server 26.04.1 avec 2 vCPU, 2 Go de RAM et
un disque dynamique de 12 Go. Suivre `docs/installation-checklist.md`, copier ce
dossier temporairement dans `/tmp/easy-linux`, puis lancer depuis la console :

```bash
cd /tmp/easy-linux
sudo bash provision/install.sh
```

Copier `tests/verify-vm.sh` hors du dossier, supprimer la copie de construction,
redémarrer, puis exécuter la vérification. Les sources ne doivent pas rester dans
l'image finale, car elles contiennent les secrets du scénario.

Ne pas exposer la VM sur Internet. Utiliser un réseau privé/NAT pendant la
construction et un réseau host-only pour les tests.

## État

La VM a été reprovisionnée et validée le 22 octobre 2026 sur Ubuntu 26.04.1 :
le vérificateur automatisé passe intégralement et le parcours SQLi → RCE → SSH
Mira → GNU tar/root a été rejoué manuellement. Les payloads et sources de build
ont été retirés. Il reste à éteindre proprement la VM, exporter l'OVA, la
réimporter sur un autre hôte et refaire une recette à froid. Le write-up de
soumission doit être rédigé manuellement par l'auteur.

