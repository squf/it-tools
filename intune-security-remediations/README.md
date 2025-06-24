🐝 **CAREFUL** running these files (!)
---

- These scripts were developed at my current company to deal with some issues we were facing regarding our risk score from our vulnerability scanner
- These scripts resolve the issues outlined in my docs here: https://github.com/squf/it-tools/tree/main/docs/security%20audit
- So, this will disable TLS 1.0 and 1.1, and force TLS 1.2 enabled | force SMB signing | set-up ECC curves (https://learn.microsoft.com/en-us/windows/win32/secauthn/tls-elliptic-curves-in-windows-10-1607-and-later) | disable weak HMAC cipher suites and force 6 modern cipher suites | disable a cipher suite part of the SWEET32 vulnerability (https://sweet32.info/)
- Be careful running these without testing in your environment as changing these settings has the potential to kill your connection to network file shares or other servers relying on SMBv1 or TLS 1.0 or TLS 1.1 -- although hopefully you have some path forward to update your stuff anyway, but I'm just sayin'
