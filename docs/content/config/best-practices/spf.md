> Sender Policy Framework (SPF) is a simple email-validation system designed to detect email spoofing by providing a mechanism to allow receiving mail exchangers to check that incoming mail from a domain comes from a host authorized by that domain's administrators. The list of authorized sending hosts for a domain is published in the Domain Name System (DNS) records for that domain in the form of a specially formatted TXT record. Email spam and phishing often use forged "from" addresses, so publishing and checking SPF records can be considered anti-spam techniques.

To add a SPF record in your DNS, insert the following line in your DNS zone:

    ; Check that MX is declared
    domain.com. IN  MX 1 mail.domain.com.

    ; Add SPF record
    domain.com. IN TXT "v=spf1 mx ~all" 

Increment DNS serial and reload configuration.