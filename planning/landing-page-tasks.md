# Landing Page Tasks — Evening Sprint (Feb 11, 2026)

## 1. Figtree Font Sizing Audit
- Full audit of Figtree font sizing across every section of the landing page
- Check heading hierarchy (h1–h6), body text, lead text, button text, nav links
- Verify responsive sizing (mobile vs tablet vs desktop)
- Ensure consistent use of font weights and sizes per design system
- Fix any inconsistencies or oversized/undersized text

## 2. Geo Banner Animation Timing Fix — ✅ COMPLETED (Feb 11, 2026)

Wrapped banner + header in a single `position: fixed` overlay container. Both slide in together via React state-driven CSS transition (`translateY(-100%)` → `translateY(0)`) after a 2.8s delay, timed to appear after the hero headline, subheadline, underline animation, and CTA button have all finished animating. Also fixed:
- Nav link font size → 18px, weight → 600
- Geo banner text → 18px, weight → 600
- Navbar "Book a Call" button vertically centered
- Nav link de-hover scale snap fixed (`$nav-link-transition: all 0.2s ease-in-out`)
- Added dev-only `FontControlWidget` for live font size/weight experimentation
- Commit: `7b7e79d`

## 3. GrowthBook Proper Setup
- Configure GrowthBook with a real event logger / tracking callback
- Re-enable `trackEvent` and `trackFeatureUsage` in `src/lib/growthbook.ts` (currently no-ops)
- Set up the A/B test for the hero headline variations
- Verify events flow through to the GrowthBook dashboard
- Remove debug `console.log` statements in `getGrowthBook()`

## 4. Website Copy Audit
- Review all copy across every section of the landing page for:
  - Grammar, spelling, punctuation
  - Tone consistency (professional but approachable)
  - Value proposition clarity
  - CTA effectiveness
  - Industry-specific terminology accuracy
- Check for placeholder or lorem ipsum text
- Verify all claims are accurate and defensible

