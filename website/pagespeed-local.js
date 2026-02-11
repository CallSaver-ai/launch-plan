#!/usr/bin/env node

/**
 * Local PageSpeed Test using Lighthouse CLI
 * This bypasses API limits by running Lighthouse locally
 */

const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

// Your landing page URL
const URL_TO_TEST = 'http://localhost:3000';

function runLighthouseTest() {
  console.log(`🚀 Running Lighthouse test for: ${URL_TO_TEST}`);
  console.log('This may take 60-90 seconds...\n');

  // Check if Lighthouse is installed
  exec('npx lighthouse --version', (error, stdout) => {
    if (error) {
      console.log('📦 Installing Lighthouse...');
      installLighthouse();
      return;
    }

    runTest();
  });
}

function installLighthouse() {
  exec('npm install -g lighthouse', (error, stdout, stderr) => {
    if (error) {
      console.error('❌ Failed to install Lighthouse:', error.message);
      return;
    }
    console.log('✅ Lighthouse installed successfully');
    runTest();
  });
}

function runTest() {
  const outputPath = path.join(__dirname, 'lighthouse-report.json');
  
  const command = `npx lighthouse "${URL_TO_TEST}" \
    --output=json \
    --output-path="${outputPath}" \
    --chrome-flags="--headless" \
    --quiet \
    --category=performance \
    --category=accessibility \
    --category=best-practices \
    --category=seo \
    --form-factor=mobile`;

  console.log('⏳ Running Lighthouse audit...');

  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error('❌ Lighthouse error:', error.message);
      return;
    }

    // Read and parse the report
    try {
      const report = JSON.parse(fs.readFileSync(outputPath, 'utf8'));
      displayResults(report);
      
      // Clean up the report file
      fs.unlinkSync(outputPath);
    } catch (parseError) {
      console.error('❌ Error reading report:', parseError.message);
    }
  });
}

function displayResults(lhr) {
  console.log('\n📊 Lighthouse Results\n');
  
  // Overall scores
  console.log('🎯 Overall Scores:');
  Object.entries(lhr.categories).forEach(([key, category]) => {
    const score = Math.round(category.score * 100);
    const emoji = score >= 90 ? '🟢' : score >= 50 ? '🟡' : '🔴';
    console.log(`  ${emoji} ${category.title}: ${score}/100`);
  });

  // Core Web Vitals
  console.log('\n⚡ Core Web Vitals:');
  const vitals = lhr.audits;
  console.log(`  📈 Largest Contentful Paint (LCP): ${vitals['largest-contentful-paint'].displayValue}`);
  console.log(`  🎯 First Input Delay (FID): ${vitals['max-potential-fid'].displayValue}`);
  console.log(`  🎨 Cumulative Layout Shift (CLS): ${vitals['cumulative-layout-shift'].displayValue}`);

  // Performance opportunities
  console.log('\n🔧 Top Performance Opportunities:');
  const opportunities = Object.entries(lhr.audits)
    .filter(([key, audit]) => 
      audit.score !== null && 
      audit.score < 1 && 
      audit.details && 
      audit.details.type === 'opportunity'
    )
    .sort(([,a], [,b]) => (a.numericValue || 0) - (b.numericValue || 0))
    .slice(0, 5);

  opportunities.forEach(([key, audit]) => {
    const savings = audit.details?.overallSavingsMs || 0;
    console.log(`  ⏱️  ${audit.title}: Save ~${Math.round(savings)}ms`);
  });

  // Failed audits (things to fix)
  console.log('\n❌ Failed Audits (Priority Fixes):');
  const failedAudits = Object.entries(lhr.audits)
    .filter(([key, audit]) => 
      audit.score !== null && 
      audit.score < 0.9 && 
      !audit.manual
    )
    .sort(([,a], [,b]) => (a.numericValue || 0) - (b.numericValue || 0))
    .slice(0, 10);

  failedAudits.forEach(([key, audit]) => {
    const impact = audit.numericValue || 0;
    console.log(`  🔴 ${audit.title}: ${Math.round(impact)}ms impact`);
    if (audit.description) {
      console.log(`     ${audit.description.substring(0, 100)}...`);
    }
  });

  // Resource summary
  console.log('\n📦 Resource Summary:');
  const resourceSummary = lhr.audits['resource-summary'];
  if (resourceSummary) {
    Object.entries(resourceSummary.details.items[0]).forEach(([type, info]) => {
      if (typeof info === 'object' && info.size) {
        const sizeKB = Math.round(info.size / 1024);
        const count = info.count || 0;
        console.log(`  ${type}: ${sizeKB}KB (${count} files)`);
      }
    });
  }

  // Specific recommendations
  console.log('\n💡 Quick Wins:');
  const quickWins = [
    'unused-css-rules',
    'unused-javascript',
    'render-blocking-resources',
    'offscreen-images',
    'modern-image-formats'
  ];

  quickWins.forEach(auditId => {
    const audit = lhr.audits[auditId];
    if (audit && audit.score < 1) {
      const savings = audit.details?.overallSavingsMs || 0;
      console.log(`  • ${audit.title}: ${Math.round(savings)}ms savings`);
    }
  });

  console.log('\n✅ Test completed!');
}

runLighthouseTest();
