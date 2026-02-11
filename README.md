# Production Launch Plan

Operational hub for CallSaver production launch planning, checklists, and cross-repo utilities.

## Directory Structure

```
production-launch-plan/
├── planning/          # Launch planning documents
├── legal/             # Legal documents (LLC formation, operating agreement)
├── services/          # External services inventory and audit
├── qr-code/           # QR code tracking system and generation
├── website/           # PageSpeed testing utilities
├── scripts/           # Cross-repo utilities (logo updates)
└── archive/           # Historical debugging notes
```

## Planning (`planning/`)

| File | Description |
|------|-------------|
| `master-plan.md` | Full launch plan (~60 tasks across Phases 0–4) |
| `active-plan.md` | Current active tasks and priorities |
| `daily-plan.md` | Daily planning and progress tracking |
| `business-formation-checklist.md` | Prosimian Labs LLC formation checklist |

## Legal (`legal/`)

| File | Description |
|------|-------------|
| `OPERATING_AGREEMENT_PROSIMIAN_LABS_LLC.md` | Operating Agreement (markdown source) |
| `OPERATING_AGREEMENT_PROSIMIAN_LABS_LLC-2026-02-10.pdf` | Signed Operating Agreement (PDF) |

## Services (`services/`)

| File | Description |
|------|-------------|
| `external-services-inventory.md` | Audit of 23 external services (AWS, Stripe, Supabase, etc.) |

## QR Code System (`qr-code/`)

| File | Description |
|------|-------------|
| `qr-code-system.md` | QR tracking system reference (scan tracking, A/B testing, Cal.com attribution) |
| `generate-qr.js` | QR code generator script (uses `qrcode` npm package) |
| `qr-bcard-staging.png` | Generated staging business card QR code |

```bash
# Generate a QR code
cd qr-code && node generate-qr.js
```

## Website (`website/`)

| File | Description |
|------|-------------|
| `pagespeed-test.js` | PageSpeed Insights API test runner |
| `pagespeed-local.js` | Local PageSpeed testing variant |

## Scripts

### `scripts/update-logos.sh`

Cross-repo logo update utility. Converts SVG source files to PNG and WebP, then distributes all variants to the correct locations across 3 repos.

**Prerequisites:**
- `inkscape` (CLI) — SVG → PNG conversion
- `imagemagick` (`convert`) — PNG → WebP conversion

**Usage:**
```bash
./scripts/update-logos.sh ~/path/to/black-logo.svg ~/path/to/white-logo.svg
```

**What it does:**
1. Converts each SVG → PNG (988x152) → WebP
2. Copies all 6 files (2 variants × 3 formats) to:

| Repo | Destinations |
|------|-------------|
| `~/callsaver-landing` | `public/img/{black,white}-logo.{svg,png,webp}` |
| `~/callsaver-frontend` | `public/{black,white}-logo.{svg,png,webp}`, `public/images/black-logo.png` |
| `~/callsaver-api` | `email-previews/black-logo.png`, `public/white-logo.svg`, `public/logo-header.png` |

**After running, manually:**
1. Visually verify logos in each app
2. Upload new logo to Stripe Dashboard → Settings → Branding
3. Upload new logo to DocuSeal (Pro plan required — see `~/callsaver-docuseal/DOCUSEAL_SETUP.md`)
4. Regenerate MSA PDF: `cd ~/callsaver-api && npx tsx scripts/generate-msa-pdf.ts`

## Archive

Historical debugging notes and resolved incident docs are in `archive/`.
