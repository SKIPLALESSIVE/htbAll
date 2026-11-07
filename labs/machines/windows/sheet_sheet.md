Pour un user, les checks classiques sont :
- Kerberoast → le compte a un servicePrincipalName
- AS-REP Roast → DONT_REQ_PREAUTH est activé dans userAccountControl
- Password reset / takeover → tu as ForceChangePassword, GenericAll, GenericWrite ou certains droits ACL sur lui
- Shadow Credentials → tu peux écrire msDS-KeyCredentialLink
- RBCD → tu peux écrire msDS-AllowedToActOnBehalfOfOtherIdentity sur une machine cible
- AddMember → tu peux ajouter quelqu’un à un groupe intéressant
- WriteDACL / WriteOwner → tu peux souvent te donner ensuite des droits plus puissants
- BadSuccessor / dMSA → droits de création d’objet dans une OU + conditions spécifiques sur le dMSA / target selon patch
