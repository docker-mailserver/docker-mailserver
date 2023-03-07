require ["fileinto","mailbox"];

if anyof (header :contains "X-Spam-Flag" "YES",
          header :contains "X-Spam" "Yes") {
    fileinto "Junk";
}
