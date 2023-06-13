# .ABOUT
# use this after running GenerateRandomPassword.ps1
# build a .csv called RandomizedReset.csv
# delimiter is -- ; 
# example:
# samaccountname;randompassword
# this script will pull in the .csv and set everyones passwords to the random string
# print out a copy of the .csv to have the passwords handy as needed, dispose of in shredbox when done

Import-Module ActiveDirectory 

Import-Csv RandomizedReset.csv -Delimiter ";" | Foreach {
$NewPass = ConvertTo-SecureString -AsPlainText $_.NewPassword -Force
Set-ADAccountPassword -Identity $_.sAMAccountName -NewPassword $NewPass -Reset -PassThru | Set-ADUser -ChangePasswordAtLogon $false
}