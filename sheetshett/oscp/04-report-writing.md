# 04 — Report Writing for Penetration Testers

## Objectifs
Prendre des notes exploitables **pendant** le test et produire le rapport OffSec en 24 h. 33 % de la note.

---

## 1. Prise de notes : la règle des 3 secondes

Dès qu'une commande fonctionne → **copier-coller immédiat** dans les notes. Ne jamais compter sur le scrollback.

```bash
script -a /root/exam/00-notes/session-$(date +%H%M).log
```

### Note par cible (à créer avant l'attaque)
```markdown
# 192.168.120.10 — LINUX01

## Scan
- 22/tcp ssh OpenSSH 8.2p1
- 80/tcp http Apache 2.4.49

## Accès user
Commande : `curl -s "http://192.168.120.10/cgi-bin/.%2e/.%2e/.%2e/..."`
Shell obtenu : www-data
Preuve : /root/exam/03-loot/192.168.120.10/user_proof.png

## Accès root
Méthode : SUID /usr/bin/find
Commande : `find . -exec /bin/sh -p \; -quit`
Preuve : proof.txt

## Horodatage
10:02 scan | 10:20 shell | 10:41 root
```

---

## 2. Structure du rapport OffSec

```
1. Cover Page
   - titre, client, dates, version, classification
2. Table of Contents
3. Executive Summary
   - objectif, périmètre, résultats globaux, risque, recommandations clés
4. Scope & Methodology
   - cibles, exclusions, fenêtre, outils, limitations
5. Attack Narrative (le cœur)
   - chronologique, par cible
   - commentaires, commandes, captures
6. Findings
   - un finding par vulnérabilité
7. Recommendations
8. Appendices
   - preuves, sorties brutes, timeline
```

### Executive Summary — modèle
```markdown
Ce test a évalué <N> systèmes du <DATE_AU> au <DATE>. Un attaquant non
authentifié a obtenu un accès administratif sur <N> d'entre eux, dont le
contrôleur de domaine <DC>, permettant la compromission complète du domaine.

Points saillants :
- Apache 2.4.49 obsolète (CVE-2021-41773) → exécution de code
- Réutilisation du même mot de passe administrateur local
- Service exécuté avec des privilèges excessifs (SeImpersonate)

Risque global : Critique.

Recommandations prioritaires :
1. Corriger les services exposés (patch < 30 jours)
2. Mots de passe locaux uniques (LAPS)
3. Restreindre les privilèges de service
```

Pas de jargon inutile, pas de commandes, une page.

---

## 3. Fiche de finding

```markdown
## F-01 — Remote Code Execution via Apache 2.4.49 (CVE-2021-41773)

| Champ | Valeur |
|---|---|
| Sévérité | Critical |
| CVSS | 9.8 (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H) |
| Actif | 192.168.120.10:80 |
| CWE | CWE-22 |
| Statut | Confirmé |

### Description
Le serveur Apache 2.4.49 autorise une traversée de répertoire...

### Preuve
```bash
curl -s --path-as-is "http://192.168.120.10/cgi-bin/.%2e/.%2e/.%2e/.%2e/etc/passwd"
```
Sortie :
```
root:x:0:0:root:/root:/bin/bash
```
Capture : `figures/F-01.png`

### Impact
Exécution de commandes en tant que www-data, puis root via SUID find.

### Remédiation
Mettre à jour Apache ≥ 2.4.51, désactiver mod_cgi, appliquer le moindre privilège.
```

### Règles de preuve
- Commande **exacte** + sortie **réelle**.
- Capture d'écran avec `hostname`, `whoami`/`id`, et le fichier proof.
- Horodatage.
- Aucune donnée inventée : si ce n'est pas reproduit, ce n'est pas un finding.

---

## 4. CVSS v3.1 sans calculateur

| Métrique | Valeurs | Question |
|---|---|---|
| **AV** Attack Vector | N / A / L / P | réseau, adjacent, local, physique |
| **AC** Attack Complexity | L / H | conditions particulières ? |
| **PR** Privileges Required | N / L / H | authentification nécessaire ? |
| **UI** User Interaction | N / R | victime doit cliquer ? |
| **S** Scope | U / C | impacte un autre composant ? |
| **C/I/A** | H / L / N | confidentialité, intégrité, dispo |

Repères :
| Score | Sévérité | Exemple |
|---|---|---|
| 9.0–10 | Critical | RCE non authentifié |
| 7.0–8.9 | High | SQLi avec dump, privesc admin |
| 4.0–6.9 | Medium | XSS stocké, IDOR |
| 0.1–3.9 | Low | énumération d'utilisateurs |
| 0.0 | Info | bannière de version |

```bash
pip install cvss
python3 -c "from cvss import CVSS3;print(CVSS3('AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H').scores())"
```

---

## 5. Rédaction rapide (méthode 4 h)

| Temps | Tâche |
|---|---|
| 0:00–0:30 | ranger les preuves, créer le squelette |
| 0:30–1:30 | Attack narrative (copier les notes, reformuler) |
| 1:30–3:00 | findings (titres, CVSS, description, remédiation) |
| 3:00–3:30 | executive summary (à écrire **en dernier**) |
| 3:30–4:00 | relecture, captures, PDF, vérification du nom de fichier |

### Erreurs fréquentes
- Captures illisibles ou non liées au finding.
- Findings sans commande reproductible.
- Executive summary copié du technique.
- Oublier le scope / les limitations.
- Mauvaise numérotation, TOC cassée.
- Rendre après la deadline (24 h).

---

## 6. Checklist avant rendu

- [ ] Toutes les cibles du scope traitées (même « non compromis » documenté)
- [ ] Chaque proof (user/admin) présent avec `hostname` + `whoami`/`id`
- [ ] Chaque finding : titre, sévérité, CVSS, preuve, impact, remédiation
- [ ] Attack narrative chronologique et lisible
- [ ] Executive summary ≤ 1 page
- [ ] Limitations explicites
- [ ] Numérotation / TOC / figures cohérentes
- [ ] PDF exporté, ouvert et relu
- [ ] Nom de fichier conforme, upload effectué, confirmation reçue
