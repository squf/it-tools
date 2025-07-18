# Absolute nightmare

* So this is another one of those funny things you would only ever have to do in a HAADJ environment. I am assuming you have **Windows Terminal** and **PWSH7** installed for all of this.
* Everything in here is for a very specific task of migrating a user's [Home Directory](https://learn.microsoft.com/en-us/windows/win32/adschema/a-homedirectory) from on-prem server to that user's OneDrive folder.
* This script will prompt you for a username, it will search everything in the data server UNC path (you have to specify this in the ODHF script) for a matching username value, it will construct their OneDrive URL using that same value, and then it will copy their entire Home Directory from OnPrem to "OneDrive...\Home Folder" for them. So everything gets neatly moved over to OneDrive in one parent folder and doesn't clutter up their entire OneDrive. That's what everything in this folder is for.

* **My honest recommendation is to just purchase ShareGate if you can convince your mgmt to budget for this tool instead, but, this repo is free to use and worked as of July 2025 in my environment at least!**
* [ShareGate article on doing this same exact thing but using their tool and avoiding all hassles](https://help.sharegate.com/en/articles/10236383-import-from-file-share-to-onedrive-for-business-with-powershell)

* I found [this OneDrive powershell module](https://github.com/MarcelMeurer/PowerShellGallery-OneDrive) but it hasn't been updated in 3 years, but it is free / open to use, this is also required install because the scripts here rely on some pieces of it / some direct graph api calls (its a mix!)

# Things to consider

* You **will need to register an Entra App for this, and generate a secret key -- copy this secret key before leaving the page when you generate it -- you can't view the secret key again after you generate it the first time just a disclaimer**
* install Marcel's OneDrive module as well: `Install-Module -Name OneDrive`
* The way this script is supposed to function is that it fetches an access-token via Graph API and stashes it in the `$Auth` variable, so you can use it in other scripts so long as you stay in that authenticated shell context (which you can check at any time by just typing `$Auth` in shell and seeing if the variable returns anything)

**I spent about 3 afternoons troubleshooting all this to get it working**

* requires [pre-provisioning user OneDrive](https://learn.microsoft.com/en-us/sharepoint/pre-provision-accounts)
* If you're getting [HTTP 401 errors](https://learn.microsoft.com/en-us/troubleshoot/sharepoint/lists-and-libraries/401-error-when-using-graph-api-to-access-data) using any of this, check if you have a geolocation conditional access policy and exclude yourself from it if so. I ran into this running this script and after excluding myself it was fine.
* Eventually, I actually hit the [Graph API throttle limits](https://learn.microsoft.com/en-us/graph/throttling-limits) / [SharePoint & OneDrive limits](https://learn.microsoft.com/en-us/sharepoint/dev/general-development/how-to-avoid-getting-throttled-or-blocked-in-sharepoint-online) while running these scripts so often. To try and get around this since its per app per tenant, I registered a second app and made a copy of `get-token.ps1` -> `get-token2.ps1` - and just changed the ClientID and ClientSecret values in that version of the script. This doubles my cap at least, so I have double the amount of API call space, but there's no easy way around these API throttle limits.
* I was curious about setting up [Data Connect](https://learn.microsoft.com/en-us/graph/data-connect-concept-overview) to avoid all API limits, but I'm not even sure if that would work. I mean it certainly wouldn't with the scripts located here as they are still going to make API calls as-is, but like, maybe you could pull all your SharePoint data into Azure / MGDC and then pass info there? Don't know how that all works, that's a complete architecture shift away from what I'm doing here.
* instead I ended up just changing a lot of the script logic i.e., initially i was sending an API call to check every single file / now it just sends 1 API call to gather all files and compares against that (to avoid overwriting / duplicating data), it was sending 1 API call per folder to create it, now it batches 20 folders into 1 API Call and then recursively fills those folders up with their data later, etc., I'm not sure exactly how much all this batching logic has reduced the API usage in pure numbers but its a massive reduction over the initial script versions i came up with so hopefully you'll never hit a 429 error using this as-is

# Registered app setup

* I kept running into tons of issues with my app permissions, so eventually, I just gave it everything it could possibly need and stopped worrying about least-privilege model
* I registered my app and made sure to copy its `Secret Key` into my actual `get-token.ps1` script (you can't view this again after you leave the page the first time you generate it fyi)
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

* TBH I probably don't need any of these delegated ones, but whatever, its working and i'm tired and sleepy 😴

# Scripts readme

**ODHF.ps1**
* This is the primary script which actually does the checking of parent and child directories, and copies the files over to OneDrive. it stands for OneDriveHomeFolder btw.
* You need to run `get-token.ps1` before running this, which stores the `access_token` you need for authentication into the `$Auth` variable in your shell.
* So this script needs to be run **after** running that script and you need to stay in the same shell context the entire time this script is running.
* Includes logging to a .txt file at -> `C:\tmp\ODHF_Logs` and the log itself is also named after the username value you provide. This makes tracking the file uploads ezpz because each log will be uniquely named and match the user in question, which is pretty neat. This log is appended to so it will track re-runs of the script etc. gracefully.
* It also now handles HTTP 429 (API throttling) errors gracefully
* Handles large item uploads with batching (4 MB+)
* Fixed an issue with empty child / nested folders, now this script is pretty robust and can be stopped and re-run whenever without creating tons of empty nested folders, now it will just skip files if they exist and otherwise put everything into the "Home Folder" that gets created the first time the script is run
* I've also tested having multiple people run this script simultaneously (as well as running it in multiple tabs of windows terminal) and it ran without issue, though I can't say what will happen if you max out your API calls. There is API throttle handling in the script but it might not work perfectly, give it a cooldown before trying again I suppose.

**get-token.ps1**
* As mentioned above, this just grabs a 1 hour access token for you to use with the primary script and stores it in $Auth variable
* You can run this script and then immediately run `$Auth` in your shell after to verify its working
* i ended up also making a `get-token2.ps1` with a different clientID/secretKey in my environment so i could run the script in 2 tabs or with 2 people using different app ID's to try and reduce API usage / throttling issues
* if you want to do the same thing just register 2 entra apps, its just the same script each time just change up the variables at the beginning of the script

**get-authaud.ps1**
* This was a troubleshooting script I made to verify my roles and scopes and suchlike for the token, hopefully you don't have to get this deep into the weeds like I did
* If you find yourself running this script you should probably just immediately go to your mgmt and beg for ShareGate at this point tbh

**check-od.ps1**
* just a small helper file I came up with to check the contents of a specified user's OneDrive\Home Folder -- just for a final verification if you want to run it, to ensure the files got copied over
* in initial testing I'm just doing all of this to my own OneDrive folder so its no big deal I can just look at my own OneDrive whenever in many places, but, it might be more of a pain to check other people's OneDrive's later when I start migrating all of them (we havent allowed users to use onedrive at all yet so there is nothing available for me to check in their `c:\users\...` directory or i would just do that)
* the only issue with using this script is it is adding more API calls to your app token so might hit throttle limits sooner if you use this a bunch
