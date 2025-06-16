Our vulnerability scanner recommends applying the following cipher configuration:

`ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK:!SHA1:!DSS`

This is in OpenSSL format and won't work neatly with Microsoft, see below for translation:

| OpenSSL Name                  | Windows Name                                  |
| ----------------------------- | --------------------------------------------- |
| ECDHE-ECDSA-AES128-GCM-SHA256 | TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256       |
| ECDHE-RSA-AES128-GCM-SHA256   | TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256         |
| ECDHE-ECDSA-AES256-GCM-SHA384 | TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384       |
| ECDHE-RSA-AES256-GCM-SHA384   | TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384         |
| ECDHE-ECDSA-CHACHA20-POLY1305 | TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 |
| ECDHE-RSA-CHACHA20-POLY1305   | TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256   |

**Example code:**

```
$preferredCiphers = @(

    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",

    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",

    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",

    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",

    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",

    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"

)

foreach ($cipher in $preferredCiphers) {

    Enable-TlsCipherSuite -Name $cipher

    Write-Host "Enabled $cipher"

}
```
