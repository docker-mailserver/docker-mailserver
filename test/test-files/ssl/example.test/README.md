# Testing certificates for TLS

Use these certificates for any tests that require a certificate during a test. **DO NOT USE IN PRODUCTION**.

These certificates for usage with TLS have been generated via the [Smallstep `step certificate`](https://smallstep.com/docs/step-cli/reference/certificate/create) CLI tool. They have a duration of 10 years and are valid for the SAN `example.test` or it's `mail` subdomain.

`Certificate Details` sections are the output of: `step certificate inspect cert.<key type>.pem`.

Each certificate except for the wildcard one, have the SANs(Subject Alternative Name) `example.test` and `mail.example.test`.

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

<!-- markdownlint-disable MD033 MD040 -->
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
<!-- markdownlint-enable MD033 MD040 -->

---

`self-signed` certs lacks a chain of trust for verifying a certificate. See `test/mail_ssl_manual.bats` which covers verification test.

The minimal setup to satisfy verification is adding a Root CA (self-signed) that is used to sign the server certificate (leaf cert):

Create an ECDSA Root CA cert:

```sh
step certificate create "Smallstep Root CA" ca-cert.ecdsa.pem ca-key.ecdsa.pem \
  --no-password --insecure \
  --profile root-ca \
  --not-before "2021-01-01T00:00:00+00:00" \
  --not-after "2031-01-01T00:00:00+00:00" \
  --san "example.test" \
  --san "mail.example.test" \
  --kty EC --crv P-256
```

Create an ECDSA Leaf cert, signed with the Root CA key we just created:

```sh
step certificate create "Smallstep Leaf" cert.ecdsa.pem key.ecdsa.pem \
  --no-password --insecure \
  --profile leaf \
  --ca ca-cert.ecdsa.pem \
  --ca-key ca-key.ecdsa.pem \
  --not-before "2021-01-01T00:00:00+00:00" \
  --not-after "2031-01-01T00:00:00+00:00" \
  --san "example.test" \
  --san "mail.example.test" \
  --kty EC --crv P-256
```

The Root CA certificate does not need to have the same key type as the Leaf certificate, you can mix and match if necessary (eg: an ECDSA and an RSA leaf certs with shared ECDSA Root CA cert).

<!-- markdownlint-disable MD033 MD040 -->
<details>
<summary>Certificate Details (signed by Root CA key):</summary>

`step certificate inspect with_ca/ecdsa/cert.ecdsa.pem`:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 28540880372304824564361820670143583738 (0x1578c60b9eedca127fe041712f9d55fa)
    Signature Algorithm: ECDSA-SHA256
        Issuer: CN=Smallstep Root CA
        Validity
            Not Before: Jan 1 00:00:00 2021 UTC
            Not After : Jan 1 00:00:00 2031 UTC
        Subject: CN=Smallstep Leaf
        Subject Public Key Info:
            Public Key Algorithm: ECDSA
                Public-Key: (256 bit)
                X:
                    b6:64:18:5f:f6:3f:b6:b1:da:09:00:27:e9:70:4e:
                    8e:11:c4:58:8d:02:a2:46:f6:5b:d5:12:9b:ea:6a:
                    e4:39
                Y:
                    87:56:d8:43:6b:4d:5d:4a:44:73:d2:81:34:1d:cd:
                    de:53:ed:62:c4:61:76:c6:bf:96:0a:0a:8e:10:fa:
                    c2:63
                Curve: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature
            X509v3 Extended Key Usage:
                Server Authentication, Client Authentication
            X509v3 Subject Key Identifier:
                48:C4:A2:B2:31:9B:9C:3D:4D:BD:58:45:60:F0:C6:16:EB:74:C0:3B
            X509v3 Authority Key Identifier:
                keyid:3F:3D:65:1A:72:82:16:C6:20:E8:B6:FC:1B:2E:6D:A4:9C:2C:92:78
            X509v3 Subject Alternative Name:
                DNS:example.test, DNS:mail.example.test
    Signature Algorithm: ECDSA-SHA256
         30:46:02:21:00:b6:dc:7d:ba:f6:d9:b1:3f:28:4d:6d:4c:a4:
         e9:c5:24:80:d4:6c:a5:fc:9f:74:4e:9a:bb:5b:ca:8a:5e:dd:
         32:02:21:00:e2:c8:8b:1b:be:a2:f9:5f:cd:41:8c:0a:75:71:
         ca:e9:be:65:d1:ca:5e:50:77:f7:8a:c0:f8:03:77:1b:53:0a
```

</details>

<details>
<summary>Root CA Certificate Details (self-signed):</summary>

`step certificate inspect with_ca/ecdsa/ca-cert.ecdsa.pem`:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 83158808788179848488617675347018882219 (0x3e8fcdd2d80ab546924c05b4d9339cab)
    Signature Algorithm: ECDSA-SHA256
        Issuer: CN=Smallstep Root CA
        Validity
            Not Before: Jan 1 00:00:00 2021 UTC
            Not After : Jan 1 00:00:00 2031 UTC
        Subject: CN=Smallstep Root CA
        Subject Public Key Info:
            Public Key Algorithm: ECDSA
                Public-Key: (256 bit)
                X:
                    76:30:c0:21:d2:6c:6b:ca:de:be:1d:c3:5c:67:08:
                    93:bf:73:53:2a:23:5d:d8:06:2a:8b:09:bc:39:fd:
                    0b:0d
                Y:
                    a7:74:1f:7c:b9:95:73:6c:ba:00:00:d7:52:06:0c:
                    e9:00:c8:aa:bb:e1:50:e7:ec:ff:bf:e5:30:bb:9b:
                    18:07
                Curve: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE, pathlen:1
            X509v3 Subject Key Identifier:
                3F:3D:65:1A:72:82:16:C6:20:E8:B6:FC:1B:2E:6D:A4:9C:2C:92:78
    Signature Algorithm: ECDSA-SHA256
         30:45:02:21:00:bf:d7:51:c7:7b:67:41:90:ac:c5:89:cd:04:
         60:7d:6b:da:8d:75:c2:c6:1c:18:93:82:79:96:35:19:a4:ea:
         2f:02:20:5a:bc:95:3b:de:f6:8b:00:fd:1a:69:81:57:b5:b6:
         91:0f:10:ef:2b:b2:39:83:c0:3c:a0:26:21:51:4b:40:3c
```

</details>
<!-- markdownlint-enable MD033 MD040 -->

**ECDSA (P-256) - wildcard:**

This one is for testing the wildcard san `*.example.test`:

```sh
# Run at `example.test/with_ca/ecdsa/`:
step certificate create "Smallstep Leaf" wildcard/cert.ecdsa.pem wildcard/key.ecdsa.pem \
  --no-password --insecure \
  --profile leaf \
  --ca ca-cert.ecdsa.pem \
  --ca-key ca-key.ecdsa.pem \
  --not-before "2021-01-01T00:00:00+00:00" \
  --not-after "2031-01-01T00:00:00+00:00" \
  --san "*.example.test" \
  --kty EC --crv P-256
```

---

When bundling chain of trust into a single certificate file (eg: `fullchain.pem`), starting with the server cert, include any additional parent certificates in the chain - but do not add the final Root CA cert; otherwise you'll get a related error with not being able to verify trust:

```sh
$ openssl s_client -connect mail.example.test:587 -starttls smtp

# Verification error: self signed certificate in certificate chain
```

Thus, the minimal bundle would be `leaf->intermediate` (`fullchain.pem`) with separate Root CA cert.