## 5. Replace Static App Screenshot with Recorded Demo
- Use [OpenScreen](https://openscreen.vercel.app/) to record a live demo of the CallSaver web app
- Replace the current static screenshot that appears below the copy:
  > "Imagine never worrying about missing a call again. CallSaver voice agents handle the phones so you can focus on what actually matters—growth."
- Ensure the recording is high quality, shows key features, and loops well
- Optimize file size for web (consider WebM + MP4 fallback)

## 6. Recover Longer Hero Video from Windows Installation
- Boot into Windows on dual-boot laptop
- Locate and recover the longer video demo previously created
- Replace the current `HeroHeaderVideo-quarter-length.mp4` which loops too quickly
- Ensure the new video is optimized for web delivery (compressed, correct codec)
- Test that the hero background video plays smoothly without visible loop seam

## 7. PageSpeed Insights Score Audit
- Run Google PageSpeed Insights for both mobile and desktop
- Document current scores (Performance, Accessibility, Best Practices, SEO)
- Identify and fix top issues impacting performance:
  - Image optimization (WebP/AVIF, lazy loading, proper sizing)
  - JavaScript bundle size
  - Render-blocking resources
  - CLS / LCP / FID metrics
- Re-run after fixes and document improvement

## 8. SEO Competitive Analysis
- Analyze callsaver.ai vs competitors:
  - **broccoli.com**
  - **lace.ai**
- Compare:
  - Meta titles, descriptions, and OG tags
  - Heading structure and keyword usage
  - Page load speed
  - Mobile responsiveness
  - Structured data / schema markup
  - Backlink profile (if tools available)
  - Content depth and keyword targeting
- Document findings and actionable improvements for callsaver.ai
- Implement quick-win SEO fixes identified during analysis

## 9. Sticky Navbar/Banner Overlay — Improve Appearance Over White Sections

### Problem
When the user scrolls past the hero (dark video background), the sticky banner+navbar overlay crosses over white/light sections (Features, FAQ, etc.). The opaque white navbar with the purple geo banner looks jarring and disconnected against the white page backgrounds — no visual separation, the banner color clashes, and it feels like a foreign element floating over the content.

### Brainstormed Approaches

#### A. Glassmorphism / Frosted Glass (⭐ RECOMMENDED FIRST)
- Apply `backdrop-filter: blur(12px)` + semi-transparent background (`rgba(255,255,255,0.8)`) to the navbar when sticky
- The geo banner could become `rgba(76,0,255,0.85)` with blur
- **Why it works:** This is the #1 approach used by modern sites in 2025/2026. Apple.com, Linear.app, Vercel.com, Stripe.com, Notion.so — all use frosted glass navbars. It lets the content peek through subtly while maintaining readability. It looks premium and polished.
- **Effort:** Low — CSS-only, ~5 lines of changes
- **Risk:** Low — widely supported, graceful degradation (just becomes opaque on older browsers)

#### B. Scroll-Aware Color Adaptation
- Use `IntersectionObserver` to detect which section the navbar is overlapping
- Dynamically change navbar background, text color, and banner color based on the underlying section
- Dark sections → light/transparent navbar; Light sections → dark or frosted navbar
- **Why it works:** Sites like [lenis.darkroom.engineering](https://lenis.darkroom.engineering/) and [awwwards.com](https://www.awwwards.com/) nominees do this. Creates a chameleon effect.
- **Effort:** Medium — requires JS observer logic + transition CSS for each state
- **Risk:** Medium — complex to tune, potential flicker if section boundaries are close together

#### C. Hide Banner on Scroll, Show Only Compact Navbar
- When user scrolls past the hero, slide the geo banner up (collapse it) and only show a slimmer navbar
- Banner reappears when user scrolls back to top
- **Why it works:** Reduces visual noise. Many SaaS sites (Intercom, HubSpot) collapse promotional banners on scroll to prioritize navigation.
- **Effort:** Low-Medium — add scroll listener, animate banner height to 0
- **Risk:** Low — clean UX pattern, well-established

#### D. Hide-on-Scroll-Down, Show-on-Scroll-Up
- Entire navbar+banner hides when scrolling down (user is consuming content)
- Slides back in when user scrolls up (user is navigating)
- **Why it works:** Medium.com, Dev.to, many mobile-first sites use this. Maximizes content area. Very common in 2025.
- **Effort:** Low — scroll direction detection + translateY toggle
- **Risk:** Low — but some users find it disorienting on desktop

#### E. Drop Shadow + Subtle Border on Sticky
- Keep the current opaque white navbar but add a soft bottom shadow and/or a 1px bottom border when sticky
- Creates visual separation from the white content below without changing the navbar itself
- **Why it works:** Simple, minimal. GitHub.com, Figma.com use subtle shadows.
- **Effort:** Very Low — 2 lines of CSS
- **Risk:** Very Low — but may not fully solve the "looks bad" problem, just mitigates it

#### F. Navbar Becomes Transparent Over Dark Sections, Solid Over Light
- Navbar starts transparent over the hero video, transitions to frosted/solid as it enters white sections
- Text and logo colors invert accordingly
- **Why it works:** Premium feel. Shopify.com, Tesla.com, and many luxury brand sites do this.
- **Effort:** Medium-High — requires section detection + dual color schemes for all navbar elements
- **Risk:** Medium — logo needs light/dark variants (already have both), but link colors and button styling need careful handling

#### G. Remove Sticky Entirely — Static Navbar + Floating "Back to Top" / CTA
- Remove sticky behavior. Navbar only appears at the top.
- Add a floating "Book a Call" CTA button (bottom-right) that appears after scrolling past the hero
- **Why it works:** Removes the problem entirely. Some modern sites (especially long-form landing pages) prefer this approach with a persistent floating CTA.
- **Effort:** Low — remove sticky, add floating button component
- **Risk:** Low — but loses quick access to navigation links

#### H. Thin Sticky Bar (Minimal Mode)
- On scroll, the full navbar collapses into a very thin bar (~40px) with just the logo and CTA button
- Expands back to full on hover or scroll-up
- **Why it works:** Notion.so, some Webflow sites do this. Minimizes visual disruption while keeping key actions accessible.
- **Effort:** Medium — requires two navbar states + smooth transition between them
- **Risk:** Low — but need to ensure the collapsed state is still usable

### Recommendation Order (try in this sequence)

1. **A — Glassmorphism** — Try this first. Highest ROI, lowest effort, industry standard in 2025/2026. If it looks good, stop here.
2. **C — Collapse banner on scroll** — If the geo banner is the main eyesore, just hide it on scroll. Combine with (A) for the navbar itself.
3. **E — Drop shadow** — Quick win to add if (A) alone isn't enough separation.
4. **D — Hide on scroll down** — Good fallback if the navbar just doesn't look right overlaying content at all.
5. **B or F — Scroll-aware color** — Only if you want a truly premium, polished feel and are willing to invest the tuning time.
6. **H — Thin sticky bar** — If you want minimal but still functional.
7. **G — Remove sticky** — Nuclear option. Only if nothing else works.

### What the Best Sites Do (2025/2026)
- **Apple.com**: Frosted glass navbar, collapses sub-nav on scroll
- **Linear.app**: Frosted glass, hide-on-scroll-down
- **Vercel.com**: Frosted glass with subtle border
- **Stripe.com**: Frosted glass, slight background tint shift
- **Notion.so**: Hides navbar on scroll down, shows on scroll up
- **Intercom.com**: Collapses promotional banner, keeps compact nav
- **Figma.com**: Subtle shadow separator, slightly transparent

## 10. Mobile Visual Review (Manual)

Full manual visual review by Alex of the entire landing page on mobile screen sizes. Check:
- Hero section layout, video background, headline/subheadline readability
- Geo banner + navbar overlay appearance and spacing
- Feature cards — layout, text wrapping, padding, card sizing
- Integration cards — icon alignment, text overflow, card stacking
- FAQ accordion — question text wrapping, answer readability, tap targets
- Audio demo section — player controls, visualizer sizing
- CTA section — button sizing, form layout
- Footer — column stacking, link tap targets, email links, logo sizing
- General — font sizes feel right on small screens, no horizontal overflow, no cut-off text, adequate touch targets (min 44px), spacing between sections

---

## Priority Order
1. ~~Geo banner animation timing fix~~ — ✅ DONE
2. Figtree font sizing audit (nav links + geo banner already done at 18px/600)
3. Website copy audit + SEO competitive analysis (combined — SEO keyword/content analysis feeds directly into copy improvements; also generate hero headline A/B test variations during this step)
4. GrowthBook proper setup (wire up the A/B test variations from step 3)
5. OpenScreen app demo recording & replace static screenshot
6. Recover longer hero video from Windows & replace current short loop
7. PageSpeed Insights audit & fixes
8. Sticky navbar/banner overlay improvement (see Task 9 for approaches)
9. Mobile visual review (manual — Alex)
