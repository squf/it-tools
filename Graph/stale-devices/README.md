# Managing Stale Devices in Intune and Entra

**Backstory**

* I was looking around on [Ugur's site](https://www.intuneautomation.com/script/get-stale-intune-devices) for some more things to add to my environment like I often do during downtime - (constant learning is a part of any IT role)

* This "get stale devices" script had me thinking about our Teams Devices (AOSP enrolled, Teams / Android desk phones and conference room devices we use at my current company)
  
* We have a TON of stale Android devices here because nobody ever bothered to set-up device clean-up rules, so it falls to me I suppose!
  
* I know about the built-in "Device clean-up rules" in Intune and this is a good start, the way this works to my understanding is you specify a time (usually 90 days is a good "safe" option to avoid accidentally removing someone's device while they were on PTO or something) and then when a stale device hits that mark it will get deleted from Intune. HOWEVER, it still hangs out in "the Microsoft infra backend" (so somewhere in Graph you could probably still find a record of this device but it should be gone from all main GUI portals at least) until the device certificate expires. Of course naturally, Rudy Ooms has a [blog](https://call4cloud.nl/intune-mdm-device-certificate-expired-0x80190190/) about this - please check out Rudy's work he's one of my favorite Microsoft MVP's.
  
* At any rate, I'm not going to dig into what our certificate expiration dates are right now, but from what I've read online they should default to 365 day lifetime -- this gets renewed by the scheduled task / intune sync cycle that kicks off every sign-in, so it's usually not something that ever causes an issue. Just noting here that, the built-in "Intune device clean-up rules" will just remove these stale devices from your Intune portal but they will still be hanging out in the background until that Intune MDM cert expires.

* **OK So what** - well, cleaning up from Intune is nice, but we have the same stale devices present in Entra as well. It sure would be nice to clean those up while we're at it instead of only cleaning Intune yeah? I do not know of anything built into Entra GUI directly that functions similar to Intune's device clean-up rules, so, my first thought was "make an Azure Runbook that does this automatically".

# Scripted solution

* I did work on my version of a total cleanup script that will delete from Entra and Intune, using [Remove-MgDeviceManagementManagedDevice powershell cmdlet](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.devicemanagement/remove-mgdevicemanagementmanageddevice?view=graph-powershell-1.0), but of course naturally I found other Microsoft admins also have blogs and websites dedicated to this same topic already.
* So you can either use my solution here, or refer to these other resources for more. In particular, TBone's blog-post below includes a full clean-up script, and he is well-known as a very good Microsoft MVP as well, so if you trust his solutions more than mine that is totally fine and you should just go read his blog for more info and use his script.
* You can find my version of this script in this repo, mine uses a Cert Thumbprint for app authentication, and has parameters for `-DaysStale` and `-WhatIf` so you can do a dry run before you fire it off, when you go to set this up as an Azure Runbook you can specify what you want those parameters to always run at in the Azure GUI.

* **Other resources:**
* [https://www.anoopcnair.com/intune-device-cleanup-rules-setup-guide/](https://www.anoopcnair.com/intune-device-cleanup-rules-setup-guide/)
* [https://www.tbone.se/2024/02/09/cleaning-up-inactive-intune-and-entra-id-devices/](https://www.tbone.se/2024/02/09/cleaning-up-inactive-intune-and-entra-id-devices/)
* [https://techcommunity.microsoft.com/blog/devicemanagementmicrosoft/using-intune-device-cleanup-rules-updated-version/3760854](https://techcommunity.microsoft.com/blog/devicemanagementmicrosoft/using-intune-device-cleanup-rules-updated-version/3760854)
