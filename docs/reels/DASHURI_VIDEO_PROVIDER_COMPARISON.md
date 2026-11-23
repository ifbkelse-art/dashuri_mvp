# Video provider comparison for Reels

**Prices were checked on 22 Nov 2026** from the official pages listed under Sources, or from search results quoting them. Check them again on the providers' own pages before committing money. **No account was created and nothing was purchased.**

Stream (getstream.io), which runs the live calls, was also considered. It is a real-time product (WebRTC rooms billed per participant-minute) with no short-video hosting, CDN playback or upload pipeline, so it does not fit Reels.

## 1. What each option does

| | **Mux Video** | **Cloudflare Stream** | **AWS S3 + MediaConvert + CloudFront** |
|---|---|---|---|
| Upload | Direct uploads: the server creates a one-time URL and the app PUTs the file. Passthrough id; resumable | Direct creator uploads (one-time URL, `maxDurationSeconds`); tus for > 200 MB | Presigned S3 PUT; you build multipart and resume yourself |
| Transcoding | Automatic adaptive ladder; **basic quality is free** | Automatic, included in the storage price | MediaConvert jobs you define (billed per output minute; Basic tier for simple outputs) |
| Adaptive playback | HLS | HLS and DASH | HLS packaging set up by you |
| Thumbnails | `image.mux.com` at any time offset (signed) | Thumbnail endpoint at any time offset | A separate MediaConvert frame-capture output |
| CDN | Included (multi-CDN) | Cloudflare network | CloudFront |
| Signed playback | JWT (RS256) signing keys; `signed` policy per asset | Signed URLs and tokens, `requireSignedURLs` | CloudFront signed URLs or cookies |
| Webhooks | Yes, HMAC-SHA256 `Mux-Signature` | Yes, HMAC-SHA256 `Webhook-Signature` | EventBridge / SNS |
| Moderation | None built in; frames are reachable by URL, which suits Sightengine | None built in | Amazon Rekognition (a separate service and bill) |
| Data location | US-based processing (no India region) | Global network; no data-region guarantee on standard plans | Can stay in `ap-south-1` (Mumbai) |
| Scalability | High (managed) | High (managed) | High, but you operate it |
| Operations work | Low: one adapter (built: `adapters/mux`) | Low | **High:** buckets, IAM, job templates, packaging, CDN, signing, lifecycle rules |

## 2. Pricing (official pages)

| Item | Mux (pay as you go) | Cloudflare Stream | AWS |
|---|---|---|---|
| Free allowance | **100,000 delivery minutes per month on every plan, plus a $20/month usage credit** | No free usage on the paid product | CloudFront always-free **1 TB transfer and 10 M requests per month** |
| Encoding | Basic: **$0**; plus $0.03125/min | Included | MediaConvert per output minute (Basic tier from about $0.0075/min, region-dependent; each rendition is billed) |
| Storage | **from $0.0024 per stored minute per month** (720p, first tier); the docs table shows $0.0030 | **$5 per 1,000 minutes stored** ($0.005/min), bought in 1,000-minute blocks | S3 about $0.025/GB-month (Mumbai), very cheap at this scale |
| Delivery | **about $0.0008/min at 720p** after the free minutes (the docs show $0.0010) | **$1 per 1,000 minutes delivered** ($0.001/min) | about $0.109–0.12/GB in India after 1 TB (third-party summaries; check the official calculator) |

### Worked example: Dashuri base case, Month 6

The base case (from the simulator) has about 194,000 views a month at 12 s each, so about **38,900 watch-minutes**. About 570 uploads a month at 30 s gives about **1,100 stored minutes after six months**.

| | Mux | Cloudflare Stream | AWS |
|---|---|---|---|
| Delivery | 38.9k min is under the free 100k: **$0** | 38.9k × $0.001 = **$38.9** | about 3 GB, inside the 1 TB free tier: **$0** |
| Storage | 1.1k × $0.0024 = **$2.6** | 2 blocks × $5 = **$10** | about $0.1 |
| Encoding | $0 (basic) | $0 | about 570 × 0.5 min × 4 renditions × $0.0075 ≈ **$8.6** |
| Credit | −$20 | — | — |
| **Month total** | **$0** | **about $49** | **about $9 plus engineering time** |

**Optimistic case, Month 6:** about 647,000 watch-minutes.
- Mux: (647k − 100k) × $0.0008 + storage ≈ **$460**.
- Cloudflare: about **$650 + $25**.
- AWS: delivery of about 50 GB is still in the free tier, so **≈ $40 plus engineering**.

At high volume, AWS becomes the cheapest per minute. It also costs weeks of engineering and ongoing operations.

## 3. Recommendation: Mux, behind the `VideoProvider` interface

1. **Zero cost at Dashuri's current scale.** The 100,000 free delivery minutes and the $20 credit cover the base case. That fits the "can't pay bills" constraint best.
2. **Least operational work:**
   - direct uploads from the phone;
   - free basic encoding;
   - signed playback that we already sign ourselves (no per-view API call);
   - signed webhooks;
   - thumbnails at any time offset, which is exactly what frame-based moderation needs.
3. **Already built and tested:** `backend/internal/adapters/mux`, with unit tests for uploads, assets, deletion, webhook signatures (including stale, tampered and rotated) and RS256 playback tokens.

**When to revisit:**
- watch time grows past roughly 1 M minutes a month (AWS or a negotiated Mux contract);
- data residency in India becomes a requirement (AWS Mumbai).

The `VideoProvider` port (upload session, asset status, playback, frames, delete, webhook parsing) is all that a replacement adapter has to implement.

**Risks to check before going live:**
- Mux's acceptable-use policy for an 18+ dating-adjacent product. Read the AUP and ask Mux sales in writing.
- DPDP cross-border transfer. Allowed unless the country is restricted, but it must be disclosed in the privacy policy.
- Whether Mux's free tier stays on pay-as-you-go.

## Sources

- Mux pricing: <https://www.mux.com/pricing> and <https://www.mux.com/docs/pricing/video>. Free 100k delivery minutes, $20 PAYG credit, basic encoding free, storage from $0.0024/min.
- Mux price changes: <https://www.mux.com/blog/price-drop> (July 2025).
- Mux signed playback, direct uploads and webhooks: <https://www.mux.com/docs>.
- Cloudflare Stream pricing: <https://developers.cloudflare.com/stream/pricing/>. $5 per 1,000 minutes stored, $1 per 1,000 minutes delivered.
- Cloudflare Stream direct creator uploads and webhooks: <https://developers.cloudflare.com/stream/uploading-videos/direct-creator-uploads/> and <https://developers.cloudflare.com/stream/manage-video-library/using-webhooks/>.
- AWS Elemental MediaConvert pricing: <https://aws.amazon.com/mediaconvert/pricing/>.
- Amazon CloudFront pricing, including always-free 1 TB: <https://aws.amazon.com/cloudfront/pricing/>. The India per-GB rate is from third-party summaries and is unverified.
- Sightengine pricing and operation definition: <https://sightengine.com/pricing> and <https://sightengine.com/faq/what-is-an-operation>.
