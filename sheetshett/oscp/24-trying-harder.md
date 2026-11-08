# 24 — Trying Harder: The Labs

## Objectifs
Transformer la pratique en score : stratégie de labs, gestion du temps d'examen, et comportement face au blocage.

---

## 1. Progression de labs

| Étape | Objectif | Volume |
|---|---|---|
| 1 | Machines « faciles » guidées | 10 |
| 2 | Machines sans writeup, 1 indice max | 15 |
| 3 | Machines retirées (type examen) | 10 |
| 4 | Sets AD complets | 2–3 |
| 5 | Examens blancs 24 h | 2 |

À chaque machine : **user + root + notes**, sinon elle ne compte pas.

```bash
# Suivi
machine | ports | user | root | temps | méthode privesc | refait ?
```

---

## 2. Gestion du temps d'examen (23 h 45)

### Répartition conseillée
| Bloc | Durée | Cibles |
|---|---|---|
| Scan + tri | 1 h | toutes |
| AD set (3 machines) | 8–10 h | priorité (26 %) |
| Standalone 1 | 3 h | la plus « facile » |
| Standalone 2 | 3 h | |
| Standalone 3 | 3 h | |
| Rapport | 3–4 h | **avant la fin** |
| Marge | 2 h | imprévus |

> Ne jamais finir à 23 h 44. Prévoir 3 h de rapport **dans** les 24 h, pas après.

### Règle de rotation
```
90 min sans progrès → changer de cible
Après 2 rotations → revenir avec une checklist « ce que je n'ai pas testé »
```

Checklist de reprise :
- [ ] Tous les ports scannés (UDP inclus)
- [ ] Tous les vhosts
- [ ] Toutes les creds testées partout
- [ ] Tous les paramètres web testés
- [ ] Les deux chemins de privesc possibles

---

## 3. Mécanique du blocage

```markdown
## Blocage : 10.10.10.20
Ce que j'ai tenté :
- nmap -p- → 22,80,8080
- ffuf dirs → /admin, /api
- sqlmap sur /api/item?id= → rien
- creds admin:admin → refusé

Ce que je n'ai PAS testé :
- /api/v1 (versioning)
- Host header sur 8080
- paramètre "debug" ou "test"
- HTTP/1.0, méthodes PUT/DELETE

Prochaine piste :
- fuzzer les vhosts
- vérifier si /admin accepte POST
```

Écrire noir sur blanc casse le biais de confirmation.

---

## 4. Points partiels

| Situation | Points |
|---|---|
| shell user non privilégié | partiel |
| accès admin mais pas de proof | souvent 0 |
| proof mais pas de méthode | partiel |
| AD : accès à une machine du set | partiel |
| DA obtenu | maximal |

Toujours **prouver** :
```bash
hostname; whoami; id; cat /root/proof.txt
```
```cmd
hostname & whoami & type C:\Users\Administrator\Desktop\proof.txt
```

---

## 5. Ce qui fait gagner les derniers points

1. **Relire ses notes** : souvent la réponse y est déjà (un cred trouvé 3 h plus tôt).
2. **Réutiliser les creds** partout, y compris en local admin (`--local-auth`).
3. **Tester les chemins « moches »** : `/backup`, `/old`, `.git`, `.env`, `?debug=1`.
4. **Vérifier les privesc évidents** qu'on a sautés : `sudo -l`, `whoami /priv`, services.
5. **AD** : ne pas oublier `--shares`, `--sessions`, SYSVOL, GPP.
6. **Rapport** : un finding précis = des points même sans shell.

---

## 6. Après l'examen

- Rapport rendu dans les 24 h → confirmation.
- Garder les notes : elles constituent un portfolio (anonymisé).
- Refaire les machines ratées pour comprendre.
- Ne jamais publier de contenu d'examen (NDA OffSec).

---

## 7. Checklist finale

- [ ] 40+ machines avec notes
- [ ] 3 sets AD
- [ ] 2 examens blancs chronométrés
- [ ] Rapport rédigé en < 4 h, deux fois
- [ ] Tableau de suivi prêt
- [ ] Binaires et wordlists hors ligne
- [ ] Quota MSF compris et respecté
- [ ] Aucune IA ouverte
- [ ] Alarme réglée pour le rendu du rapport
