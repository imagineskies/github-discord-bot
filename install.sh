#!/bin/bash
set -euo pipefail

# Defining an array of packages required to deploy this bot
requiredPrograms=('wget' 'npm' 'nodejs' 'nginx')
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

read -p "Enter a port to listen to:  " listenPort; echo
read -s -p "Enter Webhook URL: " webhookURL; echo
read -s -p "Enter Bot Token: " botToken; echo

random_str=$(openssl rand -base64 48 | tr -d '+/=' | head -c 64)

envBody=$(cat <<EOF
GITHUB_SECRET="$random_str"
BOT_TOKEN="$botToken"
PORT="$listenPort"
DISCORD_WEBHOOK_URL="$webhookURL"
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


# Request domain name from user
read -p "Enter your domain name: " domainName


# Create log files
gitBotAccessDir="/var/log/nginx/gitbot-access.log"
gitBotErrorDir="/var/log/nginx/gitbot-error.log"

sudo touch "$gitBotAccessDir"
sudo chown $USER:$USER "$gitBotAccessDir"
sudo chmod 660 "$gitBotAccessDir"

sudo touch "$gitBotErrorDir"
sudo chown $USER:$USER "$gitBotErrorDir"
sudo chmod 660 "$gitBotErrorDir"

# Create reverse proxy config file
reverseProx=$(cat <<EOF
server {
    server_name "$domainName";

    access_log "$gitBotAccessDir";
    error_log "$gitBotErrorDir";

    client_max_body_size 50M;

    location / {

        proxy_pass http://127.0.0.1:3000;

    }
}
EOF
)
echo "$reverseProx" | sudo tee /etc/nginx/sites-available/gitbot.conf > /dev/null

# Create symlink between available and enabled sites
sudo ln -s /etc/nginx/sites-available/gitbot.conf /etc/nginx/sites-enabled/gitbot.conf

# Restart nginx to load changes
sudo service nginx restart

# Generate TLS Certificate
sudo certbot --nginx -d "$domainName"