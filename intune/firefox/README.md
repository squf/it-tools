# Firefox Removal Intune Remediation scripts

* This might not be extremely useful to anybody on its own, unless you happen to also need to completely nuke Firefox everywhere in your environment too in which case hey set this up in Intune should be great for you
* Firefox includes an uninstaller file at `...\Mozilla Firefox\uninstall\helper.exe` in either Program Files directory depending on how it was installed
* The helper script(s) are designed to detect and silently run this file, and wait for the process to complete with either exit code 0 or 1, then logs this output to `C:\tmp\FirefoxHelper.log`
* The reg script(s) are designed to detect the existence of the `...\FirefoxHelper.log` output from the helper scripts, and if they exist, then it will try to delete: `HKLM\SOFTWARE\Mozilla` `...\mozilla.org` `...\MozillaPlugins` in registry, and output results to `C:\tmp\FirefoxRegistry.log`
* This should in theory work to completely remove Firefox cleanly from PC's these scripts are assigned to via Remediation Script in Intune
* But who knows, these are like the 5th version(s) of similar scripts I've been trying to run for a week now with no success (!)
