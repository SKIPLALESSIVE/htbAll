en gros c'est "simple"
on dump le fichier headump de l'api, ensuite on trouve des creds qui permettent de se connecter au clickhouse, avec lequel on peut lire les req envoyer a l'autre endpoint, qui donnent une sorte d'IDOR. 
avec ces creds, on va énumérer la base, et trouver dans le fichier kafka une façon de se connecter en ssh avec des creds
mais on est tjr pas sur le flag user ( smr la pute)
ensuite en énumérant la machine on tombe sur un svc qui fait tourner un script vulnérable
en gros on vient trigger une erreur dans kaftka, pendant ce temps on vient écouter dans journalctl ce qu'il se passe et on récupère mdp / password de la db 
on fait cela à l'aide du script snoop.sh : 
- vient regarder /proc, les pids etc jusqu'à voir un clickhouse-client et --password pcq c'est comme ça que le process est appelé. 
- on récupère les creds root clickhouse comme ça 

pour trigger le processus clickhouse, on se sert de trigger.sh qui vient en gros créer une req malformée qui vient trigger le DLG et fait restart le process en gros

on récupère donc un accès root sur clickhouse
avec cet accès root, on va venir écraser le fichier qui fait le formatage