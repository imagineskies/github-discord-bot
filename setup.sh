#!/bin/bash
set -euo pipefail

# Defining an array of packages required to deploy this bot
requiredPrograms=('wget' 'npm' 'nodejs')
installList=()

# Check to see if any packages are not installed. Append missing prograpackagesms to array

for program in "${requiredPrograms[@]}"; do
    if ! command -v "$program" &>/dev/null; then
        installList+=("$program")
    fi
done

# Install any missing packages

if [ ${#installList[@]} -ne 0 ]; then 
    sudo apt update
    sudo apt install -y "${installList[@]}"
fi

# Get node executable 

nodeExe=$(command -v node)

# Now we need to initialize a working directory

wdPrompt="
Where should the working directory be? 
(Default: ~/gitbot)
"
read -p " ${wdPrompt}" workingDirectory

# Default Directory

workingDirectory=${workingDirectory:-"$HOME/gitbot"}

# Create and enter directory

mkdir -p "$workingDirectory" 
cd "$workingDirectory"

# Initalize Node Project and install dependencies

npm init -y
npm install --save dotenv express axios body-parser discord.js

wget -q "https://raw.githubusercontent.com/imagineskies/github-discord-bot/refs/heads/main/index.js" -O index.js

# Create and populate environment variables

touch .env
chmod 600 .env

read -p "Enter a port to listen to:  " listenPort
read -s -p "Enter Webhook ID: " webhookID; echo
read -s -p "Enter Webhook Token: " webhookTKN; echo
read -s -p "Enter Bot Token: " botToken; echo

random_str=$(openssl rand -base64 48 | tr -d '+/=' | head -c 64)

envBody=$(cat <<EOF
GITHUB_SECRET="$random_str"
BOT_TOKEN="$botToken"
WEBHOOK_TOKEN="$webhookTKN"
PORT="$listenPort"
WEBHOOK_ID="$webhookID"
EOF
)
echo "$envBody" >> .env

# Create log files

sudo touch /var/log/gitbot.log
sudo chown $USER:$USER /var/log/gitbot.log
sudo chmod 660 /var/log/gitbot.log

sudo touch /var/log/gitbot-error.log
sudo chown $USER:$USER /var/log/gitbot-error.log
sudo chmod 660 /var/log/gitbot-error.log

# Create systemd file for the discord bot

systemD=$(cat <<EOF
[Unit]
Description=Bot to update discord channel upon changes to a GitHub repo
After=network.target

[Service]
Type=simple
ExecStart=$nodeExe index.js
WorkingDirectory=$workingDirectory
Restart=on-failure
User=$USER
Environment=NODE_ENV=production
StandardOutput=file:/var/log/gitbot.log
StandardError=file:/var/log/gitbot-error.log

[Install]
WantedBy=multi-user.target
EOF
)

echo "$systemD" | sudo tee /etc/systemd/system/gitbot.service > /dev/null


# Reload systemd and start the service

sudo systemctl daemon-reload
sudo systemctl enable --now gitbot.service