# Configuring automated Intune Assignments reporting

* Using - [ugurkocde/IntuneAssignmentChecker: This script enables IT administrators to analyze and audit Intune assignments. It checks assignments for specific users, groups, or devices, displays all policies and their assignments, identifies unassigned policies and detects empty groups in assignments.](https://github.com/ugurkocde/IntuneAssignmentChecker?tab=readme-ov-file#-usage) - Ugur is a brilliant Microsoft MVP who makes tons of great scripts for Intune / Azure, check him out! He also has a separate website at [Intune Automation](https://intuneautomation.com) with a large library of very useful tools. My GitHub repo for IT tools is sad and weak in comparison :'( 

* I'm wanting to set this up on the Internal Reporting Server I set-up previously at my current company to run as part of a scheduled task, I also would like to set this up as an Azure Runbook instead, but since we already have an Azure VM set-up to run e-mail reports I'll just use that in this instance.

* This is easier for me to do as well, since what I want to do is have Ugur's script generate the .html report for me, and then a separate script will e-mail it off to our Systems team for review on a scheduled basis. I am sure I could achieve that same logic in an Azure Runbook either directly or through blob storage, but I'm not quite skilled enough yet for that. So since we have the infra in-place for this already that I set-up before, and since I'm more familiar with it and understand how I will get this working that way, I will go that way.

* Now, if you look at Ugur's GitHub repo for this, you'll see there are Authentication and Usage sections which I'll be setting up here. I downloaded the source code .zip file to my Internal Reporting Server and saved it into a directory right at the root of C:\ where it will live.

* I edited the `IntuneAssignmentChecker_v3.ps1` file, specifically this section:

```
# Fill in your App ID, Tenant ID, and Certificate Thumbprint
# Use parameter values if provided, otherwise use defaults
$appid = if ($AppId) { $AppId } else { '<YourAppIdHere>' } # App ID of the App Registration
$tenantid = if ($TenantId) { $TenantId } else { '<YourTenantIdHere>' } # Tenant ID of your EntraID
$certThumbprint = if ($CertificateThumbprint) { $CertificateThumbprint } else { '<YourCertificateThumbprintHere>' } # Thumbprint of the certificate associated with the App Registration
# $certName = '<YourCertificateNameHere>' # Name of the certificate associated with the App Registration
```

* I did not register a new app for this, I am re-using the same one we're using for the rest of our e-mail reports, however it is missing some permissions:
 
 ![image](https://github.com/user-attachments/assets/0d8703d4-3380-4acf-9b52-06e41db5db68)

* I went to the App Registration and added the missing permissions then granted admin consent to them. These are Graph Application Permissions, not Delegated.

* Now it appears to be running fine

  ![image](https://github.com/user-attachments/assets/0b1cabca-c3a3-450d-b95f-f81b783d8575)

* So based on that, now all I should need to do is run: `.\IntuneAssignmentChecker_v3.ps1 -GenerateHTMLReport` this parameter that Ugur built into the script should allow me to run this in an automated fashion (so I can add this to a scheduled task later)

* I wanted to make the report go to a different directory, this script outputs it to: `$filePath = Join-Path (Get-Location) "IntuneAssignmentReport.html"` so the same directory as the script itself. We have a specific directory we store all our generated reports in on this server, so I changed that line in the script to point there instead -> `$filePath = "C:\Reports\IntuneAssignmentReport.html"` - just static assignment for this $filePath variable, simple enough.

* I know already that this script only works in PWSH7 and not the 5.1 IDE on the server, but luckily I also have PWSH7 and Windows Terminal set-up there for just such an occassion. I just ran the script from there as-is after making my edits, with `.\IntuneAssignmentChecker_v3.ps1 -GenerateHTMLReport`

* It did run successfully as expected, but the terminal window is hanging open with this check:

  ![image](https://github.com/user-attachments/assets/01639737-4bb5-4f04-955b-6cec748be9fb)

* This is from these lines in the script: 

```
# Ask if user wants to open the report
$openReport = Read-Host "Would you like to open the report now? (y/n)"
	if ($openReport -eq 'y') {
	Start-Process $filePath
}
```

* For a simple fix, I tried just commenting all of these lines out and re-running the script. 

* This worked and the terminal doesn't just hang open waiting for input any longer, this also served as a test for whether this script is Append or Overwrite - i.e., if I just leave it running automatically will it overwrite the existing .html file or just clobber it all together, how does it handle that? 

* Good news is that it overwrites the file, so I can safely leave this running automatically in the background for awhile

* Now all that's left is the following:
	* Set-up a scheduled task to run this script with the `-GenerateHTMLReport` parameter, let's say at 5:00 AM biweekly
	* Set-up a separate script which will grab this .html file, attach it and send it as an e-mail to our Systems team for review, run this on a scheduled task let's say 6:00 AM biweekly
	* This should give the first script plenty of time to run through and grab a fresh copy to send off, and the email should arrive to our shared inbox before any of us gets to work in the morning

* I have already several other scripts which will do the "grab this file, attach it, send as email" on the server, but unfortunately I can't share them here on GitHub because they include sensitive data for our environment, but basically long story short they are also using the AppID authentication information, an Azure Key Vault to pass SMTP values, and the deprecated `Send-MailMessage` cmdlet because I haven't figured out a way yet to use any different cmdlets for sending SMTP.

* I set-up a specific one called `send-mail.ps1` and stored it in the same directory the AssignmentChecker script lives in, then I tested this via terminal and verified I received the e-mail with the .html file attached as expected

* **Common Scheduled Task gotchas:**
	* General: "Run whether user is logged on or not"
	* Actions:
	  Start a program - `"C:\Program Files\PowerShell\7\pwsh.exe"`
	  Add arguments - `-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Reports\IntuneAssignmentChecker-3.3.4\IntuneAssignmentChecker_v3.ps1" -GenerateHTMLReport`
	* Conditions: Wake the computer to run this task checked, all else unchecked
	* Settings (check all these on, don't check anything else on): 
	  Allow task to be run on demand
	  Stop the task if it runs longer than 3 days
	  If the running task does not end when requested, force it to stop
	  If task is already running, then the following rule applies: Do not start a new instance

* I set-up the AssignmentChecker scheduled task first and ran it, then verified it did produce a brand new .html file for me in the directory I expect correctly.

* With the scheduled task in place for that, and the testing done, I set-up the second script to send the email and made sure its scheduled to run about 1 hour after the first script -- to ensure the AssignmentChecker has plenty of time to run successfully and generate the .html file the e-mail requires.

* Both scheduled tasks are working as expected, so now all that's left to do is wait until the next time they run automatically 2 weeks from now and check our reports.

And that's all folks!
