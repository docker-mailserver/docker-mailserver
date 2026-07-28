# Mirrors `_arg_expect_mail_account` (target/scripts/helpers/database/manage/postfix-accounts.sh):
# just requires a local part and a domain part, no deliverability checks. Using `EmailStr` instead
# would reject reserved TLDs like `.test`/`.example` that this project's own docs/tests use.
MAIL_ACCOUNT_PATTERN = r"^[^@\s]+@[^@\s]+$"
