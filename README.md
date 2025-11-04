# GitHub to Discord Webook Bot

A fast an easy way to get realtime updates from a GitHub repository inside a Discord channel.

---

## Prerequisites

- Debian based linux system
- A valid Discord bot token and webhook url.
- Permissions for configuring GitHub repository webhooks
- A domain name

## Installation & Use

### Domain Name

You will need a domain name in case you don't already have one. Namecheap sells really cheap domains and you can get a .xyz TLD for a couple of dollars. One you have a domain name, create one A record that points to your public IP address. It can take up to 24 hours for DNS records to sync, but this typically is completed in minutes. You can check using the dig command on linux and checking the answer section.

### Run install script

Once you have a domain pointing at your IP address, run the following setup script. It will ensure all required programs are installed, initalize node, install the requiured node packages, save environment variables, create systemd service, and configure reverse proxy.

```shell
curl -fsSL "https://raw.githubusercontent.com/imagineskies/github-discord-bot/refs/heads/main/install.sh" | bash
```

#### Required Information

1. Port: Can be any number between 1024 and 65535.
2. Webhook URL: You can read Discord's support page [here](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) to learn how to make a webhook. Once created, you will need to enter the webhook url into the shell script.
3. Bot Token: Once you have a Discord application created in the Developer Portal, in the settings to the Bot tab. Click the *Reset Token* button, and you will be presented with your bot token.
4. Domain name: You will also be asked to provide a domain name. This is then used in the reverse proxy and provided to certbot for generating TLS certificate.

## Uninstallation

To remove the bot and it's associated files, run the following script.

```shell
curl -fsSL "https://raw.githubusercontent.com/imagineskies/github-discord-bot/refs/heads/main/uninstall.sh" | sudo bash
```