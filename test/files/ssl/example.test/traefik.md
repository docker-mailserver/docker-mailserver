# Traefik `acme.json` test files

Traefik encodes it's provisioned certificates into `acme.json` instead of separate files, but there is nothing special about the storage or content.

Each `*.acme.json` file provides base64 encoded representations of their equivalent cert and key files at the same relative location.

The only relevant content being tested from these `acme.json` files is in `le.Certificates`, everything else is only placeholder values.

---

Certificates have been encoded into base64 for `acme.json` files from the `example.test/with_ca/{ecdsa,rsa}/` folders:

- Those folders each provide a Root CA cert which functions similar to _Let's Encrypt_ role for verification of the chain of trust. All leaf certificates are signed by the Root CA key file located in these two folders.
- Leaf certificates are the kind you'd get provisioned normally via a service like _Let's Encrypt_ to use with your own server. These are available in both ECDSA and RSA, where those in `with_ca/rsa/` are valid for both FQDNs `mail.example.test` and `example.test` as SANs; but those in `with_ca/ecdsa/` are restricted to one FQDN.
- Each `acme.json` file lists the supported FQDNs in the `sans` field. Presently `main` is always `Smallstep Leaf`, which is associated to the certificate "Subject CN", which was often used for an FQDN in the past prior to SAN support. `main` can still provide a valid FQDN, but none of the test `acme.json` have a matching cert to test against.
- There is also two wildcard configs, where the only difference is a pure ECDSA or RSA chain for `*.example.test`.These are valid for subdomains of `example.test` such as: `mail.example.test`, but not `example.test` itself.

---

Encode and decode certs easily via the [`step base64`](https://smallstep.com/docs/step-cli/reference/base64) command:

- Decode: `echo 'YmFzZTY0IGVuY29kZWQgc3RyaW5nCg==' | step base64 -d`
  Optionally write the output to a file: `> example.test/with_ca/ecdsa/cert.rsa.pem`
- Encode: `cat example.test/with_ca/ecdsa/cert.rsa.pem | step base64`
- Inspect the PEM encoded data: `step certificate inspect example.test/with_ca/ecdsa/cert.rsa.pem`
  Note: `step certificate inspect` will only work with valid PEM encoded files, not the example base64 value to decode here.
