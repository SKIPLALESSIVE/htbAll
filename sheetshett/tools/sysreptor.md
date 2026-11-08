# SysReptor — Cheatsheet reporting

> Plateforme de reporting pentest : tu écris en **Markdown**, le design est en **HTML/Vue**, export **PDF**.
> Community Edition gratuite (self-hosted). HTB offre un hébergement gratuit avec le design officiel CPTS/OSCP.
> ⚠️ Nom correct : **SysReptor** (pas « sysreport »).

---

## 1. Concepts

| Objet | Rôle |
|---|---|
| **Project** | Un engagement = un projet (client, dates, scope) |
| **Report** | Le livrable structuré : sections + findings |
| **Findings** | Vulnérabilités, créés depuis des **Finding Templates** |
| **Notes** | Brouillons, sorties brutes, captures — jamais dans le PDF |
| **Finding Templates** | Bibliothèque réutilisable (source du gain de temps) |
| **Design** | Mise en page HTML/CSS → PDF, séparée du contenu |
| **Report Sections** | Chapitres libres (Executive Summary, Scope…) |

---

## 2. Installation self-hosted

```bash
# Docker (recommandé)
curl -s https://docs.sysreptor.com/install.sh | bash
# ou manuel
git clone https://github.com/Syslifters/sysreptor
cd sysreptor/deploy
cp app.env.example app.env
# éditer app.env : SECRET_KEY, ALLOWED_HOSTS, ENCRYPTION_KEY
docker compose up -d
# → http://localhost:8000
```

```bash
# Créer le superuser
docker compose exec app python3 manage.py createsuperuser
```

### Importer les designs/templates HTB
```bash
docker compose exec --no-TTY app python3 manage.py importdemodata --type=project
docker compose exec --no-TTY app python3 manage.py importdemodata --type=design
docker compose exec --no-TTY app python3 manage.py importdemodata --type=findingtemplate
# Designs HTB (CPTS, CWEE, OSCP-like)
curl -s "https://docs.sysreptor.com/assets/htb-designs.tar.gz" | tar xz
```

---

## 3. Workflow d'engagement

```bash
# 1. Créer le projet (nom, client, dates, scope)
# 2. Créer les notes par hôte AVANT de commencer
# 3. Capturer au fil de l'eau
# 4. Transformer les notes en findings
# 5. Publish → PDF
```

### Arborescence de notes conseillée
```
Notes/
├── 00-scope
├── 01-recon/
│   ├── nmap-10.10.10.20
│   └── ffuf-web01
├── 02-hosts/
│   ├── 10.10.10.20-web01
│   │   ├── creds
│   │   ├── commandes
│   │   └── captures
│   └── 10.10.10.25-dc01
├── 03-findings-brouillon
└── 04-cleanup
```

### Note type par hôte
```markdown
# 10.10.10.20 — web01.inlanefreight.htb

## Services
- 22/tcp OpenSSH 8.2p1
- 80/tcp Apache 2.4.49

## Credentials
| user | secret | source |
|---|---|---|
| admin | Admin123! | /var/www/config.php |

## Accès
`ssh admin@10.10.10.20` → user

## Findings
- [ ] F-01 RCE Apache (CVE-2021-41773)
- [ ] F-02 Credentials en clair

## Prochaines étapes
- privesc : sudo -l → rien ; SUID ?
```

---

## 4. Markdown SysReptor

```markdown
# Titre 1
## Titre 2

**gras**  *italique*  `code`  ~~barré~~

- liste
  - sous-liste
1. numérotée

> citation / avertissement

[^1] note de bas de page

| Col | Col |
|---|---|
| a | b |
```

### Blocs de code
````markdown
```bash
nmap -sCV <TARGET>
```
````

### Images & pièces jointes
```markdown
![Capture F-01](/images/f-01.png)
```
- Coller une image dans un champ texte → upload automatique.
- Les fichiers du projet sont listés dans *Files* ; référencer par `/files/<nom>`.

### Encadrés de sévérité (designs HTB)
```markdown
::: info
Information
:::
::: warn
Avertissement
:::
::: danger
Critique
:::
```

### Champs de formulaire
Les designs exposent des champs (`title`, `customer`, `cvss`, `severity`…) remplis dans le panneau de droite, pas dans le markdown.

---

## 5. Créer un finding

1. *Findings* → **Create from template** (ou *Blank*).
2. Remplir :

| Champ | Contenu |
|---|---|
| Title | `Remote Code Execution via Apache 2.4.49 (CVE-2021-41773)` |
| Severity | Critical / High / Medium / Low / Info |
| CVSS | vecteur + score |
| Affected Components | `10.10.10.20:80 (web01)` |
| Description | ce qui est vulnérable, où, comment |
| Evidence | commandes, sorties, captures |
| Impact | conséquence métier concrète |
| Recommendation | correction actionnable |
| References | CVE, CWE, éditeur |

