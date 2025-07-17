# Absolute nightmare

* So this is another one of those funny things you would only ever have to do in a HAADJ environment. I am assuming you have **Windows Terminal** and **PWSH7** installed for all of this.
* Everything in here is for a very specific task of migrating a user's [Home Directory](https://learn.microsoft.com/en-us/windows/win32/adschema/a-homedirectory) from on-prem server to that user's OneDrive folder.
* This script will prompt you for a username, it will search everything in the data server UNC path (you have to specify this in the ODHF script) for a matching username value, it will construct their OneDrive URL using that same value, and then it will copy their entire Home Directory from OnPrem to "OneDrive...\Home Folder" for them. So everything gets neatly moved over to OneDrive in one parent folder and doesn't clutter up their entire OneDrive. That's what this entire repo is for.

* **My honest recommendation is to just purchase ShareGate if you can convince your mgmt to budget for this tool instead, but, this repo is free to use and worked as of July 2025 in my environment at least!**
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
* I use Marcel's custom cmdlets from his module wherever possible, but in some cases I had to just construct and pass my own Graph API calls directly, like for setting the UploadURL and passing an `Invoke-RestMethod` call, this is in an `else` switch as a fallback in case his fails
* This is because I was running into issues just trying to pass the direct OneDrive URL, so I switched over to using the Graph API and site ID / drive ID paths, which get gathered in my script and passed into later things. don't worry about it

**I spent about 2 afternoons troubleshooting all this to get it working**

* As I am writing this readme, I am uploading all of my one test user's home folder contents to their OneDrive but I don't think its fully successful yet, I am not sure its actually recursively adding files to subfolders correctly at this time (lol!!!!)
* I will be updating `ODHF.ps1` as a result if I continue tweaking it or getting it working better, so since nobody ever reads anything on my GitHub anyway I wouldn't worry about it too much. I will specify in the .ps1 file whether it's been updated to handle these cases or not later.
* **Later update:** i did actually get a better version of this script working now that I'm pretty happy with, updated `ODHF.ps1` file with the new version already
* I will probably need to work on an entirely different script to handle provisioning user OneDrive's, which I already know has about a 24-hour lead time on it (i.e., I'll provision them all on Monday and then come back and do the file transfer on like Wednesday or smth) -- I'll add this script later as/when needed.

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

* TBH I probably don't need any of these delegated ones, but whatever, its working and i'm tired of testing

# Scripts readme

**ODHF.ps1**
* This is the primary script which actually does the checking of parent and child directories, and begins copying the files over
* You need to run `get-token.ps1` before running this, which stores the `access_token` you need to connect your app to Graph API into the `$Auth` variable in your shell.
* So this script needs to be run after running that script and you need to stay in the same shell context the entire time this script is running.
* Includes logging to a .txt file at -> `C:\tmp\ODHF_Logs` and the log itself is also named after the username value you provide. This makes tracking the file uploads ezpz because each log will be uniquely named and match the user in question, which is pretty neat. This log is appended to so it will track re-runs of the script etc. gracefully.
* It also now handles HTTP 429 (API throttling) errors gracefully
* Handles large item uploads with batching (4 MB+)
* Fixed an issue with empty child / nested folders, now this script is pretty robust and can be stopped and re-run whenever without creating tons of empty nested folders, now it will just skip files if they exist and otherwise put everything into the "Home Folder" that gets created the first time the script is run
* I've also tested having multiple people run this script simultaneously and it ran without issue, though I can't say what will happen if you max out your API calls. There is API throttle handling in the script but it might not work perfectly, give it a cooldown before trying again I suppose.

**get-token.ps1**
* As mentioned above, this just grabs a 1 hour access token for you to use with the primary script and stores it in $Auth variable
* You can run this script and then immediately run `$Auth` in your shell after to verify its working

**get-authaud.ps1**
* This was a troubleshooting script I made to verify my roles and scopes and suchlike for the token, hopefully you don't have to get this deep into the weeds like I did
* If you find yourself running this script you should probably just immediately go to your mgmt and beg for ShareGate at this point tbh

**check-od.ps1**
* just a small helper file I came up with to check the contents of a specified user's OneDrive\Home Folder -- just for a final verification if you want to run it, to ensure the files got copied over
* in initial testing I'm just doing all of this to my own OneDrive folder so its no big deal I can just look at my own OneDrive whenever in many places, but, it might be more of a pain to check other people's OneDrive's later when I start migrating all of them
