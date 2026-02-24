/**
 * Firecrawl Batch Scrape Test Script
 * Sends a batch scrape request to Firecrawl with webhook URL using fetch
 */

import dotenv from 'dotenv';

dotenv.config({ path: '../callsaver-api/.env.local' });

const FIRECRAWL_API_KEY = process.env.FIRECRAWL_API_KEY;

if (!FIRECRAWL_API_KEY) {
  console.error('❌ FIRECRAWL_API_KEY not found in environment');
  process.exit(1);
}

// Get ngrok URL from command line or use default
const ngrokUrl = process.argv[2];

if (!ngrokUrl) {
  console.error('❌ Please provide your ngrok URL as an argument');
  console.error('   Usage: pnpm test:batch <ngrok-url>');
  console.error('   Example: pnpm test:batch https://abc123.ngrok-free.app');
  process.exit(1);
}

const webhookUrl = `${ngrokUrl}/webhooks/firecrawl`;

const urls = [
  'https://oak.plumbing'
];

console.log('🚀 Sending Firecrawl batch scrape request...');
console.log('URLs:', urls.join(', '));
console.log('Webhook URL:', webhookUrl);

async function main() {
  try {
    const response = await fetch('https://api.firecrawl.dev/v2/batch/scrape', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${FIRECRAWL_API_KEY}`
      },
      body: JSON.stringify({
        urls: urls,
        formats: [{ type: 'markdown' }],
        onlyMainContent: true,
        webhook: {
          url: webhookUrl,
          events: ['completed', 'failed'],
          metadata: {
            attioCompanyRecordId: 'test-company-123',
            calBookingUid: 'test-booking-456',
            businessName: 'Oak Plumbing Test'
          }
        }
      })
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`HTTP ${response.status}: ${error}`);
    }

    const result = await response.json();

    console.log('\n✅ Batch scrape submitted:');
    console.log('  ID:', result.id);
    console.log('  Success:', result.success);
    console.log('  URL:', result.url);
    console.log('\n⏳ Waiting for webhook...');
    console.log('   Check your ngrok terminal and the webhook server output');
    
  } catch (error: any) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main();
