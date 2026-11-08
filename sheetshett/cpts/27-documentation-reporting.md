# 27 — Documentation & Reporting

## Objectifs
Produire un rapport de pentest professionnel : structure, preuves, scoring, remédiation, executive summary, et tenir une documentation exploitable pendant le test.

---

## 1. Documentation pendant le test

### Journal de session
```bash
# Horodater toutes les commandes
script -q -a engagement_$(date +%F).log

# Ou par outil
nmap ... -oA scans/nmap_<host>
ffuf ... -o ffuf/dirs.json -of json
sqlmap ... --output-dir sqlmap/<host>
```

### Arborescence type
```
engagement/
├── 00-scope/
│   ├── scope.md
│   └── roe.pdf
├── 01-recon/
│   ├── nmap/
│   ├── dns/
│   └── osint/
├── 02-exploitation/
│   ├── <host>/
│   │   ├── notes.md
│   │   ├── proof/
│   │   └── loot/
├── 03-post/
├── 04-report/
│   ├── report.md
│   ├── report.pdf
│   └── findings/
└── 05-cleanup/
    └── cleanup.md
```

### Template de notes par hôte
```markdown
# Host: 10.10.10.20 (web01.inlanefreight.htb)

## Services
- 22/tcp OpenSSH 8.2p1
- 80/tcp Apache 2.4.49

## Credentials
| user | password | source |
|---|---|---|
| admin | Admin123! | config.php |

## Findings
- [ ] CVE-2021-41773 (path traversal)
- [ ] IDOR sur /api/user/{id}

## Timeline
- 10:02 scan nmap
- 10:15 découverte /cgi-bin
- 10:22 lecture /etc/passwd
```

---

## 2. Structure du rapport

### Page de garde
- Titre, client, dates, version, classification (Confidentiel)
- Auteur, contact, numéro de contrat

### 1. Executive Summary (1 page max)
- Objectif et périmètre
- **Verdict global** (ex. « risque élevé »)
- 3–5 findings majeurs en langage métier
- Impact business (données, conformité, continuité)
- Recommandations prioritaires
- **Pas de jargon**, pas de commandes

### 2. Scope & Methodology
- Cibles incluses / exclues
- Fenêtre de test
- Méthodologie (PTES, OWASP, MITRE ATT&CK)
- Limitations (accès, temps, outils bloqués)
- Références aux règles d'engagement

### 3. Risk Rating
- Échelle utilisée (CVSS v3.1 + impact métier)
- Tableau récapitulatif des findings triés par sévérité

### 4. Findings détaillés
Un finding = une fiche :

```markdown
## F-01 — RCE via Apache 2.4.49 (CVE-2021-41773)

**Sévérité** : Critical — CVSS 9.8
**Actif** : 10.10.10.20:80 (web01)
**Catégorie** : CWE-22 Path Traversal → CWE-78 RCE
**Statut** : Confirmé

### Description
Le serveur Apache 2.4.49 est vulnérable à une traversée de répertoire
permettant la lecture de fichiers hors racine web. Combinée à mod_cgi,
elle permet l'exécution de commandes arbitraires.

### Preuve
Requête :
```http
GET /cgi-bin/.%2e/.%2e/.%2e/.%2e/etc/passwd HTTP/1.1
Host: 10.10.10.20
```
Réponse (extrait) :
```
root:x:0:0:root:/root:/bin/bash
```
Capture : `proof/F-01.png`

### Impact
Un attaquant non authentifié peut exécuter des commandes en tant que
www-data, puis escalader vers root (voir F-05).

### Remédiation
- Mettre à jour Apache ≥ 2.4.51
- Désactiver mod_cgi si non nécessaire
- Restreindre les permissions du processus web

### Références
- NVD CVE-2021-41773
- Apache Security Advisory
```

### 5. Annexes
- Liste des outils et versions
- Timeline complète
- Détail des comptes créés / artefacts
- Logs bruts
- Glossaire

---

## 3. Scoring

```bash
# CVSS 3.1
python3 -c "from cvss import CVSS3; c=CVSS3('AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H'); print(c.scores(), c.severities())"
```

### Combiner CVSS et contexte
| Facteur | Question |
|---|---|
| Exposition | Internet / interne / local ? |
| Données | PII, secrets, financier ? |
| Continuité | service critique ? |
| Détection | EDR / logs / WAF ? |
| Facilité | exploit public ? authentification ? |

### Tableau des findings
| ID | Titre | Sévérité | CVSS | Actif | Statut |
|---|---|---|---|---|---|
| F-01 | RCE Apache | Critical | 9.8 | 10.10.10.20 | Confirmé |
| F-02 | SQLi login | High | 8.1 | app.htb | Confirmé |
| F-03 | IDOR | Medium | 5.3 | api.htb | Confirmé |

---

## 4. Preuves

Règles :
- **Reproductibles** : commande exacte + sortie.
- **Horodatées**.
- **Minimales** : ne pas dumper plus que nécessaire.
- **Anonymisées** si données personnelles.
- Captures lisibles (pas de terminal illisible).

```bash
# Capture de preuve propre
curl -s "http://<TARGET>/vuln?x=1" | tee proof/F-02_response.txt
sha256sum proof/* > proof/checksums.txt
```

---

## 5. Rédaction

### Bonnes pratiques
- Voix active, phrases courtes.
- Un finding = un problème = une remédiation.
- Distinguer **cause** et **symptôme**.
- Quantifier l'impact (« accès à 12 000 comptes clients »).
- Ne pas inclure de données sensibles réelles.
- Relecture orthographique et technique.

### Erreurs fréquentes
- Executive summary trop technique.
- Findings sans preuve.
- Sévérités incohérentes.
- Remédiations irréalistes.
- Oublier le hors-scope.
- Ne pas mentionner les limitations.

---

## 6. Restitution

- **Debrief technique** : équipe IT, détail des findings.
- **Debrief exécutif** : direction, risques et priorités.
- **Q&A** et plan de remédiation.
- **Retest** : vérifier les corrections (souvent inclus).

### Checklist avant livraison
- [ ] Tous les findings ont une preuve
- [ ] Sévérités cohérentes (CVSS + contexte)
- [ ] Executive summary ≤ 1 page et compréhensible
- [ ] Scope et limitations explicites
- [ ] Remédiations actionnables
- [ ] Données sensibles expurgées
- [ ] Annexes complètes
- [ ] Version et date à jour
- [ ] Relecture par un pair

---

## 7. Template de rapport minimal

```markdown
# Penetration Test Report — <CLIENT>
Date: <DATE> | Version: 1.0 | Classification: Confidentiel

## 1. Executive Summary
...

## 2. Scope & Methodology
...

## 3. Summary of Findings
| ID | Finding | Severity | CVSS |

## 4. Detailed Findings
### F-01 ...
### F-02 ...

## 5. Remediation Plan
| Priorité | Action | Responsable | Échéance |

## 6. Annexes
- A. Tools
- B. Timeline
- C. Evidence
```
