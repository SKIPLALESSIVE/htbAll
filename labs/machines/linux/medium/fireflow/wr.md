on vient enumérer le mcp. 
trouver une cve, rce et user flag 

privesc : 
avec le user qu'on a eu, on cherche a se latérialiser
y'a un truc accessible avec un config.json dans le home, on se connecte au serveur 
on va forger le JWT ensuite pour privesc

une fois qu'on s'est lateralisé dans le conteneur k3s, on va énumérer l'api, voir le droit node/proxy, utilise pour privesc 
en gros on va se servir de la permission pour ouvrir un websocket, se connecter au node privilégié, et ensuite lister tout le host et donc le /root/root.txt