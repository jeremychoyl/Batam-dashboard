# CLAUDE.md — Batam Dashboard

Context for Claude Code when working in this repo. **This is part of the Batam
property business (Ace Hotel + Laundry Shophouse) — fully separate from the
Mac-mini quant trading fund (`gekko` / `gekko-research`). Do NOT mix memory,
context, credentials, or deployments between them.**

## Where this repo sits — four repos in `~/batam`

This is one of four independent repos, each with its own remote:

| Path | GitHub repo | What it is |
|------|-------------|-----------|
| `~/batam` (root) | `jeremychoyl/batam-workspace` **private** | router `CLAUDE.md` + Claude settings |
| `~/batam/dashboard` | `jeremychoyl/Batam-dashboard` | **this repo** — investor model + rent tracker |
| `~/batam/propbot` | `jeremychoyl/batampropbot` **private** | WhatsApp consultant bot, on Railway |
| `~/batam/memory` | `jeremychoyl/claude-memory-batam` **private** | Claude's saved facts, symlinked from `~/.claude/projects/…/memory` |

The root repo **gitignores** the other three, so a clean `git status` there says
nothing about this one — and committing here says nothing about the others.
Before ending a session check all four, not just the one you touched:

```bash
for r in . dashboard propbot memory; do
  printf '\n=== %s ===\n' "$r"; git -C "$r" status -sb
done
```

`~/batam/.claude/check-repos.sh` runs this on a `Stop` hook and warns only when
something is unbacked, but it skips `.claude/settings.local.json` and never
fetches — run the loop by hand for the full picture. See the root `CLAUDE.md`.

## Two pages in this repo
- **`index.html`** → `/` — the Ace Hotel & Laundry investor model (below).
- **`edi.html`** → `/edi` — **Edi Haron**, a 19-room hostel rent tracker for the
  partner who collects rent. Same look and the same Part 1/2/3 shape as the
  Cash Transfers tab, but rent is held **per room per month** (`_rent`), because
  Edi's rents differ per room and change over time. Seeded from his 2026 book
  (Januari–Agustus); tenancy spans were derived from the month-by-month tenant
  names and verified to reproduce all 152 room-months exactly.
  Its cloud state is **Supabase row `id=2`**, saved by a plain PATCH with **no
  password** (deliberate — Edi updates his own rent collection). See
  `SETUP-EDI.sql` — **already applied 7 Aug 2026**: row 2 created by the owner
  (anon INSERT is blocked by RLS) plus policy `anon_write_edi_row` granting the
  anon key UPDATE on `id = 2` only. Reads needed nothing — the SELECT policy
  isn't id-scoped. The save sends `return=representation` and treats zero
  returned rows as failure, because an RLS-blocked write returns 200 with an
  empty array and is otherwise indistinguishable from success. `vercel.json` sets `cleanUrls` so `/edi` works without `.html`.
  Month index 0 = Jan 2026 there, vs May 2026 in `index.html` — check which page
  you're in before touching month maths.
  **Snapshots on `/edi` live inside row 2's own JSON** under `_snapshots`
  (capped at `MAX_SNAPSHOTS = 12`, oldest dropped, never nested — `saveSnapshot`
  strips `_snapshots` from the payload it stores). This is deliberately NOT the
  `snapshots` table, which `index.html`'s Save Snapshot uses for row 1 only, so
  `/edi` needed no extra SQL. Restore is two-tap (arms for 6s) and does *not*
  auto-save — it loads the snapshot and waits for Save, so a reload undoes a
  wrong restore. Because they share the row's fate, `backups/edi-YYYY-MM-DD.json`
  stays the off-row line of defence; restore that by PATCHing `data` to row 2.

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

### Dates
All date entry uses native `<input type="date">` (tap = OS calendar picker).
The *stored* value for table rows stays `DD/MM/YYYY` — `toISO()` / `fromISO()` /
`fmtLongDate()` (top of the first `<script>`) convert at the edges, so legacy
saved rows and the delinquency parser keep working. Keep that convention for any
new date field. The Accounts tab's P&L / Cash-Flow periods are **from/to picker
pairs** (`acc-pl-from|to`, `acc-cf-from|to`, listed in `ACC_DATE_IDS`, stored as
ISO); `fmtDateRange()` renders the heading label and collapses whole calendar
months (`1 May–31 Jul` → "May–Jul 2026"). `parseLegacyRange()` migrates the old
free-text `_acc_pl_period` / `_acc_cf_period` keys on load. Room rent due day is
a 1–31 `<select>` (`setDueDay`); `setCheckIn` seeds it from the picked check-in
date the first time only, never overwriting an explicit choice.

### Timeline tab (made editable 2026-08-06)
Milestones are data (`timeline`, persisted as `_timeline`), not markup. Each has
`{month, label, event, detail, auto, accent}`: `month` is an `<input type="month">`,
`label` overrides the rendered month when set (that's how "~Nov 2026" and
"Phase 2 (Future)" work), `accent:'blue'` highlights. The ✏️ Edit button flips
`tlEditing` between the presentation timeline and stacked edit cards. The two
`auto:'p1'|'p2'` milestones keep their detail line from the live model —
`renderTimeline()` (in the main model script, note the name clash with
`renderMilestones()`) caches that text on `window._tlAuto` and writes through to
`#tl-p1-detail`/`#tl-p2-detail` only if those nodes still exist, so deleting or
editing a milestone can't break `recalc()`.

### Input styling
One card system: `.input-group` + `.input-group-title` + `.input-row` +
`.input-label` (+ `.compact` for cards that size to content outside
`.inputs-grid`). The Accounts/Cash-Transfers FX boxes, the Accounts period
pickers and the Timeline editor all use it — don't hand-roll inline-styled boxes.
`.field-date` is the picker equivalent of the global `input[type=number]` look.

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
