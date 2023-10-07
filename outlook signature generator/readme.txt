this was a fun project to work on

company needed "company wide email signature branding" without paying any money

so:

first script is `get-signature.ps1`
second script is `set-signature.ps1`, which is meant to be set-up in your NETLOGON folder as a user logon script

you'll need a place to store the company .htm files which will be generated as part of this process, and it needs to be globally available for your intranet
i set `get-signature.ps1` up as a scheduled task on the server hosting the .htm files

when the GPO is running via set-signature.ps1, it will look in the directory i set-up on this server to grab .htm files
it will then move those .htm files to the $ENV:USERNAME's %appdata%\microsoft\signatures folder, creating this directory if it doesn't already exist in the process
this will make the signature.htm file pop-up in the users Outlook following their sAMAccountName naming convention

i also added some registry cleanup things to the set-sig script but i'm not sure if they are needed or helpful at all, i was trying to also troubleshoot an issue with Outlook our company had, but the registry cleanup didn't help with that. oh well.
