# Construction de la VM

## 1. VM de base

Créer une VM VirtualBox : Ubuntu Server 26.04.1 LTS minimale, disque VDI dynamique
12 Go, 2 vCPU, 2048 Mo de RAM. Choisir langue et clavier English (US). Pendant la
construction, utiliser NAT pour les mises à jour ; ne jamais faire de redirection
de port vers une interface publique.

Les choix détaillés de l'assistant sont dans `installation-checklist.md`.

Créer un compte temporaire d'administration distinct de `mira`. Il doit être
supprimé avant export, après avoir vérifié que la console de secours reste
utilisable selon la procédure HTB.

## 2. Provisionnement

Copier temporairement `easy-linux` dans `/tmp` de la VM puis exécuter depuis la
console VirtualBox :

```bash
sudo bash provision/install.sh
cp tests/verify-vm.sh /tmp/verify-vm.sh
cd /tmp
# Supprimer ensuite /tmp/easy-linux, puis redémarrer.
```

Le script refuse un lancement sans privilèges, installe les paquets, déploie
l'application, configure nginx/systemd/sudo, crée les flags et nettoie les
historiques. Il définit aussi un mot de passe root de secours destiné à la
console ou à `su`; `PermitRootLogin no` reste obligatoire.

Après validation du provisionnement, supprimer de la VM la copie complète du
dossier `easy-linux`. C'est obligatoire : `install.sh` contient les identifiants
et flags de construction. Conserver les sources uniquement sur la machine de
développement, jamais dans l'OVA.

## 3. Réseau

Le script prépare un profil DHCP IPv4 natif `systemd-networkd` pour la première
interface non-loopback détectée, retire les anciens YAML Netplan et ne code
aucune adresse en dur. Le réseau de construction doit fournir un serveur DHCP ;
conserver une console VirtualBox avant le redémarrage.

## 4. Recette

Depuis une machine d'attaque sur le même réseau host-only :

```bash
nmap -sC -sV -p- TARGET_IP
curl -H 'Host: ledger.htb' http://TARGET_IP/
```

Exécuter ensuite la checklist `tests/acceptance.md`, puis un audit LinPEAS et une
revue manuelle des SUID, capabilities, tâches planifiées, groupes, services et
permissions.

Après suppression des sources et redémarrage, lancer le contrôle automatisé :

```bash
sudo bash /tmp/verify-vm.sh
```

### Diagnostic de `sudo -l`

Le test automatisé exécute `/usr/bin/sudo -n --list` sous l'identité de `mira`
et vérifie que la règle `ledger-backup` est bien affichée. Cela empêche qu'une
image soit livrée avec une configuration sudoers invalide ou illisible.

Le message `--list cannot be used together with environment variable` ne vient
pas d'une variable héritée par le processus. Il apparaît lorsqu'une affectation
est passée comme **argument** de la commande, par exemple :

```bash
sudo -l NAME=value       # erreur
NAME=value sudo -l       # valide
/usr/bin/sudo --list     # commande de diagnostic canonique
```

Si le terminal affiche seulement `sudo -l` mais produit cette erreur, exécuter
`set -x`, retaper la commande manuellement sans accepter une suggestion, puis
utiliser `type -a sudo` et `/usr/bin/sudo --list`. Ne pas installer d'alias ou de
wrapper nommé `sudo` dans l'image : cela masquerait la cause et créerait un
comportement non standard pour les joueurs.

Certains clients SSH installent leur description de terminal dans
`~/.terminfo` puis retransmettent explicitement `TERMINFO`. La règle sudoers de
Ledger conserve uniquement cette variable pour `mira`. Ne pas utiliser le tag
`SETENV`, qui permettrait de fournir des variables dangereuses comme `BASH_ENV`
à une commande root. En cas de diagnostic, la forme totalement isolée reste :

```bash
env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" PATH=/usr/bin:/bin \
  /usr/bin/sudo --list
```

## 5. Gel et export

État de la VM live vérifié le 20 octobre 2026 : mises à jour Ubuntu appliquées
(y compris les mises à jour phasées), chaîne complète rejouée jusqu'à root,
contrôle `verify-vm.sh` entièrement réussi et espaces joueur nettoyés. Un reboot
et une nouvelle recette restent obligatoires avant l'export définitif.

Avant export : changer tous les secrets provisoires, rédiger la documentation
humaine, nettoyer les fichiers temporaires, éteindre proprement la VM, puis
exporter en OVA. Importer l'OVA dans un environnement vierge et refaire deux fois
le parcours complet, dont une fois après reset/reboot.

