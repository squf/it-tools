# Disable TLS for 3DES Cipher suite

**Links**:

* [Disable-TlsCipherSuite (TLS) | Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/tls/disable-tlsciphersuite?view=windowsserver2025-ps)
* [Correct way to disable insecure cipher? - Windows - Spiceworks Community](https://community.spiceworks.com/t/correct-way-to-disable-insecure-cipher/829071/6)

**To-do:**

* There's a Powershell cmdlet you can run to check what cipher suites are enabled on a given host: `get-tlsciphersuite` -- I ran this on my laptop and 3DES is not enabled. I checked our vuln. scanner report and found that it picked it up on one server -> EDITEDFORGITHUB.vm.local, this is the only host in our environment reporting that it has 3DES Cipher suite still enabled
* Running this cmdlet on that host should resolve it, if not there are registry and GPO settings to look at as well in the links above. Since we're only getting dinged on this for a single host I think GPO seems excessive and would rather manually remediate this on the single host.
* **Remove cmdlet:** `Disable-TlsCipherSuite -Name "TLS_RSA_WITH_3DES_EDE_CBC_SHA"`

I don't think there's a need to outline my current understanding or TL;DR on this one so I will spare you the rambling! It's part of an encryption algorithm so think MD5, SHA-256, AES-CMAC, etc., its just that 3DES is apparently an older cipher suite that is easily crackable these days.
