# OSCP / PEN-200 — Sheetsheets par module

Fiches de révision pour les **24 modules officiels PEN-200** (OSCP / OSCP+), rédigées pour être utilisables **sans IA ni recherche internet**, comme en examen.

Chaque fiche contient : le *pourquoi* de la technique, les commandes exactes, les variantes manuelles (quand un outil n'est pas autorisé), les pièges classiques et une checklist.

> ⚠️ Usage légal uniquement : labs OffSec, environnements autorisés, CTF.

## Règles d'examen à connaître par cœur

| Règle | Détail |
|---|---|
| Durée | **23 h 45** de test + **24 h** pour rendre le rapport |
| Cibles | 3 machines AD (set) + 3 machines standalone, points partiels (user.txt / admin.txt / proof.txt) |
| Metasploit | **1 seule machine** peut utiliser Metasploit/Meterpreter/msfvenom (y compris pour générer un payload) |
| Scanners | Pas de scanner commercial (Nessus, Qualys…). Outils open-source OK |
| IA | **Interdite** : aucune assistance IA pendant l'examen |
| Rapport | Structure imposée par OffSec, preuves obligatoires, 24 h |
| Fail | < 70 points ; les points partiels comptent |

**Conséquence pratique** : tout doit être faisable « à la main » — SQLi manuelle, LFI, upload bypass, privesc manuelle, AD avec Impacket/BloodHound. Metasploit est un bonus, jamais une dépendance.

## Conventions

| Placeholder | Sens |
|---|---|
| `<TARGET>` / `<IP>` | cible |
| `<LHOST>` / `<LPORT>` | attaquant |
| `<DOMAIN>` | ex. `oscp.exam` |
| `<DC_IP>` | contrôleur de domaine |
| `<USER>` / `<PASS>` / `<NTHASH>` | identifiants |
| `<WORDLIST>` | `/usr/share/wordlists/rockyou.txt` |

## Index des modules

### Fondations
1. [General Course Introduction](01-general-introduction.md)
2. [Introduction to Cybersecurity](02-introduction-cybersecurity.md)
3. [Effective Learning Strategies](03-effective-learning.md)
4. [Report Writing for Penetration Testers](04-report-writing.md)

### Reconnaissance & scan
5. [Information Gathering](05-information-gathering.md)
6. [Vulnerability Scanning](06-vulnerability-scanning.md)

### Web
7. [Introduction to Web Applications](07-introduction-web-applications.md)
8. [Common Web Application Attacks](08-common-web-attacks.md)
9. [SQL Injection Attacks](09-sql-injection.md)
10. [Client-Side Attacks](10-client-side-attacks.md)

### Exploitation
11. [Locating Public Exploits](11-locating-public-exploits.md)
12. [Fixing Exploits](12-fixing-exploits.md)
13. [Antivirus Evasion](13-antivirus-evasion.md)
14. [Password Attacks](14-password-attacks.md)

### Post-exploitation
15. [Windows Privilege Escalation](15-windows-privesc.md)
16. [Linux Privilege Escalation](16-linux-privesc.md)
17. [Port Redirection and SSH Tunneling](17-port-redirection-ssh-tunneling.md)
18. [Advanced Tunneling](18-advanced-tunneling.md)
19. [The Metasploit Framework](19-metasploit.md)

### Active Directory
20. [AD Introduction and Enumeration](20-ad-introduction-enumeration.md)
21. [Attacking AD Authentication](21-ad-authentication.md)
22. [Lateral Movement in AD](22-ad-lateral-movement.md)

### Synthèse
23. [Assembling the Pieces](23-assembling-the-pieces.md)
24. [Trying Harder: The Labs](24-trying-harder.md)

### Annexes
- [**Exam Playbook**](EXAM-PLAYBOOK.md) — gestion du temps, scénarios, checklist J-0
- [File Transfers (annexe)](annexe-file-transfers.md) — hors syllabus depuis 2023 mais indispensable
- [**SysReptor**](../tools/sysreptor.md) — rédaction du rapport en markdown → PDF

## Progression conseillée (12 semaines)

| Sem. | Modules | Livrable |
|---|---|---|
| 1 | 1–4 | Setup VM, notes, template de rapport |
| 2 | 5–6 | 5 machines énumérées sans exploit |
| 3–4 | 7–9 | 10 web challenges + SQLi manuelles |
| 5 | 10–12 | 3 exploits publics modifiés |
| 6 | 13–14 | 1 machine avec hash cracking complet |
| 7 | 15 | 3 Windows privesc |
| 8 | 16 | 3 Linux privesc |
| 9 | 17–18 | Pivot double avec chisel + proxychains |
| 10 | 19 | MSF en mode « une seule machine » |
| 11–12 | 20–23 | 2 sets AD complets |

## Setup de la VM d'attaque

```bash
# Vérifier l'essentiel
for t in nmap ffuf gobuster feroxbuster whatweb nikto sqlmap hydra john hashcat \
         netexec bloodhound-python chisel socat proxychains4 rlwrap python3 gcc; do
  command -v $t >/dev/null || echo "MANQUANT: $t"
done

# Impacket
sudo apt install -y python3-impacket impacket-scripts
# Wordlists
ls /usr/share/wordlists/ /usr/share/seclists/Discovery/Web-Content/ | head
# Payloads Windows utiles (à garder hors ligne)
ls /usr/share/windows-resources/ 2>/dev/null || sudo apt install -y windows-resources
```

## Notes pendant l'examen

```
/root/exam/
├── 00-notes/
│   ├── targets.md          # tableau de suivi
│   ├── creds.md            # tous les identifiants trouvés
│   └── findings.md         # brouillon de rapport
├── 01-scans/
├── 02-exploits/
├── 03-loot/
└── 04-report/
```

Tableau de suivi (à tenir à jour, c'est ce qui évite de tourner en rond) :

| Cible | Ports | Accès | user | root/admin | Temps | Statut |
|---|---|---|---|---|---|---|
| 192.168.120.10 | 22,80 | ssh www-data | ✅ | — | 45 min | en cours |
| 192.168.120.11 | 445 | — | — | — | 20 min | bloqué |
