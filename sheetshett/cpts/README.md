# CPTS — Hack The Box · Sheetsheets par module

Fiches de révision complètes pour les **28 modules** du parcours *Penetration Tester* menant à la certification **HTB CPTS**.
Chaque fiche contient : objectifs, méthodologie de reconnaissance, commandes prêtes à l'emploi, techniques d'exploitation, bypass et checklist.

> ⚠️ Usage légal uniquement : labs HTB, environnements autorisés, CTF. Toutes les cibles sont notées `<TARGET>`, `<IP>`, `<DOMAIN>`.

## Conventions

| Placeholder | Signification |
|---|---|
| `<TARGET>` / `<IP>` | IP ou hostname de la cible |
| `<DOMAIN>` | Domaine (ex. `inlanefreight.htb`) |
| `<DC_IP>` | Contrôleur de domaine |
| `<LHOST>` / `<LPORT>` | IP et port de l'attaquant |
| `<USER>` / `<PASS>` | Identifiants compromis |
| `<WORDLIST>` | ex. `/usr/share/wordlists/rockyou.txt` |

## Index des modules

### 0. Introduction
1. [Penetration Testing Process](01-penetration-testing-process.md)
2. [Getting Started](02-getting-started.md)

### 1. Enumeration & Attack Planning
3. [Network Enumeration with Nmap](03-network-enumeration-nmap.md)
4. [Footprinting](04-footprinting.md)
5. [Information Gathering — Web Edition](05-information-gathering-web.md)
6. [Vulnerability Assessment](06-vulnerability-assessment.md)

### 2. Getting Access
7. [File Transfers](07-file-transfers.md)
8. [Shells & Payloads](08-shells-and-payloads.md)
9. [Using the Metasploit Framework](09-metasploit.md)
10. [Password Attacks](10-password-attacks.md)
11. [Attacking Common Services](11-attacking-common-services.md)
12. [Pivoting, Tunneling & Port Forwarding](12-pivoting-tunneling.md)
13. [Active Directory Enumeration & Attacks](13-active-directory.md)

### 3. Web Exploitation
14. [Using Web Proxies](14-web-proxies.md)
15. [Attacking Web Applications with Ffuf](15-ffuf.md)
16. [Login Brute Forcing](16-login-brute-forcing.md)
17. [SQL Injection Fundamentals](17-sql-injection.md)
18. [SQLMap Essentials](18-sqlmap.md)
19. [Cross-Site Scripting (XSS)](19-xss.md)
20. [File Inclusion](20-file-inclusion.md)
21. [File Upload Attacks](21-file-upload.md)
22. [Command Injections](22-command-injections.md)
23. [Web Attacks](23-web-attacks.md)
24. [Attacking Common Applications](24-common-applications.md)

### 4. Post-Exploitation
25. [Linux Privilege Escalation](25-linux-privesc.md)
26. [Windows Privilege Escalation](26-windows-privesc.md)

### 5. Reporting & Capstone
27. [Documentation & Reporting](27-documentation-reporting.md)
28. [Attacking Enterprise Networks](28-attacking-enterprise-networks.md)

### 6. Avant l'examen
- [**Fiche Exam CPTS**](EXAM-CHEATSHEET.md) — plan d'attaque condensé, matrice port → attaque, chaîne AD, privesc, rapport
- [**SysReptor**](../tools/sysreptor.md) — outil de rapport (hébergement HTB gratuit, design CPTS)

## Cheatsheets PDF d'origine
Les PDF officiels HTB présents dans `sheetshett/` couvrent : Nmap, Footprinting, File Transfers, SQLi Fundamentals, Command Injections, Server-side Attacks. Les fiches markdown ci-dessous les complètent et les dépassent.

## Setup rapide de l'environnement

```bash
# Pwnbox / Kali : vérifier les outils de base
sudo apt update && sudo apt install -y nmap ffuf gobuster feroxbuster sqlmap hydra john hashcat \
  netexec impacket-scripts bloodhound.py chisel socat proxychains4 seclists enum4linux-ng \
  whatweb wafw00f nikto nuclei

# Wordlists
sudo ln -sf /usr/share/seclists /opt/seclists
ls /usr/share/seclists/Discovery/Web-Content/

# Connexion VPN HTB
sudo openvpn --config labs_SKIPLALESSIVE.ovpn
```

## Aide-mémoire transversal

```bash
# Scan rapide de tous les ports + services
nmap -p- --min-rate 5000 -T4 -oN allports.txt <TARGET>
nmap -sCV -p$(grep -oP '^\d+(?=/tcp)' allports.txt | paste -sd,) -oN services.txt <TARGET>

# Serveur HTTP de partage
python3 -m http.server 8000

# Reverse shell listener
rlwrap nc -lvnp 4444

# Upgrade de shell TTY (Linux)
python3 -c 'import pty;pty.spawn("/bin/bash")'   # puis Ctrl+Z
stty raw -echo; fg                                # puis
export TERM=xterm; stty rows 40 cols 180
```
