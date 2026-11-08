# 05 — Information Gathering

## Objectifs
Cartographier la cible sans la toucher (passif) puis avec précision (actif) : DNS, sous-domaines, services, technologies, utilisateurs.

---

## 1. Reconnaissance passive

```bash
# WHOIS / DNS
whois <DOMAIN>
dig +short A <DOMAIN>; dig +short MX <DOMAIN>; dig +short NS <DOMAIN>
dig TXT <DOMAIN>; dig TXT _dmarc.<DOMAIN>
dig ANY <DOMAIN> +noall +answer

# Transfert de zone (souvent oublié)
dig AXFR @<NS_SERVER> <DOMAIN>

# Sous-domaines via certificats
curl -s "https://crt.sh/?q=%25.<DOMAIN>&output=json" | jq -r '.[].name_value' | sort -u

# Historique / archives
curl -s "http://web.archive.org/cdx/search/cdx?url=*.<DOMAIN>&output=text&fl=original&collapse=urlkey" | head -50

# Google dorks (manuel)
site:<DOMAIN> filetype:pdf
site:<DOMAIN> inurl:admin
"<DOMAIN>" ext:sql | ext:env | ext:log
```

```bash
# Outils passifs
subfinder -d <DOMAIN> -silent -all
amass enum -passive -d <DOMAIN>
theHarvester -d <DOMAIN> -b bing,duckduckgo -l 200
```

---

## 2. Résolution & vhosts

```bash
# Ajouter les hôtes découverts
echo "<IP> <DOMAIN> www.<DOMAIN> dev.<DOMAIN>" | sudo tee -a /etc/hosts

# Vhost fuzzing (quand le DNS wildcard renvoie tout)
ffuf -u http://<TARGET> -H "Host: FUZZ.<DOMAIN>" \
     -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt \
     -fs <TAILLE_REPONSE_DEFAUT>

gobuster vhost -u http://<TARGET> -w <WORDLIST> --append-domain
```

```bash
# Comparer les réponses pour repérer le vrai site
curl -s -H "Host: dev.<DOMAIN>" http://<TARGET> | head
curl -s http://<TARGET> | head      # réponse par défaut
```

---

## 3. Scan actif (méthodologie complète)

```bash
# 1) Tous les ports TCP, rapide
sudo nmap -p- --min-rate 2000 -T4 -oN scans/allports.txt <TARGET>

# 2) Services + scripts sur les ports trouvés
ports=$(grep -oP '^\d+(?=/tcp)' scans/allports.txt | paste -sd,)
sudo nmap -sCV -p$ports -oN scans/services.txt <TARGET>

# 3) UDP (top ports, souvent lent)
sudo nmap -sU --top-ports 50 --open -oN scans/udp.txt <TARGET>

# 4) Scripts ciblés
sudo nmap -p445 --script smb-os-discovery,smb-enum-shares <TARGET>
sudo nmap -p80 --script http-enum,http-headers <TARGET>
sudo nmap -p53 --script dns-zone-transfer <TARGET>
```

### Options utiles
| Option | Usage |
|---|---|
| `-Pn` | pas de ping (host considéré up) |
| `-sS` | SYN scan (root) |
| `-sT` | connect scan (sans root, via proxy) |
| `-sV` | versions |
| `-sC` | scripts par défaut |
| `--script=<nom>` | script ciblé |
| `-O` | OS (peu fiable) |
| `-T4` | timing agressif raisonnable |
| `--min-rate 2000` | accélère le scan complet |
| `-oA` | tous les formats |

---

## 4. Énumération par service (le vrai travail)

```bash
# HTTP
whatweb -a3 http://<TARGET>
curl -sI http://<TARGET>            # headers, techno, redirections
curl -s http://<TARGET>/robots.txt http://<TARGET>/sitemap.xml
nikto -h http://<TARGET>
ffuf -u http://<TARGET>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -mc all -fc 404

# SMB
netexec smb <TARGET> -u '' -p '' --shares --users --groups
enum4linux-ng -A <TARGET>
smbclient -L //<TARGET>/ -N
smbmap -H <TARGET>

# FTP
ftp <TARGET>            # anonymous / anonymous
wget -r ftp://anonymous:anonymous@<TARGET>/

# SSH
ssh -o PreferredAuthentications=none <USER>@<TARGET>   # énumération de users via timing

# DNS
dnsrecon -d <DOMAIN> -t std,brt
dnsenum <DOMAIN>

# SMTP
smtp-user-enum -M VRFY -U users.txt -t <TARGET>
```

---

## 5. OSINT sur les personnes (utile pour AD)

```bash
# Format d'email probable : prenom.nom@<DOMAIN>
# Vérifier sur LinkedIn / site corporate (manuel)

# Générer des usernames
username_generator.py "John Doe"    # ou à la main :
# jdoe, john.doe, doej, j.doe

# Vérifier l'existence via Kerberos (AD) sans verrouillage
impacket-GetNPUsers <DOMAIN>/ -usersfile users.txt -dc-ip <DC_IP> -no-pass -format hashcat
```

---

## 6. Organisation des résultats

```
notes/<TARGET>/
├── nmap/          # -oA
├── web/           # ffuf, nikto, captures
├── creds.md       # identifiants découverts
└── summary.md     # 5 lignes : services, pistes, statut
```

### Tableau de synthèse (à remplir pour chaque cible)
| Port | Service | Version | Piste d'attaque |
|---|---|---|---|
| 22 | SSH | 8.2p1 | creds / clé |
| 80 | HTTP | Apache 2.4.49 | CVE-2021-41773 |
| 445 | SMB | Samba 4.6.2 | null session |

---

## 7. Pièges

- **Scanner seulement les 1000 ports** : rater 8080, 5985, 1433, 3306.
- **Ignorer UDP** : SNMP (161) donne parfois tout.
- **Ne pas ajouter les vhosts dans `/etc/hosts`** : site « inaccessible ».
- **Prendre `-T4` pour un scan fiable** : OK, mais vérifier avec un scan lent sur les ports ambigus.
- **Oublier l'énumération authentifiée** dès qu'un compte est obtenu.

---

## 8. Checklist

- [ ] Ports TCP complets scannés
- [ ] Versions et scripts sur chaque port
- [ ] UDP top 50
- [ ] Vhosts / sous-domaines
- [ ] Répertoires web + fichiers intéressants
- [ ] SMB / FTP / NFS en anonyme
- [ ] Users/enum via SMTP, Kerberos, RID
- [ ] Notes à jour avec pistes classées par priorité
