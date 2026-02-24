# Updated Plan: Integrating Lead Gen Pipeline into Cal.com Booking Pipeline

## Overview
Transform the Python-based lead generation pipeline into JavaScript/TypeScript and integrate it directly into the Cal.com booking pipeline after Google Place Details enrichment.

## Phase 1: Attio Schema Setup

### 1.1 Add New Company Attributes
Add to `~/callsaver-attio-crm-schema/Company/setup_attio_attributes.js`:

```javascript
{
    name: 'target_urls',
    type: 'multi-select',
    description: 'Target URLs identified for website extraction (backup for retry/re-crawl)'
},
{
    name: 's3_google_place_details_url',
    type: 'text',
    description: 'S3 URL to Google Place Details JSON (s3://callsaver-business-profiles/{record_id}/google_place_details.json)'
}
```

**Note:** The `s3_google_place_details_url` attribute was missed in the original Phase 1 Cal.com pipeline implementation. The pipeline already uploads `google_place_details.json` to S3 but doesn't store the URL in Attio. This needs to be added to:
1. The Attio schema setup script
2. The `cal-booking-pipeline.ts` enrichment step to update Attio with the S3 URL after upload

### 1.2 Existing Attributes to Use
- `last_extraction_attempt_at` - Already exists (for tracking extraction attempts)
- `s3_website_extraction_url` - Already exists (for storing S3 URL to extracted data)
- `has_sitemap` - Already exists (for sitemap status)
- `website_discovery_method` - Already exists (will use: `['url_seeding', 'failed']`) - **Updated to use Crawl4AI URL Seeding**

### 1.3 Run Setup Script
Execute the attributes setup script to create the new `target_urls` field in Attio.

## Phase 2: Website Discovery with URL Seeding

**Key Change:** Instead of manual sitemap detection + LLM classification, we use Crawl4AI's built-in URL Seeding feature which provides:
- Automatic sitemap discovery and parsing (including sitemap indexes)
- BM25 relevance scoring (10,000+ URLs/second - no LLM cost!)
- Metadata extraction from page `<head>` tags
- Automatic filtering of nonsense URLs (robots.txt, .js, .css, media files)
- Built-in caching with TTL

### 2.1 URL Seeding Query Terms

Query terms aligned with our extraction schema fields:

```typescript
// Query terms for BM25 scoring - aligned with WebsiteExtractionProfile schema
const URL_SEEDING_QUERY = [
  // Core business info
  'services', 'pricing', 'about', 'contact',
  // Trust & reviews
  'reviews', 'testimonials', 'team',
  // Service area
  'service area', 'locations', 'coverage',
  // Promotions & membership (from schema)
  'promotion', 'promotions', 'specials', 'coupons', 'discounts',
  'membership', 'maintenance plan', 'service plan',
  // FAQ & support
  'faq', 'frequently asked questions',
  // Financing
  'financing', 'payment options',
  // Emergency
  'emergency', '24 hour', 'after hours',
  // Brands
  'brands', 'manufacturers',
].join(' ');
```

### 2.2 URL Seeding Implementation

```typescript
// In cal-booking-pipeline.ts or website-discovery.ts

interface UrlSeedingResult {
  url: string;
  status: 'valid' | 'not_valid' | 'unknown';
  relevance_score?: number;
  head_data?: {
    title?: string;
    meta?: Record<string, string>;
  };
}

async function discoverTargetUrls(domain: string): Promise<{
  targetUrls: string[];
  discoveryMethod: 'url_seeding' | 'failed';
  hasSitemap: boolean;
}> {
  const CRAWL4AI_ENDPOINT = process.env.CRAWL4AI_ENDPOINT;
  
  try {
    // Use Crawl4AI's URL Seeding API
    const response = await fetch(`${CRAWL4AI_ENDPOINT}/seed`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        domain,
        config: {
          source: 'sitemap',           // Use sitemap discovery
          extract_head: true,          // Get page metadata for better filtering
          query: URL_SEEDING_QUERY,    // BM25 relevance scoring
          scoring_method: 'bm25',
          score_threshold: 0.2,        // Include pages with moderate relevance
          max_urls: 15,                // Limit to top 15 most relevant
          filter_nonsense_urls: true,  // Auto-filter junk (robots.txt, .js, etc.)
          concurrency: 10,
          cache_ttl_hours: 24,         // Cache sitemap for 24 hours
          validate_sitemap_lastmod: true
        }
      })
    });
    
    if (!response.ok) {
      throw new Error(`URL Seeding failed: ${response.status}`);
    }
    
    const urls: UrlSeedingResult[] = await response.json();
    
    if (urls.length > 0) {
      // Sort by relevance score (highest first)
      const sortedUrls = urls
        .filter(u => u.status !== 'not_valid')
        .sort((a, b) => (b.relevance_score || 0) - (a.relevance_score || 0))
        .map(u => u.url);
      
      console.log(`   🌱 URL Seeding found ${sortedUrls.length} relevant pages for ${domain}`);
      
      return {
        targetUrls: sortedUrls,
        discoveryMethod: 'url_seeding',
        hasSitemap: true
      };
    }
    
    // No URLs found - sitemap may not exist or no relevant pages
    console.log(`   ⚠️ URL Seeding found no relevant pages for ${domain}`);
    return {
      targetUrls: [],
      discoveryMethod: 'failed',
      hasSitemap: false
    };
    
  } catch (error: any) {
    console.error(`   ❌ URL Seeding error for ${domain}:`, error.message);
    return {
      targetUrls: [],
      discoveryMethod: 'failed',
      hasSitemap: false
    };
  }
}
```

