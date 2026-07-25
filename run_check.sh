#!/bin/bash
export PATH="/root/.rbenv/bin:/root/.rbenv/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
cd /root/chatwoot
bundle exec rails runner /mnt/f/Digilunar/Project/indosiaraya-app/chatwoot/check_scripts.rb
