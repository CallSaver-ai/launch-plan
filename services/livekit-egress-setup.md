# LiveKit Cloud & Egress Setup

> **Created:** Feb 11, 2026
> **Status:** IAM user created, awaiting LiveKit Cloud dashboard configuration
> **Relates to:** Task 1.21 (Configure LiveKit Cloud S3 Credentials)

---

## 1. Architecture Overview

CallSaver uses **LiveKit Cloud** (not self-hosted) for real-time voice AI infrastructure.

| Component | Details |
|-----------|---------|
| **LiveKit Cloud Project** | `callsaver-d8dm5v36` |
| **WebSocket Endpoint** | `wss://callsaver-d8dm5v36.livekit.cloud` |
| **SIP Endpoint** | `sip:callsaver-d8dm5v36.pstn.livekit.cloud` |
| **Account** | Investigate: may be under `scrumptiouslemur@gmail.com` or `alex@callsaver.ai` |

### How calls work

1. **Twilio** provisions phone numbers and SIP trunks
2. Inbound calls route via SIP to **LiveKit Cloud**
3. LiveKit Cloud hosts the real-time audio room
4. The **LiveKit Agent** (Python, running on ECS Fargate) connects to the room and handles the conversation using STT/LLM/TTS
5. **LiveKit Egress** (managed by LiveKit Cloud) records the call and uploads the recording to **S3**

### Key distinction: Cloud vs Self-Hosted

- **We use LiveKit Cloud** — egress is fully managed, no Docker containers or Redis needed on our side
- The self-hosting egress docs (deploying egress workers, Chrome sandboxing, Helm charts) do **not** apply
- We only need to provide S3 credentials in the LiveKit Cloud dashboard so their managed egress service can upload recordings to our buckets

---

## 2. Environment Variables

### Backend (`callsaver-api`) — in AWS Secrets Manager (`callsaver/{env}/backend/`)

| Secret | Value | Same across envs? |
|--------|-------|-------------------|
| `LIVEKIT_URL` | `wss://callsaver-d8dm5v36.livekit.cloud` | Yes |
| `LIVEKIT_API_KEY` | (stored in Secrets Manager) | Yes |
| `LIVEKIT_API_SECRET` | (stored in Secrets Manager) | Yes |
| `SESSION_S3_BUCKET` | `callsaver-sessions-staging` / `callsaver-sessions-production` | **Different** |

### Agent (`livekit-python/`) — in AWS Secrets Manager (`callsaver/{env}/agent/`) + ECS env vars

| Env Var / Secret | Value | Same across envs? |
|------------------|-------|-------------------|
| `LIVEKIT_URL` | `wss://callsaver-d8dm5v36.livekit.cloud` | Yes |
| `LIVEKIT_API_KEY` | (from backend namespace) | Yes |
| `LIVEKIT_API_SECRET` | (from backend namespace) | Yes |
| `LIVEKIT_WORKER_NAME` | `callsaver-agent` | Yes |
| `LIVEKIT_SIP_ENDPOINT` | `sip:callsaver-d8dm5v36.pstn.livekit.cloud` | Yes |
| `LIVEKIT_OUTBOUND_TRUNK_ID` | (stored in Secrets Manager) | Yes |

### Agent AI Provider Secrets (`callsaver/{env}/agent/`)

| Secret | Provider | Role |
|--------|----------|------|
| `OPENAI_API_KEY` | OpenAI | Primary LLM (`gpt-4.1-mini`) |
| `DEEPGRAM_API_KEY` | Deepgram | Primary STT |
| `CARTESIA_API_KEY` | Cartesia | Primary TTS |
| `ANTHROPIC_API_KEY` | Anthropic | Fallback LLM |
| `ASSEMBLYAI_API_KEY` | AssemblyAI | Fallback STT |
| `GOOGLE_API_KEY` | Google | Fallback LLM (Gemini) |

---

## 3. S3 Buckets for Call Recordings

LiveKit Egress uploads call recordings directly to these S3 buckets.

| Bucket | Environment | Region | CDK Stack | Lifecycle |
|--------|-------------|--------|-----------|-----------|
| `callsaver-sessions-staging` | Staging | us-west-1 | `Callsaver-Storage-staging` | 30-day expiration |
| `callsaver-sessions-production` | Production | us-west-1 | `Callsaver-Storage-production` | 30-day expiration |

> **Note:** The staging bucket is named `callsaver-sessions-staging` (not `callsaver-sessions-staging-us-west-1` as some earlier planning docs reference). The production bucket has not been created yet — it will be created when `Callsaver-Storage-production` CDK stack is deployed (task 1.13).

---

## 4. IAM Configuration for Egress

A dedicated IAM user provides LiveKit Cloud's egress service with S3 write access.

| Detail | Value |
|--------|-------|
| **IAM User** | `callsaver-livekit-egress` |
| **User ARN** | `arn:aws:iam::836347236108:user/callsaver-livekit-egress` |
| **Access Key ID** | `AKIA4FOROB4GDBZH7JEY` |
| **Secret Access Key** | (stored securely — see LiveKit Cloud dashboard) |
| **Policy Name** | `LiveKitEgressS3Access` (inline policy) |
| **Created** | Feb 11, 2026 |

