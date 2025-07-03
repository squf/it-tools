# Firefox Removal Intune Remediation scripts

* This might not be extremely useful to anybody on its own, unless you happen to also need to completely nuke Firefox everywhere in your environment too in which case hey set this up in Intune should be great for you
* The reason I wanted to include these scripts in my `it-tools` repo is to show the types of things to watch out for when doing uninstall remediations, because I had to go through several iterations of this script to get it to where it is currently
* The first version of the script was just running the silent uninstall via helper.exe (found on: https://silentinstallhq.com/mozilla-firefox-122-silent-install-how-to-guide/ -- a good website in general for app management) and then nuking the Program Files directory
* Then I spent a few hours really deep diving into everything Firefox could possibly be doing, i.e., why was it persistently showing up in my Discovered Apps list in Intune?
* Based on that research, I found the following things to check for, which these scripts cover:

- Recursively looking everywhere for anything Firefox related, nuking from orbit
- 2 sets of scripts, one to run in User context (be sure to set this to "User context" when setting it up in Intune) -- and the other to run in System context to clean up after
- Firefox can also (found this on some of our PC's, not on others) set-up a Mozilla Maintenance Service, which is how it keeps itself automatically updated without UAC prompts. Find and remove this service and all associated folders/data/regkeys as well.
- Some apps get installed under sys/user context and it differs depending on a lot of factors (how were they installed to begin with?) -- so based on that, I just came up with 2 sets of scripts, and just nuke both. ezpz.
- Have to clean up registry entries and ensure all four of these places: `HKCU & HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` and `HKCU & HKLM:\Software\Mozilla` get recursively force deleted, vulnerability scanners and Intune check these places to determine whether something is installed or not

* So that's why this is here, even if you don't need to remove Firefox specifically via Intune, these types of bullet points might be useful things to keep in mind for the future when dealing with other apps you want to strip completely out of your environment. Basically just keep in mind that an app is going to leave behind way more data in way more places than you might initially expect, and always keep USER vs SYSTEM context in mind for handling uninstalls (the easiest way to be sure if you're not sure is to just run both context uninstallers)

* I've found that removing Firefox from Intune remediations is a **massive pain** so I ended up with 3 separate remediations for this
* The "FF_helper" detection & remediation scripts should actually process the uninstall for Firefox if its present, this is under `...\uninstall\helper.exe` in Program Files folders on a given PC with Firefox installed
* Running this file should remove Firefox from a PC
* The other files in here will nuke out registry / scheduled tasks / services / other things, in case helper doesn't catch those things (its supposed to)
* So I would recommend if you want to just use these scripts directly in your environment, start with the **FF_helper** scripts in 1 remediation, let it run for a day or so on your target devices, and then if that's not fully clearing it out you can move to the other bundles of scripts (which need to be set up as two separate remediations, one for User context and one for System context)
