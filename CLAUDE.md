# CLAUDE.md — Batam Dashboard

Context for Claude Code when working in this repo. **This is part of the Batam
property business (Ace Hotel + Laundry Shophouse) — fully separate from the
Mac-mini quant trading fund (`gekko` / `gekko-research`). Do NOT mix memory,
context, credentials, or deployments between them.** Sibling repo:
`jeremychoyl/batampropbot` (the WhatsApp consultant bot for the same business).

## What this is
A single-page financial model / investor dashboard for the owner's **Ace Hotel
& Laundry Shophouse** business in Batam. It's a *shared live model* — every
viewer sees the same numbers, edits sync for everyone via Supabase.

Live: **https://batam-dashboard.vercel.app/**

## Stack & deploy
- **One file: `index.html`.** No build step, no framework, no dependencies
  (Chart.js loaded from CDN). Edit the HTML/CSS/JS inline.
- **Vercel** auto-deploys on every push to `main` → the public production URL
  above. Production is NOT auth-gated.
- **Supabase** is the shared backend (anon key is embedded in the client by
  design — it is a public anon key; access is governed by Supabase RLS, not by
  hiding the key):
  - table `inputs`, single row `id=1`, column `data` (JSON) holds ALL state:
    the model inputs (`in-*`), plus `_renoRows`, the Accounts figures (`_acc_*`),
    and the Cash-Transfers data (`_p1Rows`, `_p2Rows`, `_rooms`, `_payments`,
    `_archived`, `_tr_fx`). Saved via PATCH; polled every 15s so
    partners' edits appear live.
  - table `snapshots` — named version history (Save Snapshot / Restore / Preview).

## Tabs (each an `#panel-*` + its own `<script>` block)
Inputs · Overview · Projections · Occupancy · Benchmarks · Risks · Timeline ·
Renovation · Ratings · Laundry (Accounts) · Cash Transfers.
Each feature-script patches `collectInputs`/`applyInputs`/`switchTab` to persist
and render its own slice — keep that chaining intact when adding features.

### Cash Transfers tab (rebuilt 2026-08-02)
Three sections: **Part 1 — Capital Expenditure** (renovation spend ledger,
running balance, avg cost/room), **Part 2 — Rental Collections** (chained from
Part 1's closing balance, IDR+SGD), **Part 3 — Room Management** (7-room table +
12-month payment tracker with tap-to-toggle ⬜→✅→🔴, delinquency alerts, period
archiving). Replaced the old single flat `_transfers` ledger; the live-FX puller
still refreshes it via a `renderTransferDerived()` alias.

## Working rules for this repo
- **Change flow: branch → PR → Vercel preview → owner approves → merge to main.**
  Never push straight to `main` for anything non-trivial.
- ⚠️ **Vercel Deployment Protection is ON**, so every *preview* (branch) URL
  redirects to a Vercel login — the owner works from an **iPad** and can't see
  previews unless signed into the `quantstrategic` Vercel team. Production is
  unprotected. So when the owner can't use the preview, the practical path is:
  merge to `main`, verify on the public URL, and `git revert` if wrong (note the
  prior `main` SHA before merging as the rollback point).
- Secrets: only the Supabase anon key belongs client-side; never add service-role
  keys or other secrets to `index.html`.
- Changing the shape of persisted data (as the Cash-Transfers rebuild did) means
  old saved JSON keys are ignored — call it out so the owner re-saves once.
