# Choix pendant l'installation Ubuntu

Utiliser l'ISO **Ubuntu Server 26.04.1 LTS amd64** officielle et vérifier sa
somme SHA-256 avant de la monter dans VirtualBox.

## VirtualBox

- Type Linux / Ubuntu 64-bit, EFI désactivé sauf besoin particulier.
- 2 vCPU, 2048 Mo de RAM, VDI dynamique de 12 Go.
- Un seul adaptateur réseau NAT pendant l'installation et les mises à jour.
- Aucun presse-papiers partagé, glisser-déposer, dossier partagé ou port redirigé.
- Audio, USB et périphériques inutiles désactivés.
- Prendre un snapshot `00-clean-install` après l'installation initiale.

## Assistant Ubuntu

- Language: English ; keyboard: English (US).
- Installation minimale, sans environnement graphique.
- DHCP, sans proxy, miroir Ubuntu officiel.
- Disque entier en ext4 ; pas de chiffrement ; LVM facultatif mais inutile ici.
- Hostname : `ledger` exactement.
- Créer un compte administrateur temporaire de build, avec un mot de passe fort
  différent des identifiants du scénario.
- Installer OpenSSH Server, sans importer de clé depuis GitHub/Launchpad.
- Ne sélectionner aucun snap serveur supplémentaire.

Le compte de build doit s'appeler `skip`. Le provisionnement installe un service
systemd à usage unique qui supprime ce compte, son home et son groupe au premier
redémarrage, puis s'auto-retire.

## Après le premier démarrage

1. Vérifier `ip address`, la route par défaut et la résolution DNS.
2. Vérifier `timedatectl` ; le fuseau n'a pas d'impact sur le challenge, mais
   l'horloge doit être synchronisée.
3. Prendre le snapshot `01-before-provision`.
4. Copier le projet dans `/tmp/easy-linux` et lancer le provisionnement depuis
   la console VirtualBox, car le passage de Netplan à ifupdown peut interrompre
   une session SSH au redémarrage.
5. Copier `/tmp/easy-linux/tests/verify-vm.sh` vers `/tmp/verify-vm.sh`, puis
   supprimer `/tmp/easy-linux`.
6. Redémarrer. La session `skip` sera supprimée et ne pourra pas être rouverte.
7. Depuis la console, se connecter via le mode de récupération/root pour le
   contrôle local, ou copier le script avant suppression et l'exécuter dans la
   phase de recette avec une méthode d'administration temporaire maîtrisée.

## Avant l'export

- Faire les tests depuis une VM d'attaque sur un réseau host-only isolé.
- Vérifier que le compte `skip`, son groupe, ses clés, son home et ses sudoers ont disparu.
- Retirer `/tmp/verify-vm.sh`, caches APT, logs de construction et fichiers temporaires.
- Vérifier qu'aucun média ISO ni dossier partagé n'est encore attaché.
- Ne pas laisser Guest Additions sauf nécessité démontrée.
- Éteindre proprement, exporter en OVA, puis importer l'OVA sur une autre machine
  et refaire le parcours complet après un reboot.
