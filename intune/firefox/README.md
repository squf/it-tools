# Firefox Removal Intune Remediation scripts

* This might not be extremely useful to anybody on its own, unless you happen to also need to completely nuke Firefox everywhere in your environment too in which case hey set this up in Intune should be great for you
* The reason I wanted to include these scripts in my `it-tools` repo is to show the types of things to watch out for when doing uninstall remediations, because I had to go through several iterations of this script to get it to where it is currently
* The first version of the script was just running the silent uninstall via helper.exe (found on: https://silentinstallhq.com/mozilla-firefox-122-silent-install-how-to-guide/ -- a good website in general for app management) and then nuking the Program Files directory
* Then I spent a few hours really deep diving into everything Firefox could possibly be doing, i.e., why was it persistently showing up in my Discovered Apps list in Intune?
* Based on that research, I found the following things to check for, which these scripts cover:

- Helper.exe uninstall cmd
- WMI uninstall cmd
- Registry cleanup for Software\Mozilla keys
- Registry cleanup for Windows\...\Uninstall keys
- Scheduled Task cleanup
- User data cleanup in all AppData directories
- Stops MozillaMaintenance service if it is running, then deletes it silently
- Removes all MozillaMaintenance folders and regkeys if found
- Intune inventory cache cleanup in IME registry path
- Force IME refresh to push updated app info back to Intune for faster reporting updates
- Outputs .log to -> C:\tmp\FirefoxUninstall.log - for tracking (does not append,  just overwrites to avoid .log bloat - creates c:\tmp if it doesn't exist, etc.)

* So that's why this is here, even if you have no need to remove Firefox via Intune, these types of bullet points might be useful things to keep in mind for the future when dealing with other apps you want to strip completely out of your environment. Basically just keep in mind that an app is going to leave behind way more data in way more places than you might initially expect.
