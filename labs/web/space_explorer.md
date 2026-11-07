Go :  action  et  ACTION  = une seule et même clé

Le tag de struct est  json:"action" , et  encoding/json  fait un matching insensible à la casse. Donc pour Go, ces deux entrées désignent le même champ  Action  et s'écrasent mutuellement → seule la dernière est conservée :

┌─────────────────────────────────────────────────┬───────────────────────────────┐
│ Entrée                                          │ Go garde (Action)             │
├─────────────────────────────────────────────────┼───────────────────────────────┤
│ {"action":"getSecureCode","ACTION":"getcosmic"} │ getcosmic (dernier gagne)     │
│ {"ACTION":"getcosmic","action":"getSecureCode"} │ getSecureCode (dernier gagne) │
└─────────────────────────────────────────────────┴───────────────────────────────┘

Python :  action  et  ACTION  = deux clés distinctes

 json.loads  est sensible à la casse. Il garde les deux dans le dict, et  data['action']  ne lit que la minuscule :

┌─────────────────────────────────────────────────┬─────────────────────────────────────────────────┬────────────────┐
│ Entrée                                          │ dict Python                                     │ data['action'] │
├─────────────────────────────────────────────────┼─────────────────────────────────────────────────┼────────────────┤
│ {"action":"getSecureCode","ACTION":"getcosmic"} │ {'action':'getSecureCode','ACTION':'getcosmic'} │ getSecureCode  │
│ {"ACTION":"getcosmic","action":"getSecureCode"} │ {'ACTION':'getcosmic','action':'getSecureCode'} │ getSecureCode  │
└─────────────────────────────────────────────────┴─────────────────────────────────────────────────┴────────────────┘

Ce que ça implique

Ce n'est donc pas « la clé d'en dessous gagne » — c'est une collision de clés où :
- Go voit 1 clé (dédupliquée, la dernière),
- Python en voit 2 (et pioche celle qu'il veut).

L'astuce c'est d'exploiter ces deux règles opposées en même temps :
1. Go doit valider l'action légitime  getcosmic  → comme Go prend la dernière,  getcosmic  doit être en dernier (sous  ACTION ).
2. Python doit lire  getSecureCode  → il lit toujours la clé minuscule exacte  action , donc on y met  getSecureCode .

D'où  {"action":"getSecureCode","ACTION":"getcosmic"}  : Go route vers le proxy (il croit à une simple requête cosmique) et relaie le corps brut ; Python le reçoit, lit sa clé minuscule, et sert le flag. Une seule valeur logique pour Go, deux pour Python → deux composants qui prennent deux décisions différentes sur la même requête.

Si tu inverses l'ordre, c'est Go qui tombe sur  getSecureCode  et renvoie  Access denied  — d'où l'importance de l'ordre, qui n'existe que parce que Go déduplique.
