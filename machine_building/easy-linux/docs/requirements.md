# Exigences HTB et décisions du projet

Vérifié le 20 octobre 2026 à partir de la documentation officielle :

- format VMware Workstation ou VirtualBox ; choix : VirtualBox/OVA ;
- système récent et à jour ; choix : Ubuntu Server 26.04.1 LTS minimale ;
- nom d'hôte identique au nom de la box : `Ledger` / `ledger` ;
- domaines exclusivement en `.htb` ; choix : `ledger.htb` ;
- locale et clavier `en_US` ;
- aucun logiciel commercial ou soumis à licence payante ;
- disque Linux inférieur ou égal à 15 Go ; cible : 12 Go dynamique ;
- recommandation de 2 vCPU et 2 Go de RAM ;
- `/home/mira/user.txt`, propriétaire `root:mira`, mode `0640` : exception au
  mode `0644` recommandé afin d'empêcher le compte web de lire directement le flag ;
- `/root/root.txt`, propriétaire `root:root`, mode `0640` ;
- un mot de passe root fort de secours permet uniquement un `su` local ; la
  connexion SSH root reste interdite ;
- flags au format MD5, soit 32 caractères hexadécimaux ;
- historiques redirigés vers `/dev/null` et appartenant à root, sauf nécessité du scénario ;
- réseau configuré en DHCP avec un profil `systemd-networkd` natif, sans YAML
  Netplan résiduel ni adresse codée en dur ;
- scénario stable, réaliste, sans contenu offensant, politique ou protégé ;
- aucun brute force requis et aucun rabbit hole ;
- niveau Easy : deux à trois étapes, pas de reverse engineering ni de binary exploitation ;
- deux liens privés distincts lors de la soumission : image de machine et write-up.

Sources officielles :

- https://help.hackthebox.com/en/articles/5307061-machine-submission-requirements
- https://help.hackthebox.com/en/articles/5188378-machine-submission-process

## Point bloquant à respecter

HTB indique que les outils d'IA ne doivent pas servir à générer le contenu ou le
write-up soumis. Les fichiers présents ici sont des notes d'ingénierie et des
gabarits internes. Avant soumission, l'auteur doit :

1. rejouer lui-même tout le chemin d'exploitation ;
2. rédiger le write-up dans ses propres mots ;
3. produire ses propres captures ;
4. vérifier chaque secret, commande, service et règle réseau ;
5. ne pas remettre ces documents tels quels à HTB.

## Points à confirmer avant gel de l'image

- Le nom `Ledger` est disponible et ne ressemble pas trop à une machine existante.
- L'image exportée démarre correctement après import sur une autre machine.
- DHCP fonctionne dans l'environnement HTB sans interface ni adresse codée en dur.
- Le parcours prévu reste possible après plusieurs resets.
- Aucun autre vecteur plus court n'est détecté par LinPEAS/LinEnum et une revue manuelle.