### 2.3 Why URL Seeding is Better Than LLM Classification

| Aspect | LLM Classification | URL Seeding |
|--------|-------------------|-------------|
| **Cost** | ~$0.15/1M tokens | **Free** |
| **Speed** | 1-3 seconds (API call) | **Instant** (BM25 is 10k+ URLs/sec) |
| **Accuracy** | High (understands context) | Good (pattern + metadata matching) |
| **Maintenance** | Requires prompt tuning | Query terms are simple to update |
| **Built-in** | Requires OpenAI integration | **Native to Crawl4AI** |

For field service businesses with predictable URL patterns (services, pricing, about, contact), URL Seeding provides sufficient accuracy at zero cost.

### 2.4 No Fallback Methods Needed

With URL Seeding, we don't need separate fallback methods:
- ~~Common Patterns~~ - URL Seeding handles this via BM25 scoring
- ~~Homepage Only~~ - If URL Seeding finds nothing, we mark as `failed` and skip extraction

The extraction will only proceed if URL Seeding finds relevant pages. This prevents wasting Crawl4AI resources on sites without useful content.

## Phase 4: Crawl4AI EC2 Server Setup (CDK)

### 4.1 Infrastructure Overview

Deploy Crawl4AI as a Docker container on EC2 with auto-scaling to minimize costs while handling demand spikes.

**Cost Optimization Strategy:**
- Start with **t3.small** ($0.0208/hr = ~$15/month) instead of t3.medium
- Use **Auto Scaling Group** to scale up only when needed
- Scale based on CPU utilization (target 70%)
- Scale down aggressively during low usage
- Use **Spot Instances** for additional cost savings (optional)

### 4.2 CDK Stack: `crawl4ai-stack.ts`

Create new file: `~/callsaver-api/infra/cdk/lib/crawl4ai-stack.ts`

