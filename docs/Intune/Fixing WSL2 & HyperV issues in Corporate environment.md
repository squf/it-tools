> This issue impacts users trying to set-up a Linux shell in Windows Terminal in a standard Microsoft shop (*e.g. I am assuming the Windows Store is blocked and there is a company firewall doing SSL inspection*). This is mostly important for scripting and development purposes, as the Linux ecosystem offers a wide variety of powerful developer tools and makes package management much simpler.
> 
> **References:**
> 
> * **WSL/WSL2** - Windows Subsystem for Linux, runs on Hyper-V to allow you to run a Linux shell from your Windows PC natively. 
> >
> * **Hyper-V** - The underlying technology which runs WSL, which runs the Linux distributions as virtual machines interestingly enough. The main things for us are that we have to check certain services and Windows Features are running.

**Installation:**

Since the Microsoft Store is blocked in our environment, you might try using the guide published at: [Install WSL | Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/install) - which shows you can install any from a number of Linux distributions through PowerShell 7 / modern Windows Terminal. 

> There are technically two versions of WSL, hence sometimes I might refer to it as WSL or WSL2. By this time, **everything should just be running on WSL2** and **that is the version we push from PMPC**, it's just a habit of mine from the days when WSL2 first launched and making the distinction was important. 
> 
> You can check your version in PowerShell at any time with: `wsl -l -v` or `wsl --status`

In my environment, we manage installation and patching for WSL through PatchMyPC, this will vary depending on environment. Additionally, we are not doing anything to block HyperV or associated services, but you need to ensure the Windows Feature for HyperV is enabled to use this feature.

---
### **The problem:**

<img width="690" height="154" alt="image" src="https://github.com/user-attachments/assets/77f91bd0-20ce-4473-b8d2-15d5726e65c5" />

```shell
Logon failure: the user has not been granted the requested logon type at this computer.
Error code: Wsl/Service/CreateInstance/CreateVm/HCS/0x80070569

[process exited with code 4294967295 (0xffffffff)]
You can now close this terminal with Ctrl+D, or press Enter to restart.
```

You won't see this problem right away after installing a Linux distribution, for me I didn't see the problem for the first time until the day after I installed Ubuntu. I'll explain why below.

---

### **Figuring out the problem:**

