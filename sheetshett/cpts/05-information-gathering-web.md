# 05 — Information Gathering (Web Edition)

## Objectifs
Cartographier une application web : domaines, sous-domaines, vhosts, technologies, endpoints cachés, fuites d'information (GitHub, archives, certificats, DNS).

---

## 1. WHOIS / DNS / IP

```bash
whois <DOMAIN>
dig +short A <DOMAIN>
dig +short MX <DOMAIN>
dig +short NS <DOMAIN>
dig +short TXT <DOMAIN>
dig axfr <DOMAIN> @<NS>

# Historique DNS
# securitytrails, viewdns.info, dnsdumpster (OSINT)

# Reverse DNS / ASN
host <IP>
whois <IP> | grep -i "orgname\|netname\|cidr"
amass intel -whois -d <DOMAIN>
```

---

## 2. Sous-domaines

```bash
# Passif
subfinder -d <DOMAIN> -all -silent -o subs.txt
amass enum -passive -d <DOMAIN> -o amass.txt
assetfinder --subs-only <DOMAIN>
curl -s "https://crt.sh/?q=%25.<DOMAIN>&output=json" | jq -r '.[].name_value' | sort -u
gau <DOMAIN> | cut -d/ -f3 | sort -u

# Actif (brute force DNS)
gobuster dns -d <DOMAIN> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-20000.txt -t 50 --wildcard
ffuf -u http://FUZZ.<DOMAIN> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -fs 0

# Résolution en masse
dnsx -l subs.txt -a -resp -o resolved.txt
httpx -l subs.txt -status-code -title -tech-detect -o live.txt

# Permutation / alt names
altdns -i subs.txt -o alts.txt -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
```

### Zones DNS / PTR
```bash
dnsrecon -d <DOMAIN> -t std,axfr,brt
fierce --domain <DOMAIN> --dns-servers <NS_IP>
```

---

## 3. Virtual hosts — Host header fuzzing

```bash
ffuf -u http://<TARGET> -H "Host: FUZZ.<DOMAIN>" \
  -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt \
  -fs 0 -mc all

gobuster vhost -u http://<TARGET> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt --append-domain

# Détection de vhost par comparaison de taille/status
ffuf -u http://<TARGET> -H "Host: FUZZ" -w vhosts.txt -fr "not found"
```

> Un vhost n'est pas un sous-domaine DNS : il faut tester `Host:` sur le même IP.

---

## 4. Fingerprinting de technologie

```bash
whatweb -a 3 http://<TARGET>
wafw00f http://<TARGET>
nmap -p80,443 --script http-headers,http-methods,http-enum,http-title <TARGET>

# Headers détaillés
curl -sI http://<TARGET>
curl -sv http://<TARGET> 2>&1 | grep -i "server\|x-powered"

# Technologies JS / frameworks
webanalyze -host <TARGET> -crawl
nuclei -u http://<TARGET> -t technologies

# Certificats TLS
openssl s_client -connect <TARGET>:443 -servername <DOMAIN> </dev/null | openssl x509 -noout -text
```

---

## 5. Contenu & endpoints cachés

```bash
# Répertoires / fichiers
ffuf -u http://<TARGET>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -mc 200,204,301,302,307,401,403 -fc 404
gobuster dir -u http://<TARGET> -w /usr/share/seclists/Discovery/Web-Content/common.txt -x php,html,js,txt,bak,old,zip

# Extensions
ffuf -u http://<TARGET>/indexFUZZ -w ext.txt

# Fichiers sensibles
for f in robots.txt sitemap.xml .git/HEAD .env .DS_Store backup.zip config.php.bak phpinfo.php crossdomain.xml; do
  code=$(curl -s -o /dev/null -w "%{http_code}" http://<TARGET>/$f); echo "$code $f";
done

# Git exposé
wget -r http://<TARGET>/.git/
git-dumper http://<TARGET>/.git/ ./git_dump
```

### Wordlists Seclists utiles
```
Discovery/Web-Content/common.txt
Discovery/Web-Content/raft-medium-directories.txt
Discovery/Web-Content/directory-list-2.3-medium.txt
Discovery/Web-Content/api/objects.txt
Discovery/Web-Content/burp-parameter-names.txt
Discovery/DNS/subdomains-top1million-5000.txt
```

---

## 6. OSINT & fuites

```bash
# Google dorks
site:<DOMAIN> filetype:pdf
site:<DOMAIN> inurl:admin
site:<DOMAIN> intitle:"index of"
site:pastebin.com "<DOMAIN>"

# Archives web
waybackurls <DOMAIN> | tee wayback.txt
gau <DOMAIN> --threads 5 | tee gau.txt
katana -u http://<TARGET> -jc -d 3 -o crawl.txt

# GitHub (secrets)
# trufflehog, gitleaks (sur un repo cloné ou organization)
trufflehog github --org=<ORG> --only-verified

# Shodan / Censys
shodan host <IP>
shodan search 'ssl:"<DOMAIN>"'

# Emails / fuites
h8mail -t admin@<DOMAIN>
haveibeenpwned (API)
```

---

## 7. Crawling & énumération applicative

```bash
# Crawl + JS parsing
katana -u http://<TARGET> -jc -kf all -d 4 -o urls.txt
hakrawler -url http://<TARGET> -depth 3
gospider -s http://<TARGET> -d 3 -c 10

# Paramètres cachés
arjun -u http://<TARGET>/api/endpoint -m GET
paramspider -d <DOMAIN>

# Formulaires / inputs
python3 -c "import requests,re;print(re.findall(r'<form.*?</form>',requests.get('http://<TARGET>').text,re.S))"

# Analyse JS
curl -s http://<TARGET>/app.js | grep -Eo '"/[a-zA-Z0-9_/-]+"' | sort -u
```

---

## 8. Méthodologie

1. **Passif** : whois, DNS, crt.sh, subfinder, amass, archives, GitHub.
2. **Résolution et vivacité** : dnsx → httpx.
3. **Fingerprint** : whatweb, wafw00f, headers, certificats.
4. **Vhosts** : ffuf Host header.
5. **Contenu** : ffuf/gobuster + extensions + fichiers sensibles.
6. **Crawl** : katana/gospider → URLs + paramètres.
7. **Fuite** : .git, .env, backups, JS sources, API docs (`/swagger`, `/openapi.json`).

### Fichiers à toujours tester
```
/robots.txt /sitemap.xml /.git/HEAD /.env /.env.bak /.svn/entries
/backup.zip /backup.tar.gz /db.sql /dump.sql /config.php.bak
/server-status /phpinfo.php /swagger /swagger-ui /api/docs /openapi.json
/.well-known/security.txt /crossdomain.xml /web.config
```

---

## Checklist
- [ ] Domaine racine + tous les sous-domaines
- [ ] Vhosts testés sur l'IP
- [ ] Technologies et WAF identifiés
- [ ] Contenu caché (dirs, fichiers, backups, .git)
- [ ] URLs historiques et paramètres
- [ ] Fuites (secrets, emails, credentials)
- [ ] Cartographie documentée
