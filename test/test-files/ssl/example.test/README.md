# Testing certificates for TLS

Use these certificates for any tests that require a certificate during a test. **DO NOT USE IN PRODUCTION**.

These certificates for usage with TLS have been generated via the [Smallstep `step certificate`](https://smallstep.com/docs/step-cli/reference/certificate/create) CLI tool. They have a duration of 10 years and are valid for the SAN `example.test` or it's `mail` subdomain.

`Certificate Details` sections are the output of: `step certificate inspect cert.<key type>.pem`.

---

**RSA (2048-bit) - self-signed:**

```sh
step certificate create "Smallstep self-signed" cert.rsa.pem key.rsa.pem \
  --no-password --insecure \
  --profile self-signed --subtle \
  --not-before "2021-01-01T00:00:00+00:00" \
  --not-after "2031-01-01T00:00:00+00:00" \
  --san "example.test" \
  --san "mail.example.test" \
  --kty RSA --size 2048
```

<details>
<summary>Certificate Details:</summary>

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 208627341009417536895802991697858158387 (0x9cf42a11521763a5a0fbd1cedb085f33)
    Signature Algorithm: SHA256-RSA
        Issuer: CN=Smallstep self-signed
        Validity
            Not Before: Jan 1 00:00:00 2021 UTC
            Not After : Jan 1 00:00:00 2031 UTC
        Subject: CN=Smallstep self-signed
        Subject Public Key Info:
            Public Key Algorithm: RSA
                Public-Key: (2048 bit)
                Modulus:
                    e2:78:fa:af:1b:82:ee:92:8c:b6:9b:96:ee:a7:4f:
                    b8:dd:72:ec:c6:85:97:a8:53:c0:ad:0c:04:c9:23:
                    5d:3e:f5:1a:ce:78:b7:14:fd:61:53:1e:51:03:54:
                    64:60:3c:87:38:c9:fc:ec:55:8e:c0:dd:82:8c:ac:
                    d9:e9:b8:ee:37:df:95:60:d9:f2:02:f6:21:04:e0:
                    af:d2:c5:1a:b6:3e:5f:dc:3a:31:b8:e6:c7:37:8b:
                    7a:53:54:b1:21:61:34:31:05:aa:6f:28:88:89:2d:
                    ac:43:f8:4f:b0:e7:57:17:fe:b6:4d:b3:7c:0e:f4:
                    34:58:1c:b7:06:e9:33:13:d3:2a:68:eb:41:c3:5c:
                    cf:a9:f1:76:b4:41:9e:cd:86:6a:4a:80:6b:05:cd:
                    5c:0f:1a:6d:f6:8d:ed:50:a2:b5:f7:97:00:75:1b:
                    36:9f:e8:68:e7:43:d4:1c:cc:7e:d3:03:e0:c5:be:
                    54:ab:e9:e4:dc:53:36:6c:b2:46:fb:72:bd:26:e7:
                    9b:c6:45:a9:be:4a:e3:10:b8:80:55:ee:28:63:09:
                    09:60:9c:fb:57:f4:c7:36:8f:09:39:32:9d:26:92:
                    4b:78:51:9c:eb:bc:74:61:ec:80:6e:73:59:5d:52:
                    f2:02:95:24:f7:47:9d:6a:b2:b3:17:35:9d:48:58:
                    81
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage:
                Server Authentication, Client Authentication
            X509v3 Subject Key Identifier:
                05:AC:63:51:E2:44:A1:46:F8:08:86:D9:EF:69:32:B2:89:6D:DA:CE
            X509v3 Subject Alternative Name:
                DNS:example.test, DNS:mail.example.test
    Signature Algorithm: SHA256-RSA
         50:47:7b:59:26:9d:8d:f7:e4:dc:03:94:b0:35:e4:03:b7:94:
         16:7e:b6:79:c5:bb:e7:61:db:ca:e6:22:cc:c8:a0:9f:9d:b0:
         7c:12:43:ec:a7:f3:fe:ad:0a:44:69:69:7f:c7:31:f7:3f:e8:
         98:a7:37:43:bd:fb:5b:c6:85:85:91:dc:29:23:cb:6b:a9:aa:
         f0:f0:62:79:ce:43:8c:5f:28:49:ee:a1:d4:16:67:6b:59:c3:
         15:65:e3:d3:3b:35:da:59:35:33:2a:5e:8a:59:ff:14:b9:51:
         a5:8e:0b:7c:1b:a1:b1:f4:89:1a:3f:2f:d7:b1:8d:23:0a:7a:
         79:e1:c2:03:b5:2f:ee:34:16:a9:67:27:b6:10:67:5d:f4:1d:
         d6:b3:e0:ab:80:3d:59:fc:bc:4b:1a:55:fb:36:75:ff:e3:88:
         73:e3:16:4d:2b:17:7b:2a:21:a3:18:14:04:19:b3:b8:11:39:
         55:3f:ce:21:b7:d3:5d:8d:78:d5:3a:e0:b2:17:41:ad:3c:8e:
         a5:a2:ba:eb:3d:b6:9e:2c:ef:7d:d5:cc:71:cb:07:54:21:42:
         81:79:45:2b:93:74:93:a1:c9:f1:5e:5e:11:3d:ac:df:55:98:
         37:44:d2:55:a5:15:a9:33:79:6e:fe:49:6d:e5:7b:a0:1c:12:
         c5:1b:4d:33
```

</details>

**ECDSA (P-256) - self-signed:**

```sh
step certificate create "Smallstep self-signed" cert.ecdsa.pem key.ecdsa.pem \
  --no-password --insecure \
  --profile self-signed --subtle \
  --not-before "2021-01-01T00:00:00+00:00" \
  --not-after "2031-01-01T00:00:00+00:00" \
  --san "example.test" \
  --san "mail.example.test" \
  --kty EC --crv P-256
```

<details>
<summary>Certificate Details:</summary>

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 311463463867833685003701497925006766941 (0xea51ae60cd02784bbf1ba4e367ffb35d)
    Signature Algorithm: ECDSA-SHA256
        Issuer: CN=Smallstep self-signed
        Validity
            Not Before: Jan 1 00:00:00 2021 UTC
            Not After : Jan 1 00:00:00 2031 UTC
        Subject: CN=Smallstep self-signed
        Subject Public Key Info:
            Public Key Algorithm: ECDSA
                Public-Key: (256 bit)
                X:
                    b1:f7:b1:12:75:17:a8:72:9a:39:31:ef:f0:61:b2:
                    f4:0c:88:c6:05:b2:12:f2:99:e0:ac:81:78:4c:72:
                    94:e9
                Y:
                    52:8f:e9:c1:7b:b0:15:83:90:06:30:d2:c0:6b:66:
                    63:31:14:54:28:80:1d:89:6e:a4:2c:dd:59:17:5f:
                    a6:3e
                Curve: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature
            X509v3 Extended Key Usage:
                Server Authentication, Client Authentication
            X509v3 Subject Key Identifier:
                14:9F:BA:EB:14:52:9F:2C:13:B2:E9:F1:77:DA:5B:F6:E2:1D:54:BD
            X509v3 Subject Alternative Name:
                DNS:example.test, DNS:mail.example.test
    Signature Algorithm: ECDSA-SHA256
         30:46:02:21:00:f8:72:3d:90:7e:db:9e:7a:4f:6d:80:fb:fa:
         dc:42:43:e2:dc:8f:6a:ec:18:c5:af:e1:ea:03:fd:66:78:a2:
         01:02:21:00:f7:86:58:81:17:f5:74:5b:14:c8:0f:93:e2:bb:
         b8:e9:90:47:c0:f7:b1:60:82:d9:b4:1a:fc:fa:66:fa:48:5c
```

</details>
