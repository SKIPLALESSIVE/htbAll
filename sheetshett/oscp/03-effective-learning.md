# 03 — Effective Learning Strategies

## Objectifs
Méthode de progression : pratiquer dans l'incertitude, documenter ses échecs, réviser par rappel actif. Module « soft », mais c'est ce qui fait la différence sur 24 h d'examen.

---

## 1. Le principe OffSec : « Try Harder » ≠ s'acharner

| S'acharner | Persévérer utilement |
|---|---|
| Répéter la même commande | varier l'angle (autre port, autre vhost, autre user) |
| Rester 4 h sur une piste | timebox 90 min puis rotation |
| Chercher la solution | chercher **ce qui bloque** (log, erreur, version) |
| Lire des writeups | refaire sans regarder |

---

## 2. Boucle d'apprentissage

```
1. Tenter seul (30–60 min)
2. Identifier le point de blocage précis
3. Consulter UNE source (manuel, writeup)
4. Fermer la source et refaire de mémoire
5. Écrire une fiche de 10 lignes (ce que j'ai appris)
6. Refaire la machine 1 semaine plus tard, sans aide
```

L'étape 4 est celle qui compte : **reproduire sans la source**.

---

## 3. Rappel actif (active recall)

- Ne pas relire les fiches : **les reconstruire** sur papier blanc.
- Se poser des questions fermées :
  - « Quelle commande pour trouver les SUID ? »
  - « Quels privilèges Windows donnent SYSTEM ? »
  - « Comment relayer NTLM vers SMB sans Responder ? »
- Espacement : J+1, J+3, J+7, J+21.

### Exercice type (10 min/jour)
Écrire de mémoire, sans regarder :
```bash
# 1. scan complet
# 2. ffuf répertoires
# 3. reverse shell bash
# 4. SUID root
# 5. Kerberoast
# 6. DCSync
```
Puis comparer à la fiche. L'écart = la révision du jour.

---

## 4. Journal d'échecs

```
2026-03-04 — Machine X
Piste : Tomcat manager
Blocage : creds par défaut refusées, pas de rôle manager
Ce que j'ai raté : je n'ai pas vérifié /manager/html/../host-manager ni les vhosts
Leçon : toujours fuzzer les vhosts quand un service « standard » résiste
```

Après 20 entrées, les schémas apparaissent : ce sont **tes** angles morts, et c'est ce qu'il faut réviser la veille de l'examen.

---

## 5. Pratique délibérée

- Choisir **une** compétence par session (ex. « SQLi manuelle UNION »), pas « faire une machine ».
- Difficulté croissante : lab guidé → challenge → machine retirée → set AD.
- Contrainte volontaire : refaire une machine **sans Metasploit**, **sans autorecon**, **sans internet**.

### Contraintes utiles pour l'examen
| Contrainte | Pourquoi |
|---|---|
| Pas d'autorecon | tu dois savoir quoi lancer |
| Pas de Metasploit | 1 seule machine autorisée |
| Pas de searchsploit | savoir lire un PoC |
| Notes en markdown | rapport en 24 h |
| Timebox 90 min | réflexe de rotation |

---

## 6. Gestion de la charge

- 2 h de pratique > 6 h de vidéos.
- Une machine **finie** (user + root + notes) vaut mieux que trois à moitié.
- Dormir : la mémoire procédurale (réflexes CLI) se consolide au sommeil.
- Éviter les writeups le jour où tu attaques une machine : l'illusion de compétence est le piège principal.

---

## 7. Checklist de préparation

- [ ] 30+ machines rootées avec notes
- [ ] 2 sets AD complets
- [ ] 5 exploits publics modifiés avec succès
- [ ] 10 privesc Windows + 10 Linux, sans outil automatique d'abord
- [ ] 3 pivots multi-niveaux
- [ ] 2 rapports complets rédigés en < 4 h
- [ ] Journal d'échecs relu
- [ ] Fiches reconstruites de mémoire sans erreur
