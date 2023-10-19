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
  --san "mail.example.test" \
  --kty EC --crv P-256
```

The Root CA certificate does not need to have the same key type as the Leaf certificate, you can mix and match if necessary (eg: an ECDSA and an RSA leaf certs with shared ECDSA Root CA cert).

Both FQDN continue to be assigned as SAN to certs in `with_ca/rsa/`, while certs in `with_ca/ecdsa/` are limited to `mail.example.test` for ECDSA, and `example.test` for RSA. This is to provide a bit more flexibility in test cases where specific FQDN support is required.

<!-- markdownlint-disable MD033 MD040 -->
<details>
<summary>Certificate Details (signed by Root CA ECDSA key):</summary>

`step certificate inspect with_ca/ecdsa/cert.ecdsa.pem`:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 39948191589315458296429918694374173514 (0x1e0dbde943f3ab4144909744cd58eb4a)
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
                    f4:5b:00:6a:6a:ca:1d:b8:15:80:81:d0:82:72:be:
                    af:3a:3c:5e:a7:9b:64:21:16:19:27:f3:75:0b:eb:
                    e0:fe
                Y:
                    47:6a:6c:9e:d7:da:80:0e:1b:09:76:45:fe:8b:fd:
                    79:09:f7:08:22:1a:93:20:21:74:5e:78:91:53:45:
                    9e:71
                Curve: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature
            X509v3 Extended Key Usage:
                Server Authentication, Client Authentication
            X509v3 Subject Key Identifier:
                D8:BE:56:52:27:E7:90:B0:21:5B:5F:79:D8:F8:D4:85:57:F0:2B:BC
            X509v3 Authority Key Identifier:
                keyid:DE:90:B3:B9:4D:C1:B3:EE:77:00:88:8B:69:EC:71:C4:30:F9:F6:7F
            X509v3 Subject Alternative Name:
                DNS:mail.example.test
    Signature Algorithm: ECDSA-SHA256
        30:46:02:21:00:ad:08:7b:f0:82:41:2e:0e:cd:2b:f7:95:fd:
        ee:73:d9:93:8d:74:7c:ef:29:4d:d5:da:33:04:f0:b6:b1:6b:
        13:02:21:00:d7:f1:95:db:be:18:b8:db:77:b9:57:07:e6:b9:
        5a:3d:00:34:d3:f5:eb:18:67:9b:ba:bf:88:62:72:e9:c9:99
```

</details>

<details>
<summary>Root CA Certificate Details (self-signed):</summary>

`step certificate inspect with_ca/ecdsa/ca-cert.ecdsa.pem`:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 91810308658606804773211369549707991484 (0x451205b3271cead885a8ea9c5c21d9bc)
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
                    cf:62:31:60:19:3d:72:78:60:59:1e:27:13:dd:cf:
                    d9:11:36:28:32:af:fa:28:e4:0e:6e:ab:4b:ad:a2:
                    49:00
                Y:
                    dc:6c:89:09:98:fa:f7:f2:8d:ed:50:53:db:cf:6d:
                    4f:ce:9d:1a:61:97:c5:80:72:5e:26:34:4a:bb:cb:
                    81:8c
                Curve: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE, pathlen:1
            X509v3 Subject Key Identifier:
                DE:90:B3:B9:4D:C1:B3:EE:77:00:88:8B:69:EC:71:C4:30:F9:F6:7F
    Signature Algorithm: ECDSA-SHA256
        30:44:02:20:3f:3b:90:e7:ca:82:70:8e:3f:2e:72:2a:b9:27:
        46:ac:e9:e2:4a:db:56:02:bc:a2:b2:99:e4:8d:10:7a:d5:73:
        02:20:72:25:64:b6:1c:aa:a6:c3:14:e1:66:35:bf:a1:db:90:
        ea:49:59:f9:44:e8:63:de:a8:c0:bb:9b:21:08:59:87
```

</details>
<!-- markdownlint-enable MD033 MD040 -->

**Wildcard Certificates:**

This is for testing the wildcard SAN `*.example.test`.

Both `with_ca/{ecdsa,rsa}/` directories contain a wildcard cert. The only difference is the Root CA cert used, and the entire chain being purely ECDSA or RSA type.

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

<!-- markdownlint-disable MD033 MD040 -->
<details>
<summary>Certificate Details (signed by Root CA ECDSA key):</summary>

`step certificate inspect with_ca/ecdsa/wildcard/cert.ecdsa.pem`:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 15398717504679308720407721522825999382 (0xb95af63ae03a90f3bd5a6a740133416)
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
                    2f:44:73:14:e4:e8:9a:88:a1:96:82:be:f3:e5:8b:
                    94:a4:8a:ec:18:c1:73:86:cf:15:8a:e8:05:bd:46:
                    71:cf
                Y:
                    a1:bd:36:84:d0:b8:b3:15:f4:73:e2:53:87:0d:cd:
                    e8:a5:42:9a:94:91:d8:a3:d4:e1:d1:77:5a:cb:da:
                    89:ea
                Curve: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature
            X509v3 Extended Key Usage:
                Server Authentication, Client Authentication
            X509v3 Subject Key Identifier:
                CA:A0:95:BE:58:73:6C:1D:EA:50:B8:BF:34:FF:D3:F1:63:33:1F:6F
            X509v3 Authority Key Identifier:
                keyid:DE:90:B3:B9:4D:C1:B3:EE:77:00:88:8B:69:EC:71:C4:30:F9:F6:7F
            X509v3 Subject Alternative Name:
                DNS:*.example.test
    Signature Algorithm: ECDSA-SHA256
        30:46:02:21:00:f2:50:c0:b5:c9:24:e5:e9:36:a6:7b:35:5d:
        38:a7:7d:81:af:02:fc:9d:fd:79:f4:2d:4c:8a:04:55:44:a8:
        3a:02:21:00:b1:2d:d2:25:18:2d:35:19:20:97:78:f1:d5:18:
        9f:11:d5:97:a9:dc:64:95:2a:6c:9d:4e:78:69:c1:92:23:23
```

</details>
<!-- markdownlint-enable MD033 MD040 -->

---

When bundling chain of trust into a single certificate file (eg: `fullchain.pem`), starting with the server cert, include any additional parent certificates in the chain - but do not add the final Root CA cert; otherwise you'll get a related error with not being able to verify trust:

```sh
$ openssl s_client -connect mail.example.test:587 -starttls smtp

# Verification error: self signed certificate in certificate chain
```

Thus, the minimal bundle would be `leaf->intermediate` (`fullchain.pem`) with separate Root CA cert.
