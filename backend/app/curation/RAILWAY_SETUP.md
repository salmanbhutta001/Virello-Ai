# Autonomous Curation — Railway setup (Hafiz, phone se)

Backend me ab **khud-chalne wala** curation loop hai: har 3 ghante
(Asia/Karachi) 26 departments me se har ek ka kam az kam 1 product
pakka karta hai AUR har department me naye products bhi jorta hai
(growth quota, default 1/department/cycle — `VIRELLO_CURATION_NEW_PER_DEPT`),
unki 3 tasveeron wali gallery banata hai, aur Shop me list karta hai.
Koi agent ya cron ki zaroorat nahi — bas neeche wale 3 steps ek dafa karne
hain, phir `railway up`.

**Manual control (bina kisi agent ke):**
- Cycle foran chalana: `POST /api/v1/curation/run`
- Haath se product queue me daalna: `POST /api/v1/curation/candidates`
  `{candidates: [{asin, title, department, main_image_url}]}`
- Haalat dekhna: `GET /api/v1/curation/status`
Teeno ke liye admin login ya `X-Curator-Token` header chahiye.
Agar `VIRELLO_CURATOR_CREATOR_EMAIL` set na ho to listings khud hi
pehle admin account se attribute ho jati hain — cycle kabhi is wajah
se nahi rukta.

## Step 1 — Persistent volume (zaroori)

Railway ka filesystem **ephemeral** hai: redeploy par likhi hui files mit
jati hain. Is liye gallery ke liye volume lagana zaroori hai, warna nayi
products ki tasveeren har deploy ke baad 404 ho jayengi.

Railway dashboard → aapki **virello-api-production** service →
**Volumes** → **+ New Volume**:
- **Mount Path:** `/data/gallery`

(Bas — size default rehne dein.)

## Step 2 — Environment variables

Railway dashboard → service → **Variables** me ye add karein:

| Variable | Value |
|---|---|
| `VIRELLO_GALLERY_DIR` | `/data/gallery` |
| `VIRELLO_CURATION_LOG_PATH` | `/data/curation_runs.log` |
| `VIRELLO_CURATOR_CREATOR_EMAIL` | aapki creator account email (jis par products attribute hon) |
| `VIRELLO_PUBLIC_BASE_URL` | `https://virello-api-production.up.railway.app` |
| `VIRELLO_AMAZON_PARTNER_TAG` | `topitems0c1-20` |

Optional:
| Variable | Value | Matlab |
|---|---|---|
| `VIRELLO_CURATION_AUTONOMOUS` | `true` (default) | `false` karne se loop band |
| `VIRELLO_CURATION_INTERVAL_HOURS` | `3` (default) | ghanton me waqfa |
| `VIRELLO_CURATION_NEW_PER_DEPT` | `1` (default) | har cycle har department me kitne NAYE products |

`VIRELLO_CURATOR_TOKEN` pehle se set hona chahiye (curate API ke liye) —
usko haath na lagayein.

## Step 3 — Deploy

Phone se repo folder me:

```bash
railway up
```

Deploy ke baad loop khud start ho jayega (pehla run ~1 ghante me).

## Check karna (admin)

Admin account se login karke:

```
GET https://virello-api-production.up.railway.app/api/v1/curation/status
```

Ye batayega: loop on hai ya off, aakhri run kab hua, har department me
kitni products hain, aur kitne candidates queue me hain.

## Ehem baatein (honest limits)

1. **Amazon aksar bot-block karta hai.** Datacenter IPs se search pages
   kabhi kabhi khulti hain, kabhi nahi. Block hone par wo department us
   ghante skip ho jata hai (log me likha jata hai) — koi fake product
   nahi banta.
2. **Generated angles sirf file-integrity check se guzarte hain** (sahi
   JPEG, sahi size). Ye confirm nahi hota ke tasveer me wahi product hai.
   Nayi listings ko Shop me promote karne se pehle ek nazar dekh lena
   behtar hai.
3. **Pollinations free service hai** — rate limit lagne par angle
   generation fail ho sakta hai; product us ghante skip ho jayega, agle
   ghante phir try hoga.
4. **Purana curator (Muse agent wala) 2026-10-21 ko retire kar diya gaya**
   (Hafiz ka hukm: curation sirf backend se hogi). Backend loop hi ab
   wahid zariya hai; Curate API phir bhi ASIN dekh kar duplicate skip
   karti hai.
5. Volume lagane se **pehle** ki gallery files (`/gallery/*` purani
   commits wali) static folder se hi serve hoti rahengi — naya code
   volume ko pehle, static ko baad me check karta hai.
