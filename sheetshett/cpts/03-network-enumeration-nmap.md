# 03 — Network Enumeration with Nmap

## Objectifs
Maîtriser la découverte d'hôtes, le scan de ports (TCP/UDP), la détection de services/OS et le NSE (Nmap Scripting Engine).

---

## 1. Découverte d'hôtes

```bash
# Ping sweep (ICMP echo)
nmap -sn 10.10.10.0/24

# Sans ICMP (réseaux filtrés)
nmap -sn -PE -PP -PS21,22,80,443,445 -PA80,443 10.10.10.0/24

# ARP (local, plus fiable)
sudo nmap -sn -PR 192.168.1.0/24

# Liste d'hôtes
nmap -sn -iL hosts.txt -oG sweep.txt
```

### Options de scan
| Option | Effet |
|---|---|
| `-sn` | Désactive le scan de ports (ping sweep) |
| `-Pn` | Désactive la découverte (considère l'hôte up) |
| `-n` / `-R` | Pas de résolution DNS / résolution forcée |
| `-PE -PP -PS -PA -PU` | Types de probes (ICMP echo, timestamp, SYN, ACK, UDP) |
| `--packet-trace` | Affiche les paquets envoyés/reçus |
| `--reason` | Affiche la raison de l'état du port |
| `--disable-arp-ping` | Désactive l'ARP ping |
| `--top-ports=<n>` | Top n ports |
| `-p-` | 1–65535 |
| `-p22-110` / `-p22,25` | Plages / liste |
| `-F` | Top 100 ports |

---

## 2. Types de scan TCP

```bash
# SYN scan (stealth, root requis) — défaut si root
sudo nmap -sS -p- <TARGET>

# TCP connect scan (pas de root)
nmap -sT -p- <TARGET>

# ACK scan (cartographie du firewall)
sudo nmap -sA -p- <TARGET>

# Window scan / Maimon / FIN / NULL / XMAS (contournement)
sudo nmap -sW <TARGET>
sudo nmap -sM <TARGET>
sudo nmap -sF -sN -sX <TARGET>

# Scan furtif (fragmentation + timing)
sudo nmap -sS -f --data-length 24 -T2 <TARGET>

# Leurrer (decoys)
sudo nmap -sS -D RND:10 <TARGET>

# Source port usurpé (DNS 53)
sudo nmap -sS -g 53 <TARGET>

# Scan via un hôte compromis (relay)
sudo nmap -sS --proxies http://<PROXY>:8080 <TARGET>
```

### États des ports
`open`, `closed`, `filtered`, `unfiltered`, `open|filtered`, `closed|filtered`.

---

## 3. Détection de services & OS

```bash
# Version + scripts default + traceroute
sudo nmap -sCV -O -p- --min-rate 5000 <TARGET>

# Intensité des scripts
nmap -sV --version-intensity 9 -p80,443 <TARGET>

# Banner grabbing sans Nmap
nc -nv <TARGET> 80
```

### Timing
| Template | Usage |
|---|---|
| `-T0` / `-T1` | Paranoïaque / furtif (IDS) |
| `-T2` | Poli |
| `-T3` | Normal (défaut) |
| `-T4` | Agressif (lab) |
| `-T5` | Insane (lab, risque de faux négatifs) |

```bash
# Contrôle fin
nmap --min-rate 5000 --max-retries 2 --host-timeout 30m -p- <TARGET>
```

---

## 4. UDP

```bash
# Top ports UDP
sudo nmap -sU --top-ports 100 <TARGET>

# Ports critiques
sudo nmap -sU -p53,67,68,69,111,123,137,138,161,162,500,514,520,1900 <TARGET>

# UDP + version
sudo nmap -sU -sV -p161 <TARGET>
```

UDP est lent : limiter les ports, utiliser `--max-retries 1` et `--min-rate`.

---

## 5. Sortie & formats

```bash
nmap -sCV -p- <TARGET> -oA scan_<TARGET>     # .nmap .gnmap .xml
nmap -sCV -p- <TARGET> -oN normal.txt -oX out.xml
xsltproc out.xml -o out.html                 # rapport HTML
```

Reprendre/relancer :
```bash
nmap --resume previous_scan.gnmap
```

Comparer deux scans :
```bash
ndiff scan1.xml scan2.xml
```

---

## 6. NSE — Nmap Scripting Engine

```bash
# Lister les scripts
ls /usr/share/nmap/scripts/ | grep smb
nmap --script-help smb-vuln-ms17-010

# Catégories
nmap --script "default" <TARGET>
nmap --script "safe and not intrusive" -p- <TARGET>
nmap --script "vuln" -p- <TARGET>
nmap --script "discovery" -p- <TARGET>
nmap --script "exploit" -p- <TARGET>

# Scripts nommés
nmap -p445 --script smb-vuln-ms17-010 <TARGET>
nmap -p445 --script smb-enum-shares,smb-enum-users <TARGET>
nmap -p80 --script http-enum,http-headers,http-methods <TARGET>
nmap -p80 --script http-shellshock --script-args uri=/cgi-bin/status <TARGET>

# Arguments de script
nmap -p80 --script http-brute --script-args userdb=users.txt,passdb=pass.txt <TARGET>

# Mise à jour de la base
sudo nmap --script-updatedb
```

### Scripts NSE les plus utiles en pentest
```bash
--script smb-os-discovery,smb-enum-shares,smb-enum-users,smb-vuln-*
--script http-title,http-headers,http-enum,http-methods,http-robots.txt
--script ssl-enum-ciphers,ssl-heartbleed
--script dns-zone-transfer,dns-brute
--script ftp-anon,ftp-brute
--script ssh-auth-methods,ssh-brute
--script mysql-enum,mysql-info
--script ms-sql-info,ms-sql-empty-password
--script snmp-brute,snmp-info
--script ldap-search,ldap-rootdse
```

---

## 7. Firewall / IDS evasion

```bash
# Fragmentation
sudo nmap -f -sS <TARGET>

# MTU personnalisé (multiple de 8)
sudo nmap --mtu 16 -sS <TARGET>

# Decoys
sudo nmap -D RND:5 <TARGET>

# Usurpation d'IP source (peu utile en pratique)
sudo nmap -S <SPOOF_IP> -e eth0 <TARGET>

# MAC spoof
sudo nmap --spoof-mac 0 <TARGET>

# Bad checksums / données aléatoires
sudo nmap --badsum <TARGET>
sudo nmap --data-length 50 <TARGET>
```

---

## 8. Scénarios concrets

### Scan externe rapide
```bash
sudo nmap -sS -sV -sC -T4 --min-rate 1000 -p- -oA external <TARGET>
```

### Scan interne furtif
```bash
sudo nmap -sS -T2 -f --data-length 32 -D RND:5 -p21,22,80,139,443,445,3389 <TARGET>
```

### Scan complet avec vulnérabilités
```bash
sudo nmap -sCV -p- --script vuln -oA full_vuln <TARGET>
```

### Cible Windows AD
```bash
nmap -sCV -p53,88,135,139,389,445,464,593,636,3268,3269,5985,9389 <DC_IP>
nmap -p445 --script smb-vuln-ms17-010,smb-enum-shares <DC_IP>
```

---

## Checklist
- [ ] Hôtes vivants identifiés
- [ ] 65535 ports TCP scannés
- [ ] Top UDP scannés
- [ ] Versions de services détectées (`-sV`)
- [ ] Scripts NSE ciblés exécutés
- [ ] Résultats sauvegardés (`-oA`)
- [ ] Faux positifs vérifiés manuellement

## Pièges
- `-T5` rate des ports sur liens chargés → préférer `--min-rate`.
- Le scan UDP sans `-sU --top-ports` prend des heures.
- `-O` nécessite root et une cible avec ≥1 port ouvert et ≥1 fermé.
- Les pare-feux peuvent renvoyer `filtered` sur des ports réellement ouverts.
