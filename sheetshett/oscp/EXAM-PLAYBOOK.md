# OSCP — Exam Playbook (jour J)

> 23 h 45 de test, 24 h de rapport, 70/100 pour passer. Aucune IA autorisée.
> Cette fiche est faite pour être lue **au démarrage** puis consultée en cas de blocage.

---

## 0. Structure & points

| Cible | Points |
|---|---|
| 3 machines standalone | 20 chacune (10 user + 10 admin) = 60 |
| Set AD (3 machines) | 40 |
| **Total** | **100** (seuil 70) |

- Chaque machine a un `local.txt` (user) et un `proof.txt` (admin) → **chemin standard** sur Windows et Linux.
- Une machine validée sans preuve = 0.
- Le rapport est noté : findings, preuves, clarté (≈ 33 % du référentiel).

---

## 1. Les 60 premières minutes

```bash
# 1. Noter les IP fournies et l'heure de début
date

# 2. Scan de tout, en parallèle, sans attendre
nmap -p- --min-rate 2000 -T4 -oA /root/exam/01-scans/all_<IP> <IP> &
```

```bash
# 3. Pendant les scans : créer la structure
mkdir -p /root/exam/{00-notes,01-scans,02-exploits,03-loot,04-report}
script -a /root/exam/00-notes/session.log
```

```bash
# 4. Dès qu'un scan finit
nmap -sCV -p<PORTS> -oA /root/exam/01-scans/svc_<IP> <IP>
```

### Tableau de suivi (à remplir tout de suite)
| Cible | Ports | Accès | user | admin | Temps | Statut |
|---|---|---|---|---|---|---|
| | | | | | | |

---

## 2. Ordre d'attaque

1. **Trier** les 6 cibles par nombre de services / indices évidents.
2. **Commencer par les standalone faciles** (1–2 h max) : sécuriser des points.
3. **Puis le set AD** (gros bloc de points, 8–10 h).
4. **Finir les standalone restantes.**
5. **Rapport** : réserver 3–4 h minimum.

> Alternative si l'AD est familier : commencer par l'AD pendant que la fatigue est basse.

---

## 3. Boucle par cible

```
SCAN (tous ports, UDP top 50)
  ↓
IDENTIFY (versions, vhosts, fichiers, utilisateurs)
  ↓
RESEARCH (version → CVE → PoC local)
  ↓
EXPLOIT (manuel d'abord)
  ↓
SHELL + STABILISATION
  ↓
local.txt + capture
  ↓
PRIVESC (checklist ci-dessous)
  ↓
proof.txt + capture
  ↓
NOTES
```

### Checklist privesc Linux (5 min)
```bash
id; sudo -l; uname -a
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
cat /etc/crontab; ls -la /etc/cron.*
find / -writable -type f 2>/dev/null | grep -v proc
cat ~/.bash_history
```

### Checklist privesc Windows (5 min)
```cmd
whoami /priv
whoami /groups
systeminfo
wmic service get name,pathname,startmode | findstr /i "Auto"
schtasks /query /fo LIST /v
cmdkey /list
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```

---

## 4. Blocage : procédure en 6 questions

1. Ai-je scanné **tous** les ports TCP **et** l'UDP ?
2. Ai-je testé **tous les vhosts** et sous-domaines ?
3. Ai-je testé les creds trouvés sur **toutes** les cibles (`--local-auth` inclus) ?
4. Ai-je essayé les **deux** chemins de privesc (réseau + local) ?
5. Ai-je relu **mes notes** des 3 dernières heures ?
6. Ai-je essayé une **méthode manuelle** au lieu de l'outil ?

Puis : rotation vers une autre cible (90 min max par piste).

```bash
# Rappel des angles morts fréquents
- /backup, /old, /dev, /test, /.git, /.env
- paramètre ?debug=1, ?test=1, ?admin=true
- méthode PUT / DELETE / PATCH
- API versionnée /api/v1 vs /api/v2
- FTP/SMB anonyme
- base de données exposée (3306, 5432, 1433)
```

---

## 5. Rapport : plan des 4 heures

| Temps | Action |
|---|---|
| T+0:00 | créer le document, coller la structure |
| T+0:20 | Attack narrative : copier les notes, reformuler |
| T+1:00 | findings (1 par vuln, CVSS, preuve, impact, remédiation) |
| T+2:30 | captures : vérifier `hostname` + `whoami` + proof |
| T+3:00 | executive summary (en dernier) |
| T+3:20 | relecture : TOC, numérotation, fautes |
| T+3:40 | export PDF, ouverture, vérification |
| T+3:50 | upload + confirmation |

### Minimum par finding
```markdown
## F-01 — Titre
Sévérité / CVSS :
Actif :
Description :
Preuve (commande + sortie) :
Impact :
Remédiation :
```

### Preuve type
```bash
hostname; id; cat /root/local.txt
# capture d'écran + fichier texte dans 03-loot/<IP>/
```

---

## 6. Discipline de notes

```bash
# À chaque étape réussie
echo "$(date +%H:%M) | $(hostname) | $(whoami) | commande: <CMD>" >> /root/exam/00-notes/timeline.md
```

Sans cette discipline, le rapport coûte 8 h au lieu de 4.

---

## 7. Pièges d'examen

| Piège | Conséquence |
|---|---|
| Metasploit/msfvenom sur 2 machines | machine invalidée |
| Scanner commercial | interdit |
| Aide IA | disqualification |
| Shell non stabilisé | `su`/`ssh`/`vi` impossibles |
| Payload avec mauvaise IP | perte de temps |
| Attaquer hors scope | faute grave |
| Finir le rapport après la deadline | rapport non reçu |
| Ne pas dormir | erreurs de jugement en fin de course |

---

## 8. Checklist J-0

- [ ] VM snapshotée, réseau testé
- [ ] Dossier `/root/exam/` prêt
- [ ] Wordlists + binaires hors ligne
- [ ] Template de rapport prêt
- [ ] `script` lancé
- [ ] Tableau de suivi ouvert
- [ ] Aucune IA, aucun onglet writeup
- [ ] Eau / nourriture / alarmes

## Checklist avant rendu

- [ ] Toutes les cibles traitées ou documentées comme non compromises
- [ ] Chaque proof a `hostname` + `whoami`
- [ ] Chaque finding a une preuve reproductible
- [ ] Executive summary relu par un non-technicien (mentalement)
- [ ] PDF ouvert et vérifié
- [ ] Nom de fichier conforme
- [ ] Upload confirmé

---

## 9. Mental

- Un blocage n'est pas un échec : c'est une donnée. Note et change.
- 70 points ≠ 100 : viser les chemins connus, pas l'exploit exotique.
- Les points partiels existent : un shell user documenté vaut mieux que rien.
- Le rapport est la partie la plus prévisible : ne jamais la sacrifier.
