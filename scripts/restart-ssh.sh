#!/bin/bash
echo "Restarting SSH service..."
sudo systemctl restart ssh
echo "SSH service restarted. You can reconnect in VS Code now."