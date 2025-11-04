#!/bin/bash
systemctl disable --now gitbot.service
rm /etc/systemd/system/gitbot.service
rm -rf ~/gitbot
rm /var/log/gitbot*.log