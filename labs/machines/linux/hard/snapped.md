pour le user de base : 
on énumère les sous domaines, on trouve un sd nommé admin, qui renvoit vers admin.snapped.htb 
on se rend compte qu'il est sur un nging ui, qui est vulnérable a une cve a la con 
ensuite on extrait le code source avec l'exploit de cette CVE, et on trouve une base de donnée 
Dans cette base de données on trouve un hash, qui correspond au user jonathan 
on peut ensuite se connecter en ssh sur l'ip et passer à la privesc 
mdp linkinpark
pour la privesc c'est une privesc avec un abuse de snapd qui a une CVE et qui permet de passer root 