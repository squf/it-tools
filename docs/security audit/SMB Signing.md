# Configure SMB Signing for Windows

Links:

* [Configure SMB Signing with Confidence | Microsoft Community Hub](https://techcommunity.microsoft.com/blog/filecab/configure-smb-signing-with-confidence/2418102)
* [Overview of Server Message Block signing in Windows | Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-signing-overview)
* [Controlling SMB Dialects | Microsoft Community Hub](https://techcommunity.microsoft.com/blog/filecab/controlling-smb-dialects/860024)

To-do:

* There are GPO's that enable this as a requirement which would be the fastest and easiest way to target everything connected to our domain. 
* Thinking ahead, we may want to handle this without GPO since we may not always be able to rely on GPO and we want to ensure we have a method to manage these settings strictly from the cloud. This will be harder.
* The settings we need to hit are as follows:
	* ![image](https://github.com/user-attachments/assets/cba5c042-f645-4435-80ce-ad93da9fdbae)

	* Workstations: `HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\LanManWorkstation\Parameters` -> `RequireSecuritySignature = 1`
	* Servers: `HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\LanManServer\Parameters` -> `RequireSecuritySignature = 1`
	* I do not believe we are using SMB1 anywhere in the environment, though we would need to inspect that on servers, especially if there are still any servers older than 2019 still running (SMB1 stopped being included by default with Windows 10 and Server 2019 editions, and it seems unlikely to me that we'd have enabled it beyond that time. We can always come up with a Powershell script to ping out to everything on the network and report back all SMB-Connection statuses to be certain.)
	* If we are using SMB1 anywhere though, we'd also want to turn on the "Enable" settings. These get ignored in SMB2+ protocol because they are ON by default, it's a little complicated but you can read the first link above for more info if you want.

So Option 1 is we just turn these GPOs on at the root and let everything get these GPO changes, simple and easy and fast. For our non-domain and non-Intune devices, we likely need to use Powershell and send registry changes remotely to each of them.

Option 2 is if we want to approach this in a different way to ensure we can manage these settings in the medium-term future, i.e., when we decommission our on-prem environment and stop having access to GPO altogether. We use Powershell to set the registry settings manually, this could be a remediation script in Intune that targets all devices -- and then separately we need a way to push this to all servers which are not managed via Intune. Beyond that, I don't know of a clean way for us to manage all of our non-domain and non-Intune enrolled Windows devices, other than a lot of manual effort to send remote Powershell calls to set the registry on each of them.

**My current understanding:**

* I'm already familiar with PGP and MD5 hashes and setting up public/private keys from things I've done in Linux in the past like setting up ssh as an alias in `~/.bashrc`, I didn't want to just store my plaintext ssh credentials in there so I set-up keys to pass the connection instead. SMB signing is similar to this although it uses more modern encryption algorithms like AES-CMAC instead of MD5 or SHA-256, but the concept is the same. I'm familiar with MD5 hashes from downloading files from the internet, many times a public MD5 hash will be included that you can use to verify the file you downloaded wasn't tampered with. When I think of SMB I think of network shares, and I know SMB signing has been a default setting on domain controllers for decades like on the NETLOGON folder. 
* Ensuring SMB signing is enabled throughout our environment should increase our security posture by encrypting all SMB protocol data we're transmitting, which to my knowledge includes a lot of PII data that runs as part of daily scripts.
* **According to the first link from above "Configure SMB Signing with Confidence", there's a few things to note:**
	* There are legacy holdover differences between "Enabled" and "Required", we need to ensure we're targeting the "Required" settings and turning them on for everything. The "Enabled" settings are ignored nowadays but still hang out in registry, except of course if we're still using SMB1 anywhere we want these turned on as well then. As an aside, we shouldn't be using SMB1 anywhere if we're serious about securing our environment.
	* SMB signing is always enabled in SMB2+. 
	* legacy SMB1 client is no longer installed by default in Windows 10 or Windows 2019
	* We can run `get-smbconnection | fl Signed` in an elevated Powershell to check our current environment with, and verify the settings after we require them everywhere:
	  
	  PS C:\Users\squf> `get-smbconnection | fl Signed`
	  Signed : False
	  Signed : False
	  Signed : False
	  Signed : False
	  Signed : False
	  Signed : False
	  Signed : False
	  Signed : False
	  Signed : True
	  Signed : True
	  Signed : False
	  Signed : True
	  Signed : True
	  
	* You can also just run `get-smbconnection` to see what is currently using SMB protocol on your host, and pipe `fl` after for a more verbose list. I would include a screenshot here but it has a lot of sensitive info in it, so just run it on your own PC for an idea of what I'm talking about! You'll also see that it reports back any open network shares which is why I said above "When I think of SMB or Samba I think of network shares".


**TL;DR:**

* We do not currently have SMB Signing required everywhere, as evidenced by running `get-smbconnection | fl Signed` from an elevated Powershell window. 
  
* We can fix this by GPO and/or Registry settings. To target our non-domain devices we will need to use Powershell anyway, so may as well just use Powershell for everything. The GPO just changes the following registry keys:
  
* **Workstations:** `HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\LanManWorkstation\Parameters` -> `RequireSecuritySignature = 1`
  
* **Servers:** `HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\LanManServer\Parameters` -> `RequireSecuritySignature = 1`