```typescript
import {
  Stack,
  StackProps,
  Duration,
  aws_ec2 as ec2,
  aws_ecs as ecs,
  aws_autoscaling as autoscaling,
  aws_elasticloadbalancingv2 as elbv2,
  aws_iam as iam,
  aws_secretsmanager as secretsmanager,
  aws_ssm as ssm,
  CfnOutput,
} from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { DeployEnvironment } from './config';

export interface Crawl4AIStackProps extends StackProps {
  vpc: ec2.IVpc;
  openaiApiKeySecretArn: string;
}

export class Crawl4AIStack extends Stack {
  readonly crawl4aiEndpoint: string;

  constructor(scope: Construct, id: string, props: Crawl4AIStackProps) {
    super(scope, id, props);

    // Security Group for Crawl4AI
    const crawl4aiSg = new ec2.SecurityGroup(this, 'Crawl4AISg', {
      vpc: props.vpc,
      description: 'Security group for Crawl4AI server',
      allowAllOutbound: true,
    });

    // Allow inbound from VPC only (internal service)
    crawl4aiSg.addIngressRule(
      ec2.Peer.ipv4(props.vpc.vpcCidrBlock),
      ec2.Port.tcp(11235),
      'Allow Crawl4AI API from VPC'
    );

    // IAM Role for EC2
    const ec2Role = new iam.Role(this, 'Crawl4AIRole', {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
        iam.ManagedPolicy.fromAwsManagedPolicyName('CloudWatchAgentServerPolicy'),
      ],
    });

    // Grant access to OpenAI API key secret
    const openaiSecret = secretsmanager.Secret.fromSecretCompleteArn(
      this, 'OpenAISecret', props.openaiApiKeySecretArn
    );
    openaiSecret.grantRead(ec2Role);

    // User Data script to install Docker and run Crawl4AI
    const userData = ec2.UserData.forLinux();
    userData.addCommands(
      '#!/bin/bash',
      'set -e',
      
      // Install Docker
      'yum update -y',
      'yum install -y docker',
      'systemctl start docker',
      'systemctl enable docker',
      'usermod -aG docker ec2-user',
      
      // Install AWS CLI v2
      'curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"',
      'unzip awscliv2.zip',
      './aws/install',
      
      // Get OpenAI API key from Secrets Manager
      `OPENAI_API_KEY=$(aws secretsmanager get-secret-value --secret-id ${props.openaiApiKeySecretArn} --query SecretString --output text --region ${this.region})`,
      
      // Create .llm.env file
      'cat > /home/ec2-user/.llm.env << EOF',
      'OPENAI_API_KEY=$OPENAI_API_KEY',
      'EOF',
      
      // Pull and run Crawl4AI
      'docker pull unclecode/crawl4ai:latest',
      'docker run -d \\',
      '  --name crawl4ai \\',
      '  --restart unless-stopped \\',
      '  -p 11235:11235 \\',
      '  --env-file /home/ec2-user/.llm.env \\',
      '  --shm-size=1g \\',
      '  unclecode/crawl4ai:latest',
      
      // Health check
      'sleep 30',
      'curl -f http://localhost:11235/health || echo "Health check failed"',
    );

    // Launch Template
    const launchTemplate = new ec2.LaunchTemplate(this, 'Crawl4AILaunchTemplate', {
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.SMALL),
      machineImage: ec2.MachineImage.latestAmazonLinux2023(),
      securityGroup: crawl4aiSg,
      role: ec2Role,
      userData,
      blockDevices: [
        {
          deviceName: '/dev/xvda',
          volume: ec2.BlockDeviceVolume.ebs(30, {
            volumeType: ec2.EbsDeviceVolumeType.GP3,
            encrypted: true,
          }),
        },
      ],
    });

    // Auto Scaling Group
    const asg = new autoscaling.AutoScalingGroup(this, 'Crawl4AIASG', {
      vpc: props.vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
      launchTemplate,
      minCapacity: 1,
      maxCapacity: 3,
      desiredCapacity: 1,
      healthCheck: autoscaling.HealthCheck.ec2({
        grace: Duration.minutes(5),
      }),
      updatePolicy: autoscaling.UpdatePolicy.rollingUpdate(),
    });

    // CPU-based scaling policy
    asg.scaleOnCpuUtilization('CpuScaling', {
      targetUtilizationPercent: 70,
      cooldown: Duration.minutes(5),
      estimatedInstanceWarmup: Duration.minutes(3),
    });

    // Scale down more aggressively
    asg.scaleOnMetric('ScaleDown', {
      metric: asg.metricCPUUtilization(),
      scalingSteps: [
        { upper: 30, change: -1 },
        { upper: 50, change: 0 },
      ],
      adjustmentType: autoscaling.AdjustmentType.CHANGE_IN_CAPACITY,
    });

    // Internal Network Load Balancer
    const nlb = new elbv2.NetworkLoadBalancer(this, 'Crawl4AINLB', {
      vpc: props.vpc,
      internetFacing: false,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
    });

    const listener = nlb.addListener('Crawl4AIListener', {
      port: 11235,
      protocol: elbv2.Protocol.TCP,
    });

    listener.addTargets('Crawl4AITargets', {
      port: 11235,
      targets: [asg],
      healthCheck: {
        enabled: true,
        port: '11235',
        protocol: elbv2.Protocol.HTTP,
        path: '/health',
        interval: Duration.seconds(30),
        healthyThresholdCount: 2,
        unhealthyThresholdCount: 3,
      },
    });

    this.crawl4aiEndpoint = `http://${nlb.loadBalancerDnsName}:11235`;

    // Store shared endpoint in SSM Parameter
    new ssm.StringParameter(this, 'Crawl4AIEndpointParam', {
      parameterName: '/callsaver/shared/crawl4ai/endpoint',
      stringValue: this.crawl4aiEndpoint,
    });

    new CfnOutput(this, 'Crawl4AIEndpointOutput', {
      value: this.crawl4aiEndpoint,
      description: 'Internal endpoint for Crawl4AI server',
    });
  }
}
```

### 4.3 Instance Sizing Comparison

| Instance | vCPU | Memory | Cost/Month | Use Case |
|----------|------|--------|------------|----------|
| **t3.small** | 2 | 2 GB | ~$15 | **Recommended start** - handles 1-2 concurrent crawls |
| t3.medium | 2 | 4 GB | ~$30 | More memory for complex pages |
| t3.large | 2 | 8 GB | ~$60 | Heavy concurrent usage |

**Recommendation:** Start with **t3.small** and let auto-scaling handle demand spikes. The ASG will scale to t3.small × 3 = ~$45/month max during peak usage, then scale back down.

### 4.4 Memory Considerations

Crawl4AI requires:
- ~270MB for permanent browser
- ~180MB per additional browser in pool
- 1GB shared memory (`--shm-size=1g`)

**t3.small (2GB RAM)** can handle:
- 1 permanent browser + 2-3 hot pool browsers
- Sufficient for sequential crawling (our use case)

If memory becomes an issue, the ASG will scale horizontally rather than vertically.

### 4.5 Security Configuration

```typescript
// Security Group Rules (already in stack above)
// - Only allow traffic from within VPC
// - No public internet access to Crawl4AI
// - Outbound allowed for crawling websites

// API Authentication (optional, for extra security)
// Add to config.yml:
security:
  enabled: true
  jwt_enabled: false  # Use API key instead
  
rate_limiting:
  enabled: true
  default_limit: "100/minute"  # Prevent abuse
```

### 4.6 Deployment Steps

1. **Add secret to Secrets Manager (shared):**
   ```bash
   aws secretsmanager create-secret \
     --name callsaver/shared/crawl4ai/OPENAI_API_KEY \
     --secret-string "sk-your-openai-key"
   ```

2. **Add stack to CDK app (shared, no environment):**
   ```typescript
   // In bin/app.ts - deploy once, shared by all environments
   const crawl4aiStack = new Crawl4AIStack(app, 'Crawl4AI-Shared', {
     envName: 'shared',  // Not environment-specific
     vpc: networkStack.vpc,
     openaiApiKeySecretArn: 'arn:aws:secretsmanager:us-west-1:836347236108:secret:callsaver/shared/crawl4ai/OPENAI_API_KEY',
   });
   ```

3. **Deploy once:**
   ```bash
   cd infra/cdk
   npx cdk deploy Crawl4AI-Shared
   ```

4. **Access from both environments:**
   - Both staging and production read from `/callsaver/shared/crawl4ai/endpoint`
   - Optionally create environment-specific parameters that reference the shared one:
     - `/callsaver/staging/crawl4ai/endpoint` → `/callsaver/shared/crawl4ai/endpoint`
     - `/callsaver/production/crawl4ai/endpoint` → `/callsaver/shared/crawl4ai/endpoint`

### 4.7 Crawl4AI API Usage

```typescript
// From callsaver-api, get the shared endpoint from SSM
const CRAWL4AI_ENDPOINT = process.env.CRAWL4AI_ENDPOINT || 
  (await ssm.getParameter('/callsaver/shared/crawl4ai/endpoint').promise()).Parameter.Value;

async function crawlPages(urls: string[]): Promise<CrawlResult[]> {
  const response = await fetch(`${CRAWL4AI_ENDPOINT}/crawl`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      urls,
      crawler_config: {
        type: 'CrawlerRunConfig',
        params: {
          cache_mode: 'bypass',
          word_count_threshold: 10,
          page_timeout: 60000,
        }
      }
    })
  });
  
  return response.json();
}
```

### 4.8 Monitoring

Access the built-in monitoring dashboard:
- **Internal only:** `http://<nlb-dns>:11235/monitor`
- View active crawls, browser pool status, memory usage
- Set up CloudWatch alarms for ASG metrics

### 4.9 Cost Summary

| Component | Monthly Cost |
|-----------|-------------|
| t3.small (1 instance baseline) | ~$15 |
| NLB (internal) | ~$16 |
| EBS (30GB gp3) | ~$2.40 |
| Data transfer (internal) | ~$0 |
| **Total baseline** | **~$33/month** |
| **With auto-scaling (peak)** | ~$48/month |

**Shared Service Benefits:**
- One deployment serves both staging and production
- No duplicate infrastructure costs
- Same auto-scaling handles demand from both environments
- Still significantly cheaper than t3.medium ($30) + NLB

## Phase 5: Website Extraction Integration

### 5.1 New Pipeline Step 4: Website Extraction

```typescript
// Voice-optimized schema using Zod
const WebsiteExtractionProfile = z.object({
  summary: z.string().optional(),
  brands_serviced: z.array(z.string()).optional(),
  estimate_policy_text: z.string().optional(),
  value_propositions: z.array(z.string()).optional(),
  trust_and_guarantees: z.array(z.string()).optional(),
  emergency_service_available: z.boolean().optional(),
  // ... other fields from Python version
});

async function extractWebsiteData(urls: string[], businessName: string) {
  // Call Crawl4AI server
  const response = await fetch('https://crawl4ai-server.com/crawl', {
    method: 'POST',
    body: JSON.stringify({
      urls,
      extraction_config: {
        schema: WebsiteExtractionProfile,
        instruction: getExtractionInstruction(),
        provider: 'openai',
        api_key: process.env.OPENAI_API_KEY
      }
    })
  });
  
  return response.json();
}
```

## Phase 6: Pipeline Integration

### 6.1 New Pipeline Step 3: Website Analysis
```typescript
async function analyzeWebsite(domain: string, businessName: string) {
  let targetUrls: string[] = [];
  let discoveryMethod: string;
  
  // Try sitemap first
  const sitemapResult = await detectSitemap(domain);
  if (sitemapResult.found) {
    discoveryMethod = 'sitemap';
    const classification = await classifySitemapPages(domain, sitemapResult.urls, businessName);
    targetUrls = classification.target_pages.map(p => p.url);
  } else {
    // Fallback to common patterns
    discoveryMethod = 'common_patterns';
    targetUrls = await generateCommonPatterns(domain);
    
    // If common patterns fail, homepage only
    if (targetUrls.length <= 1) {
      discoveryMethod = 'homepage_only';
      targetUrls = await homepageOnly(domain);
    }
  }
  
  return { targetUrls, discoveryMethod };
}
```

### 6.2 Update Attio with Results
```typescript
const { targetUrls, discoveryMethod } = await analyzeWebsite(domain, businessName);

await attio.updateRecord('companies', attioCompanyRecordId, calBookingUid, {
  has_sitemap: discoveryMethod === 'sitemap',
  website_discovery_method: discoveryMethod,
  target_urls: targetUrls, // Backup for retry
  last_extraction_attempt_at: new Date().toISOString()
});
```

## Phase 7: S3 Storage

### 7.1 Upload Extracted Profile
```typescript
// After successful extraction
const s3Key = `${attioCompanyRecordId}/website_extraction.json`;
await s3Client.putObject({
  Bucket: 'callsaver-company-website-extractions',
  Key: s3Key,
  Body: JSON.stringify(extractedProfile),
  ContentType: 'application/json'
});

// Update Attio with just the S3 URL
await attio.updateRecord('companies', attioCompanyRecordId, calBookingUid, {
  s3_website_extraction_url: `https://s3.amazonaws.com/callsaver-company-website-extractions/${s3Key}`,
  last_extraction_attempt_at: new Date().toISOString()
});
```

## Implementation Details

### website_discovery_method Field Options (Simplified)
- `sitemap` - Sitemap found and classified with LLM
- `common_patterns` - Used predefined URL patterns based on common service business structures
- `homepage_only` - Final fallback, just the homepage
- `failed` - Network errors or completely inaccessible website

### Pipeline Flow
1. Cal.com webhook → Create booking
2. Google Places Text Search → Create/update Company
3. Google Place Details enrichment → Store in S3
4. **NEW:** Website analysis (sitemap → patterns → homepage) → Update Attio with target URLs
5. **NEW:** Website extraction via Crawl4AI → Store profile in S3
6. Create Person record

### Error Handling & Fallbacks
1. **Sitemap fails** → Try common patterns
2. **Common patterns fail** → Use homepage only
3. **All fail** → Mark as `failed`, store error in notes
4. **Retry logic** → Use backed-up `target_urls` to retry without re-analysis

### Cost Considerations
- GPT-4o-mini for classification (~$0.15/1M tokens) - only when sitemap found
- GPT-4o-mini for extraction (~$0.15/1M tokens)
- Crawl4AI infrastructure (~$33/month baseline with t3.small + NLB, scales to ~$48/month at peak)

### Security
- Crawl4AI server should require API key authentication
- Use IAM roles for S3 access
- Validate all URLs before crawling

## Benefits
- Eliminates separate Python scripts
- Immediate enrichment of Cal.com bookings
- Robust fallback strategy ensures some data extraction even for difficult sites
- Minimal data storage in Attio (just URLs and timestamps)
- Full JSON data stored efficiently in S3
- Retry capability with backed-up `target_urls`
- Voice-optimized extraction for agent use

---

## Appendix: Gap Analysis & Fixes

### Gap 1: S3 Bucket for Website Extractions

**Issue:** The plan references `callsaver-company-website-extractions` but this bucket doesn't exist in CDK.

**Fix:** The existing `callsaver-business-profiles` bucket is already used for Google Place Details. We should use the same bucket with different prefixes:
- `{attioCompanyRecordId}/google_place_details.json` - Google Place Details
- `{attioCompanyRecordId}/website_extraction.json` - Website extraction profile

**No new bucket needed** - reuse `callsaver-business-profiles`.

Update references in this plan from `callsaver-company-website-extractions` to `callsaver-business-profiles`.

### Gap 2: Reuse Existing OpenAI Secret

**Issue:** Plan creates a new `callsaver/shared/crawl4ai/OPENAI_API_KEY` but we already have `OPENAI_API_KEY` in existing secrets.

**Fix:** Update Crawl4AI stack to use existing secret:
```typescript
// Use existing OpenAI secret instead of creating new one
openaiApiKeySecretArn: 'arn:aws:secretsmanager:us-west-1:836347236108:secret:callsaver/staging/backend/OPENAI_API_KEY'
```

The same key works for both environments since it's just an API key.

### Gap 3: Add CRAWL4AI_ENDPOINT to Configuration

**Fix:** Add to `~/callsaver-api/infra/cdk/lib/config.ts`:
```typescript
// In SecretsNamespace interface
crawl4aiEndpoint: string;

// In getSecretsNamespace function
crawl4aiEndpoint: `callsaver/shared/crawl4ai/endpoint`,
```

And pass to ECS task definition as environment variable.

### Gap 4: Complete Website Extraction Zod Schema

**Fix:** Full schema based on Python `WebsiteExtractionProfileV3`:

```typescript
import { z } from 'zod';

const OfficeLocation = z.object({
  label: z.string().optional(),
  address: z.string(),
  phone: z.string().optional(),
});

const FrequentlyAskedQuestion = z.object({
  question: z.string(),
  answer: z.string(),
});

export const WebsiteExtractionProfile = z.object({
  // HIGH PRIORITY - unique to extraction
  summary: z.string().optional().describe('1-2 sentence description of the business. Do NOT include the business name.'),
  brands_serviced: z.array(z.string()).optional().describe('Equipment brands they service/install'),
  estimate_policy_text: z.string().optional().describe('Quote/estimate policy as speakable statement (under 25 words)'),
  value_propositions: z.array(z.string()).optional().describe('Top 3-5 differentiators'),
  trust_and_guarantees: z.array(z.string()).optional().describe('Verifiable trust signals'),
  emergency_service_available: z.boolean().optional(),
  
  // IDENTITY & CREDIBILITY
  email: z.string().optional(),
  licenses: z.array(z.string()).optional(),
  founded_year: z.number().optional(),
  
  // LOCATIONS & SERVICE AREA
  office_locations: z.array(OfficeLocation).optional(),
  service_areas: z.array(z.string()).optional().describe('City names only, no zip codes or states'),
  property_types_served: z.array(z.string()).optional(),
  
  // SERVICE SCOPE
  listed_services: z.array(z.string()).optional().describe('Max 5-8 core services as short labels'),
  
  // PRICING & PROMOTIONS
  diagnostic_fee_policy: z.string().optional(),
  after_hours_fee_policy: z.string().optional(),
  discounts_and_promotions: z.array(z.string()).optional(),
  financing_info: z.string().optional(),
  payment_methods: z.array(z.string()).optional(),
  
  // TRUST & LOGISTICS
  membership_plan_benefits: z.array(z.string()).optional(),
  frequently_asked_questions: z.array(FrequentlyAskedQuestion).optional(),
  common_answers: z.array(z.string()).optional(),
});

export type WebsiteExtractionProfileType = z.infer<typeof WebsiteExtractionProfile>;
```

### Gap 5: Use Crawl4AI's Built-in Job Queue & Webhooks

**Key Insight:** Crawl4AI already has a built-in job queue with Redis and webhook support! No need to duplicate with BullMQ.

**Crawl4AI Job Queue Features:**
- `POST /crawl/job` - Submit async crawl job
- `POST /llm/job` - Submit async LLM extraction job
- `GET /job/{task_id}` - Check job status
- Webhook notifications on completion
- Exponential backoff retries (5 attempts)
- Built-in Redis for job persistence

**Integration Approach:**

```typescript
// In cal-booking-pipeline.ts - submit job to Crawl4AI with webhook

async function submitExtractionJob(
  attioCompanyRecordId: string,
  targetUrls: string[],
  businessName: string,
  calBookingUid: string
) {
  const CRAWL4AI_ENDPOINT = process.env.CRAWL4AI_ENDPOINT;
  const WEBHOOK_URL = process.env.CRAWL4AI_WEBHOOK_URL; // e.g., https://api.callsaver.ai/webhooks/crawl4ai
  
  const response = await fetch(`${CRAWL4AI_ENDPOINT}/crawl/job`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      urls: targetUrls,
      crawler_config: {
        type: 'CrawlerRunConfig',
        params: {
          cache_mode: 'bypass',
          word_count_threshold: 10,
        }
      },
      webhook_config: {
        webhook_url: WEBHOOK_URL,
        webhook_data_in_payload: true,
        webhook_headers: {
          'X-Webhook-Secret': process.env.CRAWL4AI_WEBHOOK_SECRET,
          'X-Attio-Company-Id': attioCompanyRecordId,
          'X-Cal-Booking-Uid': calBookingUid,
          'X-Business-Name': businessName,
        }
      }
    })
  });
  
  const { task_id } = await response.json();
  console.log(`📋 Crawl4AI job submitted: ${task_id} for ${businessName}`);
  return task_id;
}
```

**Webhook Handler in callsaver-api:**

```typescript
// POST /webhooks/crawl4ai
app.post('/webhooks/crawl4ai', async (req, res) => {
  // Verify webhook secret
  const secret = req.headers['x-webhook-secret'];
  if (secret !== process.env.CRAWL4AI_WEBHOOK_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  const payload = req.body;
  const attioCompanyRecordId = req.headers['x-attio-company-id'];
  const calBookingUid = req.headers['x-cal-booking-uid'];
  const businessName = req.headers['x-business-name'];
  
  if (payload.status === 'completed') {
    console.log(`✅ Crawl4AI job ${payload.task_id} completed for ${businessName}`);
    
    // Process the crawled data and extract profile
    const extractedProfile = await processAndExtractProfile(payload.data);
    
    // Upload to S3
    const s3Key = `${attioCompanyRecordId}/website_extraction.json`;
    await s3Client.putObject({
      Bucket: 'callsaver-business-profiles',
      Key: s3Key,
      Body: JSON.stringify(extractedProfile),
      ContentType: 'application/json'
    });
    
    // Update Attio
    await attio.updateRecord('companies', attioCompanyRecordId, calBookingUid, {
      s3_website_extraction_url: `s3://callsaver-business-profiles/${s3Key}`,
      last_extraction_attempt_at: new Date().toISOString()
    });
    
    console.log(`✅ Website extraction stored for ${businessName}`);
  } else if (payload.status === 'failed') {
    console.error(`❌ Crawl4AI job ${payload.task_id} failed: ${payload.error}`);
    // Optionally update Attio with failure status
  }
  
  return res.status(200).json({ status: 'received' });
});
```

**Benefits of using Crawl4AI's built-in queue:**
- No duplicate queue infrastructure
- Crawl4AI handles retries internally (5 attempts with exponential backoff)
- Webhook delivers results directly to our API
- Job status tracking via `/job/{task_id}` endpoint
- Redis persistence built into Crawl4AI container
- Simpler architecture - fewer moving parts

**Note:** We still use BullMQ for other jobs (recording upload, call summarization, etc.) but website extraction leverages Crawl4AI's native capabilities.

### Gap 6: Error Handling for Crawl4AI Failures

**Fix:** Add to website extraction service:

```typescript
async function callCrawl4AI(urls: string[], retries = 3): Promise<CrawlResult[]> {
  const endpoint = process.env.CRAWL4AI_ENDPOINT;
  
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 120000); // 2 min timeout
      
      const response = await fetch(`${endpoint}/crawl`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          urls,
          crawler_config: {
            type: 'CrawlerRunConfig',
            params: {
              cache_mode: 'bypass',
              word_count_threshold: 10,
              page_timeout: 60000,
            }
          }
        }),
        signal: controller.signal,
      });
      
      clearTimeout(timeout);
      
      if (!response.ok) {
        throw new Error(`Crawl4AI returned ${response.status}: ${await response.text()}`);
      }
      
      return await response.json();
    } catch (error: any) {
      console.error(`Crawl4AI attempt ${attempt}/${retries} failed:`, error.message);
      
      if (attempt === retries) {
        throw error;
      }
      
      // Wait before retry (exponential backoff)
      await new Promise(r => setTimeout(r, Math.pow(2, attempt) * 1000));
    }
  }
  
  throw new Error('Crawl4AI failed after all retries');
}
```

### Gap 7: Monitoring & Alerting

**Fix:** Add CloudWatch alarms for the Crawl4AI ASG:

```typescript
// In Crawl4AIStack
import { aws_cloudwatch as cloudwatch, aws_cloudwatch_actions as cw_actions } from 'aws-cdk-lib';

