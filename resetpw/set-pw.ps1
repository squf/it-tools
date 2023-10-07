# .ABOUT
# use this after running get-pw.ps1
# build a .csv called pws.csv using that tool to generate long lists of random strings
# this script will pull in the .csv and set everyones passwords to the random string

Import-Module ActiveDirectory 

Import-Csv pws.csv -Delimiter "," | Foreach {
$NewPass = ConvertTo-SecureString -AsPlainText $_.NewPassword -Force
Set-ADAccountPassword -Identity $_.sAMAccountName -NewPassword $NewPass -Reset -PassThru | Set-ADUser -ChangePasswordAtLogon $false
}
