Import-Module ActiveDirectory 

Import-Csv -Path “C:\scripts\AddADUserToGroup\Users-To-Add.csv” | ForEach-Object {Add-ADGroupMember -Identity “Management-11720187724” -Members $_.’User-Name’}