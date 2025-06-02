This is a long one!

So the issue we're running into with my tenant is that the Primary User is not updating cleanly in Intune:

![Pasted image 20250530144243](https://github.com/user-attachments/assets/0edc1dda-8225-4a17-99d4-4ce3fced1ed5)



We're using this "ClientInstall" account to build out laptops and then hand them off to other people, but then the laptops just get stuck with this being the primary UPN. This causes issues with PRT, SSO, and a whole host of other problems.

Now my ideal solution would of course be that we move to fully AADJ environment, and we get a new laptop vendor that can actually support Autopilot for us (ours cannot), and we don't deal with any of this stuff ever. However it's not my company and not my rules so I am stuck in HAADJ Hell.

# How to fix?

* First, I found this blog post:[Set Intune Primary User with Azure Automation - Mr T-Bone´s Blog](https://www.tbone.se/2025/03/31/set-intune-primary-user-with-azure-automation/)
* And the associated script is here on GitHub: [Intune/Intune-Set-PrimaryUsers.ps1 at master · Mr-Tbone/Intune](https://github.com/Mr-Tbone/Intune/blob/master/Intune-Set-PrimaryUsers.ps1)

* Script seems to work fine I guess, I dunno, I think I ran this a month ago when I was last working on this. But then I got distracted and forgot about this for a month. Today I was looking at Intune and saw all of the ClientInstall Primary User UPN's and I was very confused. "I thought I fixed this a month ago with the Azure Runbook I set-up?" then I checked in on it and actually I never published the runbook (LOL).

* So today I try to publish the runbook, but I run into errors, and I find that this is probably because I never assigned permissions to the Azure Automation account correctly. Ho...

* Mr. T-Bone has another script here for permissions:

* [Intune/Azure-Add-PermissionsManagedIdentity.ps1 at master · Mr-Tbone/Intune](https://github.com/Mr-Tbone/Intune/blob/master/Azure-Add-PermissionsManagedIdentity.ps1)

* However, I keenly detect that this is using AzureAD module which is deprecated. I can't even install this anymore through PowerShell gallery. So now how am I going to get this working?
	* [PowerShell Gallery | AzureAD 2.0.2.182](https://www.powershellgallery.com/packages/azuread/2.0.2.182) See? I run this, nothing happens. Not even installable in mid-2025!
	* [Important update: Deprecation of Azure AD PowerShell and MSOnline PowerShell modules | Microsoft Community Hub](https://techcommunity.microsoft.com/blog/microsoft-entra-blog/important-update-deprecation-of-azure-ad-powershell-and-msonline-powershell-modu/4094536) - its deprecated!

* I found a script somewhere online that does the same thing but works with MgGraph, I cannot remember WHERE I found this and its not in my History in any browser so oops sorry. I will post the script here as a separate file but just know that I didn't write it and I can't properly attribute it because I don't remember and can't find where I stole it from.

* I am trying to run this script to add permissions to my Azure Automation Account to be able to run the runbook which will ultimately set the primary user values for us in Intune. What a long-winded way to go about this. However, I keep running into errors, after troubleshooting and debugging many errors I am running into, I get this one persistent one:

![Pasted image 20250530145738](https://github.com/user-attachments/assets/1e28b37e-fcab-4b14-8f18-6338ac2ce440)

* I spent seriously god knows how long trying to get this resolved but its basically just my fault for not knowing enough about Azure. That's why I made this doc! So basically long story short, I have an ==Enterprise Application== in Entra which has a whole heap of permissions on it to work with Graph API:
	* ![Pasted image 20250530145845](https://github.com/user-attachments/assets/928e28f7-5338-490e-bbe3-b383d0d0d536)

					  Enterprise App
* But this ==Enterprise App== is missing some key permissions I know I will need based on T-Bone's script from before, specifically I need:
	* `"DeviceManagementManagedDevices.Read.All", "DeviceManagementManagedDevices.ReadWrite.All", "AuditLog.Read.All", "User.Read.All"`
* But as you can see above, in an ==Enterprise App==, there's nowhere for me to add new permissions... I know I've seen an "Add Permissions" button somewhere before but where...
* I check ==App Registrations== and there's nothing in there associated with my Enterprise App, but just for funsies I check another registered app and sure enough there it is, the beautiful Add Permissions button:
	* ![Pasted image 20250530150020](https://github.com/user-attachments/assets/4292a29c-f6b2-40d4-a4db-a82cdc369c0c)

					  App registrations
* I get this kooky idea to just register a "dummy" app for Graph, assign the permissions I need from above, and then grant them Admin consent. **This works!**
  
* So I learned about Service Principals in Azure today.

* Now I try running the AddPermissions script again
* I sign-in with my Global Admin:
	* ![Pasted image 20250530150323](https://github.com/user-attachments/assets/54c205e4-7bc5-4bfb-b1c8-e6e3569fff93)

* Aaaaand I get the error again.
* I go to Graph Explorer and query:
	* `https://graph.microsoft.com/v1.0/servicePrincipals?$filter=appId eq 'my-cool-enterprise-app-for-graph'`
* And this reveals that there are no appRoles available for this app... confusing!
* Then I update the script, instead of using my Enterprise App, I point it at the default Microsoft Graph API service principal:
	* `00000003-0000-0000-c000-000000000000`
* I run the script again and get a different output, this time I get a full list of all available app roles and verify that the ones I'm trying to add are present, but then I get a bunch of "Bad 400" requests.
* This appears to be because the necessary permissions are already applied to the Automation Account somehow............maybe the earlier runs did work I don't know.
* At any rate, from here I am able to go to Azure and finally publish the runbook associated with this Automation Account:
* ![Pasted image 20250530152308](https://github.com/user-attachments/assets/825cc0ab-41a5-473a-923b-e70e9c1aa5c1)

* It was stuck in "New" status and not publishing for some reason.
* I added a space to a line that was commented out, which allowed me to Save the script, and after that I published it again, and now it is finally showing as an actually published runbook in my Automation Account. Neat.
* Now that its published, the Start button is finally clickable! It's no longer greyed out!
* ![Pasted image 20250530152850](https://github.com/user-attachments/assets/0b5020d3-2120-46b9-b08a-7f7d37a1b5c1)

* I exported our Windows devices from Intune so I'd have a .csv of the previous Primary Users to compare with
* I am getting a little nervous about running this so I made sure to set the testing mode to $true and hopefully that will be like a "What-If" and not actually apply changes to my tenant first lol
* Ran the runbook
* When I ran it, a window popped up showing me a list of parameters which are the ones from the script which I thought was pretty neat that it took those and made a little GUI final check for me
* ![Pasted image 20250602095334](https://github.com/user-attachments/assets/a13ddb6f-5d28-4867-aa3e-0b2b71a9e047)

* Using this GUI, I went down to the Testing parameter and made sure it was TRUE and then ran it. After some time the runbook finished running and I saved the output. I found that 115 of our Intune devices Would Be changed to a new Primary User if I actually ran this, and after reviewing them it all looks pretty accurate to me. The main issue of all of these ClientInstall accounts would be resolved if I ran this.
* Since this script works by looking at the last 30 days of sign-in logs to determine the Primary User to update to, I will most likely end up setting this up with a schedule to run every 30 days from Azure once I get change request approval from management at my company.

**Takeaway:**

* All in all, this took about half a day (4 hours) to put together (not counting that I started it a month ago and then got sidetracked. Once I sat down and figured it out, it took about half a day) and should at least help our environment. I gained exposure to simple topics about Azure and learned some more funky things to keep in mind for the future when dealing with Azure runbooks and Graph API permissions, Service Principals, etc.
* I still don't know why the script itself wouldn't publish the first time, or why just adding a commented out space and re-saving it allowed me to then publish it successfully, but I chalk this up to "Azure weirdness" and just a thing to keep in mind for next time.
* I also noticed that, our environment's custom Graph permissions Enterprise App appears to have lost all of its previous permissions. I think this happened after I ran the script to add permissions for the Azure automation account to the primary Graph service principal, but I'm not sure. Somewhere in this mess I seem to have nuked our primary Graph app permissions, but, the other 30~ or so scripts I have using that app currently appear to be unaffected. Thankfully I am the only Global Admin here who would be impacted by this if it did break anything, though it doesn't appear to have broken anything at this time. I need to keep this in mind and be more careful in the future however.
* Overall I think this will be very handy resource going forward, I am mentally treating Azure runbooks as a more modern / better way of doing system/tenant administration than older on-prem methods. This is, to me, basically a drop-in 'cloud native' way of doing the traditional task I'm used to of: Setting up a script, registering it as a scheduled task on some VM, and then having the script run constantly in the background on a schedule. Like a daemon in Linux world in the loose sense of being a background process that runs conditionally.
* Now I will think of other things that might make sense to set-up as Runbooks and see about setting up more runbooks, but I also am curious to track our billing usage over the next month to see how much this scheduled runbook costs us in total for Azure compute costs.
