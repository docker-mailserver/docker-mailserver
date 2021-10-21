# Traefik `acme.json` test files

Each `acme.json` test file has base64 encoded cert and key files from the sibling folder `example.test/`. Traefik encodes it's provisioned certificates into `acme.json` instead of separate files, but there is nothing special about the storage or content.

In the `acme.json` files, the only relevant content being tested is in `le.Certificates`, everything else is only placeholder.

---

Certificates have been encoded into base64 for `acme.json` files from the `example.test/with_ca/ecdsa/` folder:

- That folder provides a Root CA which functions similar to _Let's Encrypt_ role for verification of the chain of trust, with the `ecdsa/` folder being the Root CA cert as an ECDSA type (as opposed to the sibling `rsa/` folder for RSA).
- Then there is the leaf certificates, which are the ones you'd get provisioned normally via a service like _Let's Encrypt_ to use with your own server. These are available in both ECDSA and RSA which are both valid for `mail.example.test` and `example.test` as SANs.
- The `ecdsa/` folder also includes `ecdsa/wildcard/` for a wildcard variant. This has only been provisioned for an ECDSA leaf certificate, with the SAN `*.example.test` which is valid for subdomains of `example.test` such as: `mail.example.test`. The associated `acme.json` does list `main: 'example.test'` but this certificate should not support that FQDN as it's only intended to test subdomains.

---

Encode and decode certs easily via the [`step base64`](https://smallstep.com/docs/step-cli/reference/base64) command:

- Decode: `echo 'YmFzZTY0IGVuY29kZWQgc3RyaW5nCg==' | step base64 -d`
  Optionally write the output to a file: `> example.test/with_ca/ecdsa/cert.rsa.pem`
- Encode: `cat example.test/with_ca/ecdsa/cert.rsa.pem | step base64`
- Inspect the PEM encoded data: `step certificate inspect example.test/with_ca/ecdsa/cert.rsa.pem`
  Note: `inspect` will only work with valid PEM encoded files, not the example base64 value to decode here.
