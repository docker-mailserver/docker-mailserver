require ["fileinto", "reject"];

if address :contains ["From"] "spam@spam.com" {
   fileinto "INBOX.spam";
} else {
     keep;
}