**The Virtual Machines SeServiceLogon Rabbit hole** - Per this Github issue I was reading: [The user has not been granted the requested logon type at this computer · Issue #5401 · microsoft/WSL](https://github.com/microsoft/WSL/issues/5401) - `VIRTUAL MACHINE\Virtual Machines` - AKA SID: `S-1-5-83-0` - This service worker account needs special "logon as service" permissions -- having related policies set-up can trigger a **policy collision** which I found happening in my environment.

Because we had any **User Rights Assignment** policies set-up at all, we caused this issue. Our company's user rights assignment policies in Intune were preventing specific accounts from signing in as a service, which ultimately caused this issue for us. I read that these policies specifically are **replacement policies** and not additive policies like mostly every other policy type is. This also explains why there is a special section for such policies in Intune, under **Endpoint Security > Account protection**.

**So because these are replacement policies, here's how it works:**

* Windows OS has a "**default list**" of various accounts and services and SID strings allowed to logon to Windows in various ways (as a service, locally, etc.) -- this gets stored in secpol, you can check this out at any time with: `secedit /export /cfg C:\temp\security.inf` && `notepad C:\temp\security.inf` -- specifically the `SeServiceLogon` value here 
* Hyper-V has a service that runs called VMMS, one of the jobs this service manages is injecting the SID value for the VM worker account into the local secpol list when it's missing
* If you don't have any **User rights assignment** policies set-up at all, no problem you will just use the **default list** and never see this problem
* If you have **User rights assignment** policies set-up, because these are special **replacement policies**, it replaces the **default list** entirely with whatever you've specified
* Hence, in our policies, we tend to enable this setting: "**Deny logon as service to: Account1, Account2, etc.**" without specifying anything else, such as our Virtual Machines account as having Allowed logon as a service.
* Because the **default list** has now been replaced, and it just includes our deny rules, the VM service worker can no longer run at sign-in time 
* If you run a `gpupdate /force` it temporarily resets the local gp cache and state, allowing you to temporarily bypass the issue. This is the crowbar fix.
* Because our policies are **omissions** and not strict **denial** policies (e.g. we're not explicitly refusing the VM worker SID LogonAsService rights, we're just not explicitly granting them either) -- the VMMS service is alerted when the secpol changes (you just ran gpupdate), and checks secpol and sees "hey, I'm not on this list" and goes ahead and re-adds its SID string there. 
* This is why running gpupdate works like a crowbar, to temporarily wedge open the local secpol on the device and allow Hyper-V to heal itself momentarily, until the next policy sync
* I think we just need to add this SID: `S-1-5-83-0` to the "**Allow log on as a service**" setting, this is the SID string for the "**VIRTUAL MACHINE\Virtual Machines**" service worker account. Once we grant it allow rights, it should work with the rest of our policy settings. 

---

### **The fix:**

In my company's environment, we have `MDMWinsOverGPO` set up, and all of our SCCM sliders moved over to Intune. I leveraged this to isolate my laptop for testing purposes, the policy I pushed from Intune to add the Virtual Machine worker will overwrite any GPO settings.

I added the SID string for the Hyper-V VM worker account, as allowed for Service Log On:

<img width="332" height="20" alt="image" src="https://github.com/user-attachments/assets/c15bb5b3-fde5-47d7-bc13-0e9d6d6e8c3d" />

One funny thing I ran into, I'll spare you the time. **Make sure you prefix an asterisk**. When adding SID strings like this, just put an asterisk at the front, so when you go to enter this in Intune it needs to be in this format: `*S-1-5-83-0`. 

Long story short, I thought my policy wasn't working until I discovered this and it started working immediately after I added the asterisk.

**This should fix the issue** in your environment as well, unless you have other confounding factors at work. After fixing WSL2 / Ubuntu, the first thing I tried doing was installing Rust so I could start working on some Rust apps, and then I ran into a separate but similar issue with that. I will outline that issue below.

---

### **Fixing Rust install**

Because of our corporate firewall and SSL inspection, we often run into issues in our environment installing packages the default way that Linux environments expect.

For example if you just follow the standard Rust install command line on most Rust guides, as follows:

```bash
curl --proto '=https' --tlsv1.3 https://sh.rustup.rs -sSf | sh
```

You will get these SSL related errors:

```bash
warn: curl: (60) SSL certificate problem: self-signed certificate in certificate chain

More details here: https://curl.se/docs/sslcerts.html

  

curl failed to verify the legitimacy of the server and therefore could not

establish a secure connection to it. To learn more about this situation and

how to fix it, please visit the web page mentioned above.

error: command failed: downloader https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init /tmp/tmp.MmN0AESRBa/rustup-init x86_64-unknown-linux-gnu
```

##### Fix - Add firewall cert to Ubuntu cert store:

* Went to https://static.rust-lang.org
* Lock icon -> Certificate details
* There were two certificates here, one for the website, and the top one started with one of our internal IP addresses
* I downloaded the top one which came in .crt format, so I had "**IPADDRESS.crt**" on my local Windows PC (this is the cert for our company firewall)
* I renamed and moved this file over to my WSL Home directory -> **/home/squf/network_appliance.crt**
* Copy the file over to the Ubuntu cert store (rename again, you don't have to rename if you don't want to):
  ```bash
  sudo cp ~.network_appliance.crt /usr/local/share/ca-certificates/work_proxy.crt
  ```
  * Cleanup potential Windows formatting errors:
```bash
sudo sed -i 's/\r$//' /usr/local/share/ca-certificates/work_proxy.crt
```
* Refresh cert store:
```bash
sudo update-ca-certificates --fresh
```

I am not sure if the standard installation line would work from here or not, I had already bypassed and gotten the binary downloaded and so I just ran that instead in my case.

* **If the standard Rust installation continues failing** after the above steps, try the following:

* Download binary directly (this should work even without the firewall cert):
```bash
curl -k -o rustup-init https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init
```
* Make the binary executable:
```bash
chmod +x rustup-init
```
* Run the installer binary & force curl:
```bash
RUSTUP_USE_CURL=1 ./rustup-init
```