### IAM Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowEgressPutObject",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "arn:aws:s3:::callsaver-sessions-staging/*",
        "arn:aws:s3:::callsaver-sessions-production/*"
      ]
    },
    {
      "Sid": "AllowEgressListBucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::callsaver-sessions-staging",
        "arn:aws:s3:::callsaver-sessions-production"
      ]
    }
  ]
}
```

**Principle of least privilege:** This user can only write to the session recording buckets. It cannot read, delete, or access any other S3 resources.

---

## 5. LiveKit Cloud Dashboard Configuration

### Egress S3 Settings

Configure in **LiveKit Cloud Dashboard** → **Settings** → **Egress** → **S3**:

| Field | Staging Value | Production Value |
|-------|---------------|-----------------|
| **Access Key ID** | `AKIA4FOROB4GDBZH7JEY` | Same (single IAM user covers both buckets) |
| **Secret Access Key** | (from IAM key creation) | Same |
| **Region** | `us-west-1` | `us-west-1` |
| **Bucket** | `callsaver-sessions-staging` | `callsaver-sessions-production` |

> **Important:** LiveKit Cloud dashboard likely supports a single default S3 configuration per project. If per-environment bucket routing is needed, the bucket can be specified per-request in the egress API call instead. In that case, configure the staging bucket as the dashboard default, and override with the production bucket name in API calls for production sessions.

### Per-Request S3 Override (API Code)

If the dashboard only supports one default bucket, the API code can specify the bucket per-request:

```typescript
// From livekit-server-sdk
const egressClient = new EgressClient(LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET);

await egressClient.startRoomCompositeEgress('room-name', {
  file: new EncodedFileOutput({
    filepath: '{room_name}/{time}.mp4',
    output: {
      case: 's3',
      value: {
        accessKey: '', // uses dashboard default if empty
        secret: '',    // uses dashboard default if empty
        bucket: process.env.SESSION_S3_BUCKET, // environment-specific bucket
        region: 'us-west-1',
      },
    },
  }),
});
```

---

## 6. ECS Agent Infrastructure

The LiveKit Python agent runs as an ECS Fargate service.

| Detail | Staging | Production |
|--------|---------|------------|
| **Service Name** | `callsaver-agent-staging` | `callsaver-agent-production` |
| **CPU / Memory** | 512 CPU / 2048 MB | 512 CPU / 2048 MB |
| **Auto-scaling** | 1–2 tasks, 80% CPU | 1–2 tasks, 80% CPU |
| **Network** | Outbound only (no ALB) | Outbound only (no ALB) |
| **Connects to** | `wss://callsaver-d8dm5v36.livekit.cloud` | Same |
| **CDK Stack** | `Callsaver-Agent-staging` | `Callsaver-Agent-production` |

The agent does **not** handle recording — that's done by LiveKit Cloud's managed egress service.

---

## 7. Recording Flow (End-to-End)

```
Inbound call → Twilio SIP → LiveKit Cloud Room
                                    ↓
                          LiveKit Agent (ECS)
                          handles conversation
                                    ↓
                    API triggers Egress recording
                                    ↓
                LiveKit Cloud Egress (managed service)
                   records audio/video composite
                                    ↓
                Uploads MP4 to S3 bucket using
                IAM credentials from dashboard config
                                    ↓
              callsaver-sessions-{env} S3 bucket
```

---

## 8. Supported Egress Types

LiveKit Cloud supports these egress types (all managed, no self-hosting required):

| Egress Type | Description | Our Use Case |
|-------------|-------------|--------------|
| **RoomComposite** | Records all participants in a room as a single composite | Primary — full call recordings |
| **TrackComposite** | Records specific audio + video tracks | Possible future use |
| **Track** | Exports individual tracks without transcoding | Possible future use |
| **Participant** | Records a single participant | Not currently used |
| **Web** | Records a web page | Not applicable |

### Output Formats

| Output | Supported | Notes |
|--------|-----------|-------|
| MP4 file → S3 | ✅ | Primary output — call recordings |
| HLS segments → S3 | ✅ | Available if needed |
| RTMP stream | ✅ | Not currently used |
| WebSocket stream | ✅ | Audio-only, Track egress only |

---

## 9. Operational Notes

### Recording Lifecycle
- Recordings are stored in S3 with a **30-day lifecycle policy** (auto-deleted after 30 days)
- The `SESSION_S3_BUCKET` env var tells the API which bucket to reference when generating presigned URLs for playback

### Monitoring
- Egress status can be monitored via the LiveKit Cloud dashboard
- The API can poll egress status using `EgressClient.listEgress()` or receive webhook callbacks

### Cost Considerations
- LiveKit Cloud egress usage is billed by LiveKit (check LiveKit Cloud pricing)
- S3 storage costs are minimal with 30-day lifecycle (AWS charges for PUT requests + storage)
- The dedicated IAM user has no AWS billing impact (IAM is free)

---

## 10. Checklist

- [x] IAM user `callsaver-livekit-egress` created (Feb 11, 2026)
- [x] Inline policy `LiveKitEgressS3Access` attached — scoped to session buckets only
- [x] Access key generated: `AKIA4FOROB4GDBZH7JEY`
- [ ] **MANUAL:** Log in to LiveKit Cloud dashboard (https://cloud.livekit.io)
- [ ] **MANUAL:** Navigate to Settings → Egress → S3
- [ ] **MANUAL:** Enter Access Key ID, Secret Access Key, Region (`us-west-1`), Bucket (`callsaver-sessions-staging`)
- [ ] **MANUAL:** Test by triggering a recording from staging
- [ ] Production bucket created (blocked on task 1.13 — production infra deployment)
- [ ] Update LiveKit dashboard or API code to use production bucket when production is deployed
