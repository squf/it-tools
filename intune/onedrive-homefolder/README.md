# Absolute nightmare

* So this is another one of those funny things you would only ever have to do in a HAADJ environment. I am assuming you have **Windows Terminal** and **PWSH7** installed for all of this.
* **My honest recommendation is to just purchase ShareGate if you can convince your mgmt to just buy ShareGate. Do whatever you can to purchase ShareGate if you need to accomplish this same task somewhere else. Their tooling probably does this directly via GUI IDK, but even if not, their Powershell module will work way better than this hacky slapped together piece of junk I came up with.**
* Users have mapped Home Folders in AD, which are stored on a data hosting server on-prem, this gets mapped in their *AD attribute > Profile > Home folder > Connect (Drive Letter) To: (UNC path to data server)*
* We want to migrate all of these users Home folder data over to their OneDrive, but not all OneDrives have been provisioned yet (which can be accomplished by signing in as the user on the OneDrive website)
* I found [this OneDrive powershell module](https://github.com/MarcelMeurer/PowerShellGallery-OneDrive) but it hasn't been updated in 3 years, but it is free / open to use
* I also found -> [ShareGate's Powershell module](https://help.sharegate.com/en/articles/10236381-migrate-onedrive-for-business-to-onedrive-for-business-with-powershell) - which I assume works much better but we'd have to purchase ShareGate first

# Things to consider

* Marcel's script uses delegated permissions and the documentation keeps referencing Azure Active Directory (because it hasn't been updated in 3 years)
* You **will need to register an Entra App for this, and generate a secret key -- copy this secret key out to a notepad file somewhere else for future reference -- you can't view the secret key again after you generate it the first time just a disclaimer**
* I kind of hinted at it above but never actually stated it, yes you need to install Marcel's OneDrive module as well: `Install-Module -Name OneDrive`
* When I look through the `.psd1` and `.psm1` source files it is all in Deutsch so I can't read it at all, I could run it through an LLM but whatever
* The way this script is supposed to function is that it fetches an access-token via Graph API and stashes it in the `$Auth` variable, so you can use it in other scripts
* The limitations with this are that the access token only lasts for 1 hour and you have to do it all within the same shell, if you open a new tab or go to a different shell then you won't have the token anymore (which you can check at any time by just typing `$Auth` in shell and seeing if the variable returns anything)
* So this is already not very ideal, I would much prefer we just use CertThumbprint authentication or something -- something which doesn't expire after 1 hour, and something that is not using delegated permissions

**I spent about 2 afternoons troubleshooting all this to get it working**

* As I am writing this readme, I am uploading all of my one test user's home folder contents to their OneDrive but I don't think its fully successful yet, I am not sure its actually recursively adding files to subfolders correctly at this time
* I'd like to adjust my current script for this to include recursion and also skipping files completely if they already exist in the target destination to try and save time, since I'm capped at this 1 hour token access I'll probably need to run this same script multiple times to get everything moved over
* Also, really ideally, I'd rather we just purchase ShareGate and use their Powershell module for this because it is backed by an entire company and is much more up-to-date, so I am much more confident their solution works better, but that's another story

# Registered app setup

* I kept running into tons of issues with my app permissions, so eventually, I just gave it everything it could possibly need and stopped worrying about least-privilege model. Somebody smarter than me could figure this out but whatever.
* I registered my app and made sure to copy its `Secret Key` off somewhere safe for use in my scripts (you can't view this again after you leave the page the first time you generate it fyi)
* I gave the app:
* **Microsoft Graph Application Permissions:**
* Files.ReadWrite.All
* Sites.Manage.All
* Sites.ReadWrite.All
* User.Read (Default) (Delegated)
* User.Read.All
* **SharePoint Application Permissions:**
* MyFiles.Read (Delegated)
* MyFiles.Write (Delegated)
* Sites.FullControl.All
* Sites.Manage.All
* Sites.ReadWrite.All
* Sites.Selected (Delegated)
* User.Read.All
* User.ReadWrite.All

* I also gave my standard user account the **SharePoint Administrator** role just because after like 8 hours of staring at VS Code and all this my brain started to hurt and I couldn't keep track of what was being passed via delegated access or application access
* TBH I probably don't need any of these delegated ones and don't need this role, but whatever
* When I'm done with all this I will take away this role from my user

# Scripts readme

**ODHF.ps1**
* run `get-token.ps1` first to grab token

* This is the primary script which actually does the checking of parent and child directories, and begins copying the files over
* You need to run `get-token.ps1` before running this, this gives you 1 hour of token access, so if you don't finish the full Home folder transfer in that time glhf!!!! run them both again!!!!
* I hate this script, hate HAADJ, hate not having ShareGate. Simple as!

**get-token.ps1**
* As mentioned above, this just grabs a 1 hour access token for you to use with the primary script and stores it in $Auth variable
* You can run this script and then immediately run `$Auth` in your shell after to verify its working

**get-authaud.ps1**
* This was a troubleshooting script I made to verify my roles and scopes and suchlike for the token, hopefully you don't have to get this deep into the weeds like I did
* If you find yourself running this script you should probably just immediately go to your mgmt and beg for ShareGate at this point tbh
