require ["fileinto", "copy"];

if address :contains ["From"] "spam@spam.com" {
   fileinto :copy "INBOX";
}

