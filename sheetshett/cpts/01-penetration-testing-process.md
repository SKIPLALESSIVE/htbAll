# 01 — Penetration Testing Process

## Objectifs du module
Comprendre les **6 phases** d'un pentest et les livrables associés : pré-engagement, information gathering, vulnerability assessment, exploitation, post-exploitation, reporting. Savoir rédiger un scope, des règles d'engagement (RoE) et un rapport.

---

## 1. Pre-Engagement

### Éléments contractuels
| Élément | Contenu |
|---|---|
| **NDA** | Confidentialité mutuelle, données, résultats |
| **Scope** | Domaines, IP, applications, environnements **inclus** et **exclus** |
| **Timeframe** | Fenêtre de test, heures ouvrées / hors heures |
| **RoE** | Ce qui est autorisé (DoS ? ingénierie sociale ? exfiltration ?) |
| **Targets** | Liste validée des cibles et contacts d'urgence |
| **Communication** | Canal, fréquence, rapport quotidien |
| **Payment** | Acompte, jalons, pénalités |

### Checklist pré-engagement
- [ ] Scope écrit et signé (in/out of scope)
- [ ] Autorisation légale du propriétaire des systèmes
- [ ] Contacts techniques + escalade 24/7
- [ ] Tests destructifs explicitement autorisés ou non
- [ ] Gestion des données collectées (stockage, rétention, destruction)
- [ ] Assurance / limitation de responsabilité
- [ ] Plan de communication des incidents critiques

### Template de scope (extrait)
```
Client: ACROMA
Période: 01/03 → 15/03
Scope:
  10.10.10.0/24 (interne)
  *.inlanefreight.htb (externe)
Out of scope:
  Production DB 10.10.10.50
  Social engineering / phishing
Autorisé: exploitation, pivoting, password cracking
Interdit: DoS, destruction de données, exfiltration réelle
```

---

## 2. Information Gathering

Deux volets :
- **OSINT / passif** : sans toucher la cible (WHOIS, DNS, certificats, GitHub, Shodan).
- **Actif** : scans, banner grabbing, énumération de services.

```bash
whois <DOMAIN>
dig any <DOMAIN> @1.1.1.1
curl -s "https://crt.sh/?q=%25.<DOMAIN>&output=json" | jq -r '.[].name_value' | sort -u
theHarvester -d <DOMAIN> -b all
nmap -sCV -p- <IP>
```

Livrable : cartographie des actifs, technologies, employés, emails, credentials fuités.

---

## 3. Vulnerability Assessment

- Croiser versions/services avec CVE (searchsploit, Nuclei, Nessus/OpenVAS).
- Qualifier : **CVSS**, exploitabilité réelle, exposition, impact métier.
- Éviter le bruit : prioriser les vulnérabilités exploitables dans le contexte.
- **Faux positifs** : toujours confirmer manuellement avant de rapporter.

```bash
searchsploit apache 2.4.49
nuclei -u https://<TARGET> -severity critical,high
nmap --script vuln -p 80,443 <IP>
```

---

## 4. Exploitation

Principes :
1. **PoC minimal** : prouver l'impact, pas détruire.
2. **Un vecteur à la fois**, journaliser chaque commande (timestamp).
3. Capture d'écran + sortie brute pour le rapport.
4. Vérifier l'accès obtenu (`id`, `whoami /priv`), noter le chemin d'attaque.

```bash
# Journalisation de session
script -q -a engagement_$(date +%F).log
```

---

## 5. Post-Exploitation

Ordre de priorité :
1. **Local enumeration** (utilisateurs, réseau, logiciels, secrets)
2. **Privilege escalation**
3. **Credential harvesting** (fichiers de conf, historique, navigateurs, mémoire)
4. **Lateral movement** (pivoting, réutilisation de hash/tickets)
5. **Persistence** (seulement si autorisé — souvent interdit)
6. **Data exfiltration** (souvent simulée / marqueur)

```bash
# Linux
id; sudo -l; uname -a; cat /etc/os-release; find / -perm -4000 2>/dev/null
# Windows
whoami /all; systeminfo; net user; net localgroup administrators
```

**Règle d'or** : ne jamais laisser de backdoor non documentée. Toute persistance doit être listée et retirée en fin de mission.

---

## 6. Reporting

Structure standard (voir module 27) :
1. Executive Summary (1 page, non technique)
2. Scope & méthodologie
3. Risk rating (CVSS + impact métier)
4. Findings détaillés (titre, sévérité, preuve, remédiation, références)
5. Annexes (tools, logs, captures)

### Niveaux de sévérité
| Sévérité | CVSS | Exemple |
|---|---|---|
| Critical | 9.0–10.0 | RCE non authentifiée, DC compromise |
| High | 7.0–8.9 | SQLi avec dump admin, privesc root/SYSTEM |
| Medium | 4.0–6.9 | IDOR, XSS stocké, info disclosure |
| Low | 0.1–3.9 | Banner, TLS faible, énumération |
| Info | 0.0 | Bonnes pratiques |

---

## Checklist de fin de mission
- [ ] Toutes les cibles du scope testées (ou justification)
- [ ] Preuves horodatées pour chaque finding
- [ ] Findings revérifiés (pas de faux positif)
- [ ] Comptes/artefacts créés supprimés et listés
- [ ] Rapport relu, executive summary compréhensible par un non-technique
- [ ] Restitution client planifiée
