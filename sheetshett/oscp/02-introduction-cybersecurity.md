# 02 — Introduction to Cybersecurity

## Objectifs
Vocabulaire et cadre : menaces, CIA, contrôles, légalité. Peu d'examen direct, mais sert à rédiger l'executive summary.

---

## 1. Vocabulaire à ne pas confondre

| Terme | Définition | Exemple |
|---|---|---|
| **Risk** | probabilité × impact | perte de données client |
| **Threat** | acteur ou événement capable de nuire | groupe ransomware |
| **Vulnerability** | faiblesse exploitable | Apache 2.4.49 |
| **Exploit** | code/technique qui abuse la vuln | PoC CVE-2021-41773 |
| **Control** | mesure qui réduit le risque | patch, MFA, segmentation |

> Dans un rapport : une **vulnérabilité** n'est pas un **risque**. Le risque dépend du contexte (exposition, données, détection).

---

## 2. Trinité CIA

| Pilier | Atteinte | Exemple de finding |
|---|---|---|
| **Confidentiality** | lecture non autorisée | SQLi → dump de comptes |
| **Integrity** | modification non autorisée | upload de webshell, IDOR en écriture |
| **Availability** | déni de service | RCE → arrêt du service |

Ajouts fréquents : **Authenticity**, **Non-repudiation**, **Privacy**.

---

## 3. Types d'attaquants

| Acteur | Motivation | Moyens |
|---|---|---|
| Script kiddie | notoriété | outils publics |
| Cybercriminel | argent | phishing, ransomware |
| Insider | revanche, argent | accès légitime |
| APT / état | espionnage, sabotage | 0-day, persistance longue |
| Hacktiviste | idéologie | défiguration, DDoS |

---

## 4. Contrôles de sécurité

| Type | Rôle | Exemple |
|---|---|---|
| **Préventif** | empêcher | patch, WAF, MFA |
| **Détectif** | repérer | IDS, SIEM, logs |
| **Correctif** | limiter l'impact | backup, isolation |
| **Dissuasif** | décourager | bannière légale |
| **Compensatoire** | alternative | segmentation si patch impossible |

### Modèles mentaux utiles
- **Défense en profondeur** : plusieurs couches indépendantes.
- **Moindre privilège** : chaque compte a le minimum.
- **Zero Trust** : ne rien supposer du réseau interne.
- **Attack surface** : tout ce qui est joignable est attaquable.

---

## 5. Cadre légal (à connaître pour le rapport)

| Élément | Contenu |
|---|---|
| **Autorisation écrite** | indispensable, signée, datée |
| **Scope** | IP, domaines, horaires, exclusions |
| **RoE** | règles d'engagement : pas de DoS, pas de données réelles exfiltrées |
| **NDA** | confidentialité des résultats |
| **Responsible disclosure** | délai de correction avant publication |

En examen : le périmètre est strictement le réseau fourni. Toute sortie de scope est une faute.

---

## 6. Normes & frameworks

- **PTES** — phases de pentest (recon → reporting)
- **OWASP WSTG / Top 10** — web
- **MITRE ATT&CK** — techniques adverses (TTP), utile pour le rapport
- **NIST SP 800-115** — méthodologie de test
- **CVSS v3.1** — scoring (voir module 04)
- **ISO 27001 / SOC 2** — conformité côté client

---

## 7. Ce qu'on retient pour l'examen

- Le rapport parle **risque métier**, pas seulement technique.
- Une même vuln = sévérité différente selon l'exposition.
- Toujours lier un finding à un **pillar CIA** et à un **impact concret**.
- Documenter les **limitations** (temps, accès, scope) : c'est attendu, pas une faiblesse.
