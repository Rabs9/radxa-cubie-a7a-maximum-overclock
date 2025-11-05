#!/bin/bash
HOST="$1"
MAX_ATTEMPTS=30
DELAY=10

echo "Waiting for SSH to become available on $HOST..."
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
    if nc -z -w5 "$HOST" 22 2>/dev/null; then
        echo "SSH is available! Connecting..."
        sleep 5  # Give sshd a moment to fully initialize
        ssh "$HOST"
        exit 0
    fi
    echo "Attempt $i/$MAX_ATTEMPTS - SSH not available yet, waiting ${DELAY}s..."
    sleep $DELAY
done
echo "Timeout waiting for SSH to become available"
exit 1