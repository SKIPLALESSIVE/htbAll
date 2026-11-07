tout se base sur une sorte d'idor un peu bizarre : 

- on se login et on fait le tour de l'appli 
en gros le but est de récupérer l'historique de transaction d'un autre user 

- on énumère le js, on trouve des routes API dedans en V1 
on énumère l'api en v1,  et on finit d'énumérer le site. 
y'a un endroit ou en v2 on peut récupére les id de tout le monde 
ensuite on vient dans le truc de download history fetch avec cet _id en v1. 
on voit qu'il y a un aautre user qui s'appelle user_flag !
ensuite on va récupérer son id en faisant une fake transaction, on récupère son id et on refait la manip pour avoir le flag dans l'historique. 