### Finding template (à réutiliser)
```markdown
## Description
Le service <SERVICE> exposé sur <HOST>:<PORT> ...

## Proof of Concept
```bash
<COMMAND>
```
Résultat :
```
<OUTPUT>
```

## Impact
Un attaquant non authentifié peut ...

## Remediation
- Mettre à jour vers <VERSION>
- Restreindre l'accès à <HOST>
- Surveiller <LOG>
```

### Sévérités
| Niveau | Critère |
|---|---|
| Critical | RCE non authentifié, DA, données massives |
| High | Auth bypass, privesc admin, SQLi avec dump |
| Medium | XSS stocké, IDOR, info disclosure sensible |
| Low | Enumération, headers manquants, version disclosure |
| Info | Bonnes pratiques, sans impact direct |

---

## 6. Design (HTML/Vue)

Structure d'un design :
```
design/
├── report.html        # rendu PDF
├── report.css
├── report.js
└── assets/
```

```html
<!-- Boucle sur les findings -->
<div v-for="finding in report.findings" class="finding">
  <h2>{{ finding.title }}</h2>
  <span :class="finding.severity">{{ finding.severity }}</span>
  <div v-html="finding.description"></div>
</div>

<!-- Boucle sur les sections -->
<div v-for="section in report.sections" v-html="section.content"></div>
```

```css
@page { size: A4; margin: 20mm; }
.finding { page-break-inside: avoid; }
.severity.critical { color: #b00020; font-weight: 700; }
```

Outils : *Designer* intégré, aperçu live, mode debug (`?debug=1`).

---

## 7. Export & livraison

```
Publish → Preview → Download PDF
- nom de fichier personnalisable
- mot de passe PDF optionnel
```

```bash
# Export archive projet (backup / transfert)
# Projects → sélectionner → Export .tar.gz
# Import : Projects → Import

# Export markdown (plugin self-hosted)
# app.env : ENABLED_PLUGINS=markdownexport
```

Pas d'export DOCX (par design). Les clients qui exigent Word → convertir le PDF ou utiliser le plugin markdown + pandoc :
```bash
pandoc report.md -o report.docx --reference-doc=template.docx
```

---

## 8. API & CLI

```bash
# Token : Settings → API Tokens
export SYSREPTOR_TOKEN=<TOKEN>
export SYSREPTOR_HOST=https://sysreptor.example.com
```

```bash
pip install sysreptor-cli
sysreptor projects list
sysreptor projects create --name "ACME - Pentest" --design <DESIGN_ID>
sysreptor findings create --project <ID> --template <TPL_ID>
sysreptor push --project <ID>   # pousse un dossier local de markdown
```

### API brute
```bash
curl -s -H "Authorization: Bearer $SYSREPTOR_TOKEN" \
  "$SYSREPTOR_HOST/api/v1/pentestprojects/" | jq '.[].name'

# Créer un projet
curl -s -X POST "$SYSREPTOR_HOST/api/v1/pentestprojects/" \
  -H "Authorization: Bearer $SYSREPTOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"ACME 2026","design":"<DESIGN_ID>","tags":["external"]}'
```

### Import d'outils
```bash
# Nmap XML → findings/sections
sysreptor import nmap scan.xml --project <ID>
# Nessus / Burp / OpenVAS / ZAP / SSLyze supportés
```

---

## 9. Astuces exam

- **Créer les notes avant les findings** : ne jamais perdre une commande qui a marché.
- **Un finding par vulnérabilité**, pas un par machine.
- **Copier-coller la sortie brute** dans Evidence, puis résumer en une phrase.
- **Captures nommées** `F-01_proof.png` → référence directe dans le finding.
- **Templates perso** : créer 5–10 templates (RCE, SQLi, XSS, privesc, creds en clair, SMB signing) → le rapport se remplit en minutes.
- **Version history** : revenir en arrière si un copier-coller écrase une section.
- **Vérifier avant Publish** : TOC, numérotation, images, sauts de page.
- **Sauvegarder l'archive .tar.gz** à la fin de chaque journée d'exam.

---

## 10. Dépannage

| Problème | Solution |
|---|---|
| PDF vide / design cassé | vérifier le design sélectionné dans *Project Design* |
| Images manquantes | uploader via le champ, ne pas référencer un chemin local |
| `SECRET_KEY` invalide | régénérer dans `app.env` puis `docker compose up -d` |
| 502 derrière proxy | `ALLOWED_HOSTS` + `CSRF_TRUSTED_ORIGINS` |
| Import nmap échoue | XML complet (`-oX`), pas la sortie texte |
| Mot de passe perdu | `manage.py changepassword <user>` |

```bash
# Logs
docker compose logs -f app
docker compose exec app python3 manage.py check
```
