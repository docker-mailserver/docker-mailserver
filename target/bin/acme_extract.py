#!/usr/bin/env python3
import argparse,json

parser = argparse.ArgumentParser(description='Traefik acme.json key and cert extractor utility.')
parser.add_argument('filepath', metavar='<filepath>', help='Path to acme.json')
parser.add_argument('fqdn',     metavar='<FQDN>',     help="FQDN to match in a certificates 'main' or 'sans' field")

# Only one of these options can be used at a time, `const` is the key value that will be queried:
key_or_cert = parser.add_mutually_exclusive_group(required=True)
key_or_cert.add_argument('--key',  dest='requested', action='store_const', const='key',         help='Output the key data to stdout')
key_or_cert.add_argument('--cert', dest='requested', action='store_const', const='certificate', help='Output the cert data to stdout')

args = parser.parse_args()

def has_fqdn(domains, fqdn):
    main = domains.get('main', '')
    sans = domains.get('sans', [])
    return main == fqdn or fqdn in sans

# Searches the acme.json data for the target FQDN,
# upon a match returns the requested key or cert:
def retrieve_data():
    with open(args.filepath) as json_file:
        acme_data = json.load(json_file)
        for key, value in acme_data.items():
            try:
                certs = value['Certificates'] or []
                for cert in certs:
                    if has_fqdn(cert['domain'], args.fqdn):
                        return cert[args.requested]
            # One of the expected keys is missing.. return an empty result
            # Certificates: [{domain: [main, sans], key, certificate}]
            except KeyError:
                return None

# No match == 'None', we convert to empty string for
# existing error handling:
result = retrieve_data() or ''
print(result)