// High CPU alarm
const highCpuAlarm = new cloudwatch.Alarm(this, 'HighCpuAlarm', {
  metric: asg.metricCPUUtilization(),
  threshold: 85,
  evaluationPeriods: 3,
  alarmDescription: 'Crawl4AI CPU > 85% for 15 minutes',
});

// Unhealthy instances alarm
const unhealthyAlarm = new cloudwatch.Alarm(this, 'UnhealthyInstancesAlarm', {
  metric: asg.metric('GroupUnHealthyInstances'),
  threshold: 1,
  evaluationPeriods: 2,
  alarmDescription: 'Crawl4AI has unhealthy instances',
});

// Add SNS topic for alerts (optional)
// highCpuAlarm.addAlarmAction(new cw_actions.SnsAction(alertTopic));
```

**BullMQ job monitoring:**
- Failed jobs are retained for 14 days
- Can query failed jobs via Bull Board or custom endpoint
- Add Sentry error tracking in worker catch blocks

### Gap 8: Pipeline Integration Flow

**Complete flow using Crawl4AI's built-in job queue:**

```typescript
// In cal-booking-pipeline.ts, after Google Place Details enrichment:

// Step 3: Submit website extraction job to Crawl4AI (async)
if (domain) {
  const { targetUrls, discoveryMethod } = await analyzeWebsite(domain, businessName);
  
  // Update Attio with discovery results
  await attio.updateRecord('companies', attioCompanyRecordId, calBookingUid, {
    has_sitemap: discoveryMethod === 'sitemap',
    website_discovery_method: discoveryMethod,
    target_urls: targetUrls,
  });
  
  // Submit job to Crawl4AI (returns immediately, webhook called on completion)
  const taskId = await submitExtractionJob(
    attioCompanyRecordId,
    targetUrls,
    businessName,
    calBookingUid
  );
  
  console.log(`   📋 Crawl4AI extraction job submitted: ${taskId} for ${businessName}`);
}

// Continue with Person creation (doesn't wait for extraction)
```

**Webhook receives results asynchronously:**
```
POST /webhooks/crawl4ai
  ↓
Verify X-Webhook-Secret header
  ↓
Extract metadata from headers (attioCompanyRecordId, calBookingUid, businessName)
  ↓
Process crawled markdown → extract structured profile with OpenAI
  ↓
Upload to S3: callsaver-business-profiles/{attioCompanyRecordId}/website_extraction.json
  ↓
Update Attio: s3_website_extraction_url, last_extraction_attempt_at
```

This ensures:
1. Cal.com webhook responds quickly (doesn't wait for crawling)
2. Crawl4AI handles retries internally (5 attempts with exponential backoff)
3. Failed extractions don't block the pipeline
4. Jobs are persisted in Crawl4AI's Redis
5. Results delivered via webhook when ready

---

## Summary of Changes Needed

1. **S3 Bucket:** Use existing `callsaver-business-profiles` bucket
2. **OpenAI Secret:** Reuse existing `callsaver/staging/backend/OPENAI_API_KEY`
3. **Config:** Add `CRAWL4AI_ENDPOINT` and `CRAWL4AI_WEBHOOK_SECRET` to runtime config
4. **Schema:** Add complete Zod schema for website extraction
5. **Crawl4AI Job Queue:** Use built-in `/crawl/job` endpoint with webhook callbacks (no BullMQ needed for extraction)
6. **Webhook Handler:** Add `POST /webhooks/crawl4ai` endpoint to receive extraction results
7. **Error Handling:** Crawl4AI handles retries internally (5 attempts with exponential backoff)
8. **Monitoring:** Add CloudWatch alarms for ASG health
