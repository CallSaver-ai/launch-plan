/**
 * Local Firecrawl Webhook Test Server
 * Tests the webhook signature verification and payload parsing
 */

import express from 'express';
import crypto from 'crypto';
import dotenv from 'dotenv';

dotenv.config({ path: '../callsaver-api/.env.local' });

const app = express();
const PORT = 3000;

// Firecrawl webhook handler using express.raw
app.post('/webhooks/firecrawl', express.raw({ type: 'application/json' }), async (req, res) => {
  console.log('\n📥 Firecrawl webhook received');
  console.log('Content-Type:', req.headers['content-type']);
  console.log('req.body type:', typeof req.body);
  console.log('req.body instanceof Buffer:', req.body instanceof Buffer);
  
  try {
    // Step 1: Verify X-Firecrawl-Signature (HMAC-SHA256)
    const webhookSecret = process.env.FIRECRAWL_WEBHOOK_SECRET;
    const signature = req.get('X-Firecrawl-Signature');
    
    console.log('\n🔐 Signature verification:');
    console.log('  Webhook secret exists:', !!webhookSecret);
    console.log('  Signature header:', signature);

    // req.body is a Buffer when using express.raw()
    const bodyBuffer = req.body;
    console.log('  bodyBuffer length:', bodyBuffer?.length || 0);

    if (webhookSecret && signature) {
      const [algorithm, hash] = signature.split('=');
      if (algorithm !== 'sha256' || !hash) {
        console.error('❌ Invalid signature format');
        return res.status(401).json({ error: 'Invalid signature format' });
      }
      
      console.log('  Algorithm:', algorithm);
      console.log('  Hash length:', hash?.length);
      
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(bodyBuffer)
        .digest('hex');
      
      console.log('  Expected sig length:', expectedSignature.length);
      
      try {
        if (!crypto.timingSafeEqual(Buffer.from(hash, 'hex'), Buffer.from(expectedSignature, 'hex'))) {
          console.error('❌ Signature mismatch');
          return res.status(401).json({ error: 'Invalid signature' });
        }
        console.log('✅ Signature verified');
      } catch (e) {
        console.error('❌ Signature comparison error:', e);
        return res.status(401).json({ error: 'Invalid signature' });
      }
    } else {
      console.log('⚠️ Skipping signature verification (no secret or signature)');
    }

    // Step 2: Parse payload
    console.log('\n📋 Parsing payload:');
    console.log('  bodyBuffer type:', bodyBuffer?.constructor?.name);
    
    const payload = JSON.parse(bodyBuffer.toString('utf8'));
    console.log('✅ Payload parsed successfully');
    console.log('  Event type:', payload.type);
    console.log('  ID:', payload.id);
    console.log('  Success:', payload.success);
    console.log('  Data count:', payload.data?.length || 0);

    // Only process batch_scrape.completed events
    if (payload.type !== 'batch_scrape.completed') {
      console.log(`   ℹ️ Ignoring event type: ${payload.type}`);
      return res.status(200).json({ status: 'ignored' });
    }

    // Extract metadata
    const metadata = payload.metadata || {};
    const attioCompanyRecordId = metadata.attioCompanyRecordId;
    const calBookingUid = metadata.calBookingUid;
    const businessName = metadata.businessName;

    console.log('\n📦 Metadata:');
    console.log('  attioCompanyRecordId:', attioCompanyRecordId);
    console.log('  calBookingUid:', calBookingUid);
    console.log('  businessName:', businessName);

    if (!attioCompanyRecordId || !calBookingUid || !businessName) {
      console.error('❌ Missing required metadata', { metadata });
      return res.status(400).json({ error: 'Missing required metadata' });
    }

    const batchId = payload.id;
    console.log('\n✅ Webhook valid, batchId:', batchId);

    // Return 200 immediately
    res.status(200).json({ status: 'received', batchId });

    // Step 4: Process asynchronously
    console.log('\n🔄 Would process asynchronously with processFirecrawlWebhook()');
    console.log('   (skipping actual extraction for local test)');

    return;
  } catch (error) {
    console.error('\n❌ Error processing Firecrawl webhook:', error);
    res.status(500).json({ error: 'Internal server error', message: error.message });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Simple HTML test page
app.get('/', (req, res) => {
  res.send(`
    <h1>Firecrawl Webhook Test Server</h1>
    <p>Server is running on port ${PORT}</p>
    <p>Webhook endpoint: POST /webhooks/firecrawl</p>
    <p>Health check: <a href="/health">/health</a></p>
    <hr>
    <h2>Test Instructions:</h2>
    <ol>
      <li>Start ngrok: <code>ngrok http 3000</code></li>
      <li>Copy the https URL from ngrok</li>
      <li>Configure Firecrawl webhook URL to: <code>{ngrok-url}/webhooks/firecrawl</code></li>
      <li>Trigger a batch scrape from Firecrawl dashboard</li>
    </ol>
  `);
});

app.listen(PORT, () => {
  console.log(`\n🚀 Firecrawl webhook test server running on http://localhost:${PORT}`);
  console.log(`\nTo test with ngrok:`);
  console.log(`  ngrok http ${PORT}`);
  console.log(`\nThen configure Firecrawl webhook to:`);
  console.log(`  https://{your-ngrok-subdomain}.ngrok-free.app/webhooks/firecrawl`);
  console.log(`\nFirecrawl webhook secret configured:`, !!process.env.FIRECRAWL_WEBHOOK_SECRET);
  console.log(`\n---`);
});
