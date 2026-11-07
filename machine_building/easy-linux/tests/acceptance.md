# Checklist de recette

## Fonctionnement

- [ ] Démarrage sans intervention et adresse obtenue par DHCP.
- [ ] Seuls les ports 22 et 80 sont accessibles depuis le réseau joueur.
- [ ] `ledger.htb` affiche un site cohérent et toutes les pages répondent.
- [ ] Une requête directe par IP est redirigée vers `http://ledger.htb` et ne sert pas directement l'application.
- [ ] `/careers` indique clairement que le partenaire est hors machine et `/api/v1/legacy/status` guide vers l'API d'annuaire.
- [ ] La notice « Nightly archive rotation » et l'en-tête de `ledger-backup` racontent la même rotation nocturne.
- [ ] Les services `ledger`, `nginx` et `ssh` reviennent après reboot.
- [ ] Aucun timer de scrub périodique n'est livré ; le nettoyage est exécuté une seule fois à la fin du provisionnement.
- [ ] CPU, RAM et disque restent sous les limites visées.

## Parcours prévu

- [ ] L'API d'annuaire est découvrable depuis le JavaScript du login.
- [ ] Une injection `UNION` à deux colonnes extrait le hash du compte administrateur.
- [ ] Le hash SHA-256 de `reports-admin` se casse en moins de cinq minutes avec `rockyou.txt`.
- [ ] La connexion normale avec le mot de passe retrouvé donne une session administrateur.
- [ ] Sans session administrateur, `/reports` et `/admin/diagnostics` redirigent vers le login.
- [ ] Le diagnostic permet une exécution de commande sous `ledger`, sans privilèges supplémentaires.
- [ ] La RCE permet de retrouver `MIRA_IMPORT_PASSWORD` dans l'environnement du service.
- [ ] Le secret de migration donne l'accès à `mira` sans brute force.
- [ ] SSH avec `mira` fonctionne et `user.txt` est lisible.
- [ ] Le mot de passe root de secours fonctionne avec `su` local, tandis que
  l'authentification SSH root reste refusée.
- [ ] `sudo -l` révèle clairement l'outil de sauvegarde.
- [ ] `id` révèle le groupe secondaire `archive-ops`, qui permet de lire le profil d'archive et d'écrire dans la file nocturne.
- [ ] Les fichiers d'options placés dans `/opt/ledger/reports` ne déclenchent rien ; seule la file indiquée par le profil est archivée.
- [ ] L'exploitation du comportement de GNU tar donne root de façon répétable.
- [ ] Après le scrub final d'installation, les payloads ont disparu et les deux copies du rapport initial sont restaurées.
- [ ] `root.txt` est lisible uniquement après élévation.

## Absence de chemins involontaires

- [ ] Aucun mot de passe inattendu dans les processus, journaux ou fichiers web.
- [ ] Les notices de lore (rotation d'identifiants importer, sweep nocturne) sont servies par les pages publiques et couvertes par `verify-vm.sh`.
- [ ] Aucun SUID/SGID non standard exploitable.
- [ ] Aucune capability dangereuse.
- [ ] Aucun membre superflu des groupes `sudo`, `docker`, `lxd` ou `disk`.
- [ ] Aucun cron/timer ou socket exploitable hors scénario.
- [ ] LinPEAS et LinEnum ne révèlent pas de chemin plus court.
- [ ] Le scan de versions ne révèle pas de CVE triviale hors scénario.

## Conformité avant export

- [ ] Nom final, hostname et domaine concordent.
- [ ] Locale/clavier English US.
- [ ] Disque <= 15 Go ; 2 Go RAM ; 2 vCPU.
- [ ] Flags de 32 caractères hexadécimaux, propriétaires et modes corrects (`0640` pour empêcher la lecture web du user flag).
- [ ] Historiques redirigés vers `/dev/null` et liens appartenant à root.
- [ ] Aucun compte temporaire, clé SSH de build ou fichier sensible oublié.
- [ ] Le compte et le home temporaires `skip` ont été supprimés au premier reboot.
- [ ] Aucune copie des sources de provisionnement ne reste dans la VM.
- [ ] Mot de passe provisoire remplacé et mots de passe non expirants.
- [ ] OVA réimportée et testée deux fois, dont après reboot/reset.
- [ ] Write-up final rédigé manuellement par l'auteur avec ses captures.

