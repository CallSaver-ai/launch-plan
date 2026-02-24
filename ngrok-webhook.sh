#!/bin/bash
# Start ngrok tunnel for local Firecrawl webhook testing
# Usage: ./ngrok-webhook.sh

echo "🚀 Starting ngrok tunnel for Firecrawl webhook testing..."
echo ""
echo "Requirements:"
echo "  1. Install ngrok: https://ngrok.com/download"
echo "  2. Authenticate: ngrok config add-authtoken YOUR_TOKEN"
echo ""
echo "Once ngrok is running, configure Firecrawl webhook URL:"
echo "  https://{your-subdomain}.ngrok-free.app/webhooks/firecrawl"
echo ""
echo "Starting ngrok on port 3000..."
echo ""

ngrok http 3000
