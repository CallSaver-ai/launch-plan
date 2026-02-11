#!/usr/bin/env node

/**
 * PageSpeed Insights Test Script
 * Run this to get detailed performance metrics for your landing page
 */

const https = require('https');

// PageSpeed Insights API endpoint (public, no key required)
const API_URL = 'https://www.googleapis.com/pagespeedonline/v5/runPagespeed';

// Your landing page URL
const URL_TO_TEST = 'https://callsaver.ai';

function runPageSpeedTest() {
  console.log(`🚀 Running PageSpeed Insights test for: ${URL_TO_TEST}`);
  console.log('This may take 30-60 seconds...\n');

  const requestUrl = `${API_URL}?url=${encodeURIComponent(URL_TO_TEST)}&category=performance&category=accessibility&category=best-practices&category=seo&strategy=mobile`;

  https.get(requestUrl, (res) => {
    let data = '';

    res.on('data', (chunk) => {
      data += chunk;
    });

    res.on('end', () => {
      try {
        const result = JSON.parse(data);
        
        if (result.error) {
          console.error('❌ API Error:', result.error.message);
          if (result.error.details) {
            console.error('Details:', result.error.details);
          }
          return;
        }

        // Display results
        console.log('📊 PageSpeed Insights Results\n');
        
        const lighthouse = result.lighthouseResult;
        const categories = lighthouse.categories;
        
        // Overall scores
        console.log('🎯 Overall Scores:');
        Object.entries(categories).forEach(([key, category]) => {
          const score = Math.round(category.score * 100);
          const emoji = score >= 90 ? '🟢' : score >= 50 ? '🟡' : '🔴';
          console.log(`  ${emoji} ${category.title}: ${score}/100`);
        });

        // Core Web Vitals
        console.log('\n⚡ Core Web Vitals:');
        const vitals = lighthouse.audits;
        console.log(`  📈 Largest Contentful Paint (LCP): ${vitals['largest-contentful-paint'].displayValue}`);
        console.log(`  🎯 First Input Delay (FID): ${vitals['max-potential-fid'].displayValue}`);
        console.log(`  🎨 Cumulative Layout Shift (CLS): ${vitals['cumulative-layout-shift'].displayValue}`);

        // Performance opportunities
        console.log('\n🔧 Top Performance Opportunities:');
        const opportunities = Object.entries(lighthouse.audits)
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
        const failedAudits = Object.entries(lighthouse.audits)
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
        const resourceSummary = lighthouse.audits['resource-summary'];
        if (resourceSummary) {
          Object.entries(resourceSummary.details.items[0]).forEach(([type, info]) => {
            if (typeof info === 'object' && info.size) {
              const sizeKB = Math.round(info.size / 1024);
              const count = info.count || 0;
              console.log(`  ${type}: ${sizeKB}KB (${count} files)`);
            }
          });
        }

        console.log('\n✅ Test completed!');

      } catch (error) {
        console.error('❌ Error parsing results:', error.message);
      }
    });
  }).on('error', (error) => {
    console.error('❌ Request error:', error.message);
  });
}


runPageSpeedTest();
