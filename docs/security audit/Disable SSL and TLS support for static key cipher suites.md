**Links:**

* https://learn.microsoft.com/en-us/windows-server/security/tls/tls-registry-settings?tabs=diffie-hellman
* https://learn.microsoft.com/en-us/windows-server/security/tls/manage-tls#configure-tls-cipher-suite-order
* https://learn.microsoft.com/en-us/powershell/module/tls/?view=windowsserver2025-ps

**To-do:**

* our vulnerability scanner is complaining about the following cipher suites:
  - TLS 1.2 ciphers:
    - TLS_RSA_WITH_AES_128_CBC_SHA
    - TLS_RSA_WITH_AES_128_CBC_SHA256
    - TLS_RSA_WITH_AES_128_GCM_SHA256
    - TLS_RSA_WITH_AES_256_CBC_SHA
    - TLS_RSA_WITH_AES_256_CBC_SHA256
    - TLS_RSA_WITH_AES_256_GCM_SHA384`

* This cmdlet doesn't support commas / multiple suites in one-line, the following should resolve our issues:
  
* `Disable-TlsCipherSuite -Name 'TLS_RSA_WITH_AES_128_CBC_SHA'`
* `Disable-TlsCipherSuite -Name 'TLS_RSA_WITH_AES_128_CBC_SHA256'`
* `Disable-TlsCipherSuite -Name 'TLS_RSA_WITH_AES_128_GCM_SHA256'`
* `Disable-TlsCipherSuite -Name 'TLS_RSA_WITH_AES_256_CBC_SHA'`
* `Disable-TlsCipherSuite -Name 'TLS_RSA_WITH_AES_256_CBC_SHA256'`
* `Disable-TlsCipherSuite -Name 'TLS_RSA_WITH_AES_256_GCM_SHA384'`

Or an example array:

```
$ciphers = @(

    'TLS_RSA_WITH_AES_128_CBC_SHA',

    'TLS_RSA_WITH_AES_128_CBC_SHA256',

    'TLS_RSA_WITH_AES_128_GCM_SHA256',

    'TLS_RSA_WITH_AES_256_CBC_SHA',

    'TLS_RSA_WITH_AES_256_CBC_SHA256',

    'TLS_RSA_WITH_AES_256_GCM_SHA384'

)

foreach ($cipher in $ciphers) {

    Disable-TlsCipherSuite -Name $cipher

    Write-Host "Disabled $cipher"

}
```

Can be done via GPO as well: **Computer Configuration** > **Administrative Templates** > **Network** > **SSL Configuration Settings**

![image](https://github.com/user-attachments/assets/7f1feaab-02a3-4b05-bada-526c4f10db73)


Same issues as all the rest applies here though, GPO won't capture all hosts reporting vulnerabilities in our vulnerability scanner.
