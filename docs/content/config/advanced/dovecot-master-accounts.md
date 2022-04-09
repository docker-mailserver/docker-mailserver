---
title: 'Advanced | Dovecot master accounts'
---

## Introduction

A dovecot master account is able to login as any configured user. This is useful for administrative tasks like hot backups.

## Configuration

It is possible to create, update, delete and list dovecot master accounts using `setup.sh`. See `setup.sh help` for usage.

## Logging in

Once a master account is configured, it is possible to connect to any users mailbox using this account. Log in over POP3/IMAP using the following credential scheme:

Username: `<EMAIL ADDRESS>*<MASTER ACCOUNT NAME>`

Password: `<MASTER ACCOUNT PASSWORD>`