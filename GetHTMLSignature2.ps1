#import the active directory module which is needed for Get-ADUser
import-module activedirectory
#set folder location for files, the folder must already exist
$save_location = '\\172.26.215.62\sigs'
$users = Get-ADUser -filter * -searchbase "OU=Millerpipeline,OU=artera.com,DC=corp,DC=artera,DC=com" -Properties * -Credential corp\daniel.quakenbush-ad -server corp.artera.com

function FormatPhoneNumber($phoneNumber) {
  if ([string]::IsNullOrEmpty($phoneNumber)) {
    return ""
  }

  $formattedNumber = $phoneNumber -replace "[^\d]" # Remove non-numeric characters
  $formattedNumber = $formattedNumber.Insert(3, ".")
  $formattedNumber = $formattedNumber.Insert(7, ".")

  return $formattedNumber
}

foreach ($user in $users) {
  $full_name = "$($user.GivenName) $($user.Surname)"
  $job_title = "$($user.title)"
  $account_name = "$($user.sAMAccountName)"
  $telephone = FormatPhoneNumber "$($user.TelephoneNumber)"
  $mobilephone = FormatPhoneNumber "$($user.MobilePhone)"
  $email = "$($user.emailaddress)"
  $logo = "https://www.millerpipeline.com/email-company-logo.png"
  $first_name = $user.GivenName
  $last_name = $user.Surname
  $output_file = $save_location + "$account_name.htm"

  Write-Host "Now attempting to create signature HTML file for" $full_name

  $signatureContent = @"
<br><br><span style="font-family: arial, sans-serif; font-size: 12px;"><strong>$full_name</strong><br />
$job_title<br />
O $telephone `| C $mobilephone<br />
<a href="mailto:$email">$email</a><br />
</span><br />
<img alt="Miller Pipeline" border="0" height="109" src="$logo" width="100" />
"@

  $signatureContent | Out-File $output_file
}
