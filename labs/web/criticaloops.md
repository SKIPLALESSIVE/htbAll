en faisant l'enum on voit une API, un site de tickets classiques etc...
tentative d'envoyer un ticket, sans grande réussite. 


Dans les faits du coup c'est une forge de token JWT 
 - la logique de création de tokens avec la clé se fait client side au lieu de se faire server side
 - du coup y'a la clé en clair dans le js 
 - avec la clé on forge un nouveau token JWT 
 - on s'authentifie et on récupère le flag 