#!/bin/bash
export PATH="/root/.rbenv/bin:/root/.rbenv/shims:$PATH"
cd /root/chatwoot
bin/rails runner /mnt/f/Digilunar/Project/indosiaraya-app/chatwoot/check_knowledge.rb
