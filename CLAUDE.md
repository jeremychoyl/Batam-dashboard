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

  **Proof-of-payment photos (added 2026-08-17)** live in the Supabase **Storage
  bucket `receipts`**, deliberately *not* in row 2: that row is polled every 15s
  and rewritten whole on save, so a photo in it would ride every poll and an
  upload would be lost by forgetting to press Save. The **filename is the
  index** — `scope__room-slug__mNN__epoch.jpg` — so one `list` call tells the
  page which cells have proof and there is no metadata table to fall out of
  step. Keyed on the room's **name**, not its row number, because reordering a
  room would otherwise re-attach a slip to a different tenant; the `edi__` /
  `ace__` scope prefix is what lets the Ace tracker share the bucket. The bucket
  is **private** — photos are fetched with the anon key and shown as blob URLs,
  since slips carry names and bank details and `/edi` has no password. Policies
  grant anon **insert + select only**: a wrong photo is superseded by uploading
  the right one, never wiped by whoever holds the link. Setup is
  `SETUP-RECEIPTS.sql`, run once; until then the grid says so in as many words
  rather than showing every month as having no slip.
  ⚠️ Readiness is probed with a **GET for an object that cannot exist**, never
  from the `list` call: Supabase answers `200 []` when listing a bucket that was
  **never created**, identically to a real empty bucket (verified against a
  nonsense bucket name). Only a missing bucket answers `NoSuchBucket`, so that
  string is the test — anything else means the bucket is live. Three states are
  kept apart on purpose: `false` (no bucket), `'noread'` (bucket present, select
  policy missing, so uploads work but thumbnails cannot), `true`.

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
    Both the manual snapshot and the silent `autoBackup()` build their caption
    through **one** `snapshotSummary(m)`, so the two cannot record different
    things. It stores `occPct` **beside** the occupancy payback: the planning case
    has already moved once (70% → 85%), and captioning an old snapshot with
    today's rate would label a figure with a number never used to compute it.
    Snapshots saved before 2026-08-17 carry no `occPct`, so that clause is simply
    omitted for them — never back-filled.

## Tabs (each an `#panel-*` + its own `<script>` block)
Reordered 2026-08-18 to the owner's ordering. **On the bar:** Overview · Inputs ·
Renovation · Occupancy · Cash Transfers · Ace Rooms · **More ▾**. **Behind More:**
Projections · Benchmarks · Risks · Timeline · Market · Laundry (Accounts) ·
Ratings. *Ratings* was not in the owner's list; it sits with the secondary tabs
rather than being dropped, since removing an unmentioned page would lose it
silently — raise it if they want it gone.

**Overview is the landing tab** (`panel-overview` carries `active`, and the last
script block calls `switchTab('overview', …)` once at load). The More menu is a
**centred sheet, not a dropdown**: `.tabs` is a horizontally scrolling flex row,
so an absolutely positioned menu inside it is clipped — invisibly, until someone
taps on an iPad. `switchFromMore()` routes through `switchTab` passing the More
button as the clicked tab so the bar still shows something active, and the
outermost `switchTab` patch resets the More label when a bar tab is chosen. That
patch must stay in the **last** script block to remain outermost.
Each feature-script patches `collectInputs`/`applyInputs`/`switchTab` to persist
and render its own slice — keep that chaining intact when adding features.

`switchTab` also calls **`settlePanelCharts()`** on the panel it reveals (added
2026-08-17). `recalc()` builds every chart at once, including those on
`display:none` panels where the canvas has no size and Chart.js falls back to
300×150; revealing the panel resized the axes but left the datasets unpainted,
which is why the Occupancy tab drew a complete grid with no lines on it. It is
not dead code just because the Benchmarks radar happens to survive without it.

### Market tab (added 2026-08-14)

Charts scraped **asking prices by area** from BatamPropBot's archive — the only
Batam price series that exists, because we create it. Two dot strips (rooms in
IDR/month, shophouses in IDR-billions), a written summary per chart, and a table
view.

**Data comes from `market-data.json`, committed in this repo.** Not a live fetch:
this page is static on Vercel and the propbot API sends no CORS headers, so the
browser cannot read the archive directly — and a committed file keeps the tab
working when Railway is asleep. Regenerate with `propbot/ops/export-archive.py`,
which writes here *and* to `propbot/data/market-archive.json`, then commit both
repos. **The tab does not update itself**; new scans reach it only via that step.

Four things that are deliberate, not stylistic:

- **Dots, not bars.** With 1–4 listings an area, a bar implies a robustness the
  data lacks and hides that "Batu Ampar" is one seller's ask. Coincident prices
  are dodged vertically — drawn flat, four listings at two prices stacked into
  two dots above a label reading `n=4`.
- **Two charts, never one.** Rent is IDR/month and shophouses are outright sale
  prices; a shared axis is meaningless and a dual axis worse.
- **Colour is validated, not chosen.** Focus area vs other, using the dataviz
  skill's categorical slots 1–2 (`#3987e5`/`#d95926`) checked against THIS
  page's surface `#0e1929`. The dashboard's own amber `#f59e0b` was the
  intuitive pick and **fails** the dark lightness band at 0.769 — run
  `validate_palette.js` before changing these.
- **Focus areas with no listings still get a row**, labelled `n=0` and "no
  listings found — not a price of zero". Omitting them silently is the same
  failure propbot's blocked-vs-empty contract exists to prevent.

⚠️ The summaries state percentages **in the direction the sentence reads** —
"X is N% below Y" is `1 - X/Y`, not `Y/X - 1`. These benchmark the market
against the owner's own room rates, so the two are not interchangeable. And
exact figures are used wherever a number is read; the compact `1.8 m` form is
for axis ticks only, because `(2.05).toFixed(1)` floats down to `"2.0"` and
would print a 2,050,000 median as "IDR 2 m".

### Phase-specific laundry lease (2026-08-17)
The laundry rent is **two inputs**, `in-laundryAnnualRentP1` (30,000,000) and
`in-laundryAnnualRentP2` (60,000,000) — part of the shophouse in Phase 1, the
whole building in Phase 2. Ace's lease is unchanged across phases. Consequently
**there is no single `monthlyRental` or `totalMonthlyCost`**: `calc()` returns
`monthlyRentalP1/P2` and `totalMonthlyCostP1/P2`, and every Phase 1 figure must
use the P1 pair or Phase 1 looks dearer to run than it is. That includes the
occupancy curve's laundry Ph.1 line, the laundry Ph.1 breakeven card and the 85%
payback.

`applyInputs()` migrates the legacy single key: a row saved before the split
carries `in-laundryAnnualRent`, which was the **Phase 2** lease, so it is copied
into the P1-absent Ph.2 field rather than letting this file's default overwrite
the owner's own number. Press Save Changes once to store the two new keys.

Per-property rent is now simply `annualLease / 12`. The old
`monthlyRental × share-of-total` formula computed exactly the same number and
only looked like a cost allocation.

### Operating cost is a per-unit rule (2026-08-17)
Two inputs, `in-opexFreeUnits` and `in-opexPerUnit`: the first N units **across
the whole business** cost nothing to run, every unit after that costs the same
amount. Owner's rule — confirmed business-wide, *not* per property, on
2026-08-17 after first being built the other way.

The occupancy curve and the breakeven cards still need a cost per property, so
`opexSplit()` charges every unit and then shares the free-unit discount out
**pro-rata by unit count**. Any other split would leave the two property figures
not summing to the business total; the calc harness asserts that they do.

⚠️ **There is no saved per-unit figure at all — corrected 2026-08-18.** This
file previously said the live saved value was 300,000, raised from 250,000 on
2026-08-17. Audited against the actual row that day: **`in-opexPerUnit` is not a
key in row 1**, which still carries the pre-rework `in-opex: 9000000` and
`in-laundryAnnualRent: 60000000`. The saved row predates this feature and has
never been re-saved, so every operating-cost figure on the live page comes from
**this file's HTML default of 250,000**. Whatever raise was made was never
persisted. At 250,000 and today's counts the rule produces **4,500,000/mo in
Phase 1 and 6,000,000 in Phase 2** (18 and 24 charged units); at 300,000 it
would be 5,400,000 and 7,200,000 — the old note's "4,800,000 / 5,700,000" did
not match any live room count and was wrong on its own terms.

The gap is worth roughly **SGD 5,162** on the headline five-year profit, so it
was the owner's number to settle, not one to infer.

✅ **Settled: the owner confirmed 250,000 per unit on 2026-08-18**, asked
directly after the audit above. So the figure the page has been showing is the
right one — it was only ever *unbacked*, not wrong. It stops being a default and
becomes a saved value the first time anyone presses Save Changes.

⚠️ **Never press Save on the owner's behalf to "persist" a default.** Saving
writes whatever is on screen into the shared row that partners read, it needs
the edit password, and it commits **every** unsaved field at once, not the one
you came to change. Eight keys are in that state as of 2026-08-18 —
`in-opexPerUnit`, `in-opexFreeUnits`, `in-laundryAnnualRentP1/P2`,
`in-aceRent2`, `in-aceP1b`, `in-aceP2b`, `in-sgAppreciation` — every one of them
currently the file's default rather than a chosen figure. Ask, list what would
be written, then let the owner save.

Of those, `in-laundryAnnualRentP1` (30,000,000) is the one still worth checking:
the legacy key migrates into the **Phase 2** field as designed, so Phase 1's
figure is this file's guess and has never been confirmed by anyone.

The per-unit rule replaced a flat `in-opex` figure that was then
split ⅔ Ace / ⅓ laundry by a hardcoded fraction — an allocation nobody had
chosen, which alone set the laundry's breakeven occupancy and was invisible on
screen. That legacy key is the `in-opex: 9000000` still sitting unused in the
saved row: the old flat figure was nearly double what the rule now computes, so
the model's operating cost effectively halved when this shipped and no saved row
has ever confirmed the new one.

So opex is now **per property and per phase** and follows the room counts:
`laundryOpexP1/P2`, `aceOpexP1/P2`, summed into `monthlyOpexP1/P2`. Adding a room
anywhere raises cost automatically — there is no longer a cost figure to keep in
step by hand. The Inputs card shows what the rule produces for both phases, and
the breakeven cards' tap-through spells out `units − free = charged × per-unit`.

The free allowance is granted **once across the whole business**, not per
property: 20 units in Phase 1 less 2 free = 18 charged, which is what the live
page computes. Commit `3009711` ("Grant the free operating-cost units once
across the business, not per property") settled this on the owner's own reading,
confirmed business-wide.

⚠️ **This paragraph said the opposite until 2026-08-18** — it described the
per-property split (laundry gets 2, Ace gets 2) as live, and that had been wrong
since `3009711`. The two readings differ by 500,000/month, so a stale note here
is not cosmetic: it names the cheaper option as the one in force. Verified
against the running page, not the source, when corrected.

### Investment Snapshot tiles (reordered 2026-08-18)
Owner's ordering: money in → how fast it comes back → what it earns → what it
totals. Eight tiles: Initial Investment Ph.1 · Total Investment Ph.1+2 · Payback
Ph.1 · Payback Ph.2 · Monthly Net Ph.1 · Monthly Net Ph.2 · 5-Year Cumulative
Profit · **5-Year Profit After Capital** (`cum5 − totalP2Invest`, the owner's own
definition of "net").

Extended to **10 tiles** the same day: after-capital profit is split by phase
(each measured against **its own** capital — Phase 1 never spends the Phase 2
construction money), and **Annual Net Yield** is back as tile 10.

The 85% occupancy paybacks live in the grey `kpi-sub` lines instead of taking two
more tiles. ⚠️ There is deliberately **no "5-year yield" tile**: it is always
exactly 5 × the annual yield (405.7% vs 81.1%), so it could only ever restate its
neighbour. Don't add it back.

**The yield tile compares against Singapore property TOTAL return** — price
appreciation (`in-sgAppreciation`, 5.3%/yr, URA index since 2022) *plus* rental
yield (`in-sgYield`, 3.3%) ≈ 8.6%/yr. Comparing an income yield against price
growth alone would flatter this business by ignoring the rent a Singapore owner
also collects. ⚠️ The footnote under the grid (`#yield-note`) carries the caveat
that matters and must not be dropped: this is **income on capital, not capital
growth**, and a Singapore flat is still an asset after five years whereas this is
a lease — at the end there is no asset, only the refundable deposit. The
appreciation figure is an input precisely because it ages.

The after-capital tile turns red and shows a minus when the 5-year profit has not
covered the capital, rather than printing a bare negative in teal.

### Phase 2 Expansion Capex box (split 2026-08-18)
Phase 1 → Phase 2 is **two unrelated things at once**, and this box used to blend
them into one "return on incremental capex": the rooms you build, and a laundry
lease that steps up (30m → 60m/yr) whether or not you build them. Charging the
lease increase against the construction spend made the rooms look like 27%/yr
when they are 33%/yr.

The split follows **causation**: extra room revenue is caused by the capex, and so
is the extra operating cost (the rule is per unit, so 3 more rooms = 3 more
charged units). The lease step-up and the reception sublet land on the Phase 2
calendar regardless, so they sit in their own section. The two sections must sum
to `incrProfit` — verified, SGD 2,327 + (−431) = 1,896.

The box also **warns when `newRooms` disagrees with the rooms the counts actually
add** (7 paid for vs 3 earning, as of writing) and computes the return on the
earning rooms, since that is the honest denominator until the owner settles which
input is wrong.

### Occupancy tab
⚠️ **Occupancy scales room REVENUE, never profit.** Rent, operating cost and the
reception sublet do not fall when rooms sit empty, so profit at 70% occupancy is
*far* below 70% of full-occupancy profit. The "Ph.2 Annual Profit by Occupancy"
bars got this wrong until 2026-08-17 — they multiplied `annualP2_SGD` by the
occupancy rate and ran the axis to **130%**, which an occupancy rate cannot do.
At 70% that printed SGD 17.1k against a true 12.2k, 40% too high, in exactly the
range the owner plans around. Both charts now use the same arithmetic, so the
100% bar equals the model's annual net and the two cannot disagree.
`Payback @ N% occupancy` in the Live Output Summary comes from **`OCC_STRESS` in
`calc()`** — one constant, currently **0.85** (owner's planning case; it was 0.70
when first added on 2026-08-17 and changed the same day). That constant drives the
two figures, the tile captions *and* the highlighted bar, so the page cannot say
85% in one place and 70% in another; change it there and nowhere else. The bars
step in 5% so any planning case on a multiple of five lands on a real bar. Tiles
print "never at N%" rather than a negative month count when the phase loses money
at that level.
The Ace Ph.2 curve is **dashed** because it sits exactly on Ph.1 whenever both
phases hold the same rooms, and a hidden series reads as a missing one.

The four **breakeven cards are tap-through** (`showBreakeven()`, added
2026-08-17): each lays out the model's own figures — revenue at 100%, the rent
and operating cost charged, the reception offset on laundry Ph.2 — and then the
division that produces the percentage. Built from values `calc()` returns rather
than recomputed, so the card and its explanation cannot disagree. This is also
where the **operating-cost split becomes visible**: the model charges the Ace
side ⅔ and the laundry ⅓ of the single opex figure by a **fixed fraction, not an
input**, and that assumption alone sets the laundry's 83.3% breakeven — at a 20%
share it would be 73.8%. ⚠️ That fraction is written in two places
(`calc()` and `renderOccupancy`); keep them in step or the cards and the curve
will diverge.

### Ace Rooms tab (scaffolded 2026-08-17)
Room-by-room rent tracking for the **13 Ace Hotel rooms** — Section A (room
details) + Section B (12-month payment grid), persisted in row 1 under
`_aceRooms` / `_acePayments`. Deliberately **empty**: 13 rooms named Room 1–13
with no tenant, no rent, nothing ticked. The model only says 11 rooms at 3m and
2 at 1.2m, never *which* room is which, so filling any of it in would be
inventing figures on an investor-facing page. KPIs print **—**, not `Rp 0`, while
a column is unfilled, because zero reads as a measured figure.

Distinct from the **laundry** 7-room tracker in Cash Transfers Part 3 and from
Edi's hostel on `/edi` — different business, and this page needs the edit
password to save while `/edi` deliberately does not. It shares `/edi`'s one
Storage bucket for proof-of-payment photos under the **`ace__` scope**, so
neither tracker can see the other's slips (unit-tested: `ace__room-2__…` and
`edi__room-2__…` never cross). Calendar is the existing `MONTHS_12`
(May 2026–Apr 2027) so the page never carries two month baselines.

⚠️ Every identifier in that block is prefixed `ace`. This file already has
`renderRooms`, `togglePayment` and `renderPaymentGrid` for the laundry tracker,
and a duplicate top-level name silently replaces the earlier one — see the
`renderOccupancy` note above for what that costs. `markDirty` now also ignores
`type="file"`, so picking a photo does not flag the model dirty and stall the
cloud poll behind a save with nothing in it.

### Cash Transfers tab (rebuilt 2026-08-02)
Three sections: **Part 1 — Capital Expenditure** (renovation spend ledger,
running balance, avg cost/room), **Part 2 — Rental Collections** (chained from
Part 1's closing balance, IDR+SGD), **Part 3 — Room Management** (7-room table +
12-month payment tracker with tap-to-toggle ⬜→✅→🔴, delinquency alerts, period
archiving). Replaced the old single flat `_transfers` ledger; the live-FX puller
still refreshes it via a `renderTransferDerived()` alias.

⚠️ Its Section C renderer is **`renderRoomOccupancy()`**, renamed 2026-08-17.
It was called `renderOccupancy()` — and because this block is parsed *after* the
model script, that declaration silently replaced the model's own
`renderOccupancy(m)`, leaving the **Occupancy tab blank** (no chart, no
breakeven cards, no console error) from the 2026-08-02 rebuild until the rename.
Same trap as `renderTimeline`/`renderMilestones` below: these blocks share one
global scope, so a duplicate `function` name is a silent overwrite, not an
error. Check for a clash before naming a new top-level function.

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

### Phone layout (added 2026-08-18)
Everything lives inside media queries, so a wide screen renders exactly what it
rendered before — verified by diffing the rendered text of all seven panels
against the previous commit.

Two breakpoints. **≤900px** pins the tab bar (`position:sticky`; it already had
a `z-index` that did nothing without a position) and tightens page padding —
fourteen panels reachable only from that bar, and the panels are long. **≤600px**
is the phone tier.

The rule that matters most is `input, select, textarea { font-size:16px }`. iOS
Safari magnifies the whole page whenever a focused field is under 16px and does
**not** zoom back out; every input here was 11–13px. This is the same fix
`edi.html` got first, and 16px is a floor the browser imposes, not a preference.
Measured on the real engine: 27 of 27 inputs now report exactly 16px.

Two different techniques, chosen by what the table *is*:

- **Wide edit tables → `.rt-stack`.** The ledgers and room-detail tables are
  580–940px of columns; they scrolled inside their card, so fixing one tenant's
  name meant dragging a table through a 340px window. Below 600px each row
  becomes a card and each cell a labelled line, the label coming from that
  cell's own **`data-label`**. There is deliberately **no second markup path** —
  it is the same DOM restyled, so phone and desktop cannot show different
  figures and a renderer edited later cannot leave a stale card view behind.
  Six tables use it: reno, Ratings scorecard, Cash Transfers P1 and P2, laundry
  Section A, Ace Section A. **A new `<td>` needs a `data-label`** or it renders
  on a phone as a value with no column header; the cell holding the row's ✕ gets
  `class="rt-act"` instead, which turns it into a full-width "✕ Remove".
- **The two 12-month payment grids → cards.** A grid of month buttons has no
  sensible row-per-line form, so these are built as one card per room with a 6×2
  month pad — from the **same loop** as the table, exactly as `edi.html` does it,
  so the arithmetic runs once and is rendered twice. `isPhone()` / `PHONE_MQ`
  (defined next to `PAYMENT_STATES`) picks the markup, and a `change` listener at
  the end of the file re-renders both on rotation, since these choose at render
  time while `.rt-stack` follows on its own.
  ⚠️ The summary card carries the table's **Monthly Total row** as a 12-cell
  readout pad. Don't drop it — without it the phone silently loses the
  month-by-month figures the wide view shows along the bottom.

`#footer-bar` is `position:fixed` and wraps to **93px** on a phone against a
28px desktop line, hiding the end of every tab. `clearFooterBar()` sets the
content's bottom padding from the bar's *measured* height, on load, on resize
and after the save/snapshot paths — **not** a hardcoded number, because the bar
re-wraps as its own save-timestamp text changes length.

Tiles go two-up (`.grid-kpi`, and `.tile-grid`, a hook added to the five
inline-styled `auto-fill` grids): at this width `minmax(170–200px,1fr)` resolves
to one column, which turned the ten-tile Investment Snapshot into ten screens.
Phone buttons get `min-height:44px` — measured, several were 23–39px.

The occupancy Gantt still scrolls, because twelve months genuinely need width;
it gets a narrower name column and a `.phone-hint` telling you to swipe. That
hint is the *only* element added to the desktop DOM, and it is `display:none`
above 600px.

Verified with headless Chrome via `.claude/chrome`: no horizontal page overflow
at 390 / 430 / 768px on any tab, and all 84 laundry and 156 Ace room-months
remain individually tappable in the card view — the same counts the wide table
offers.

**`edi.html` was brought to the same standard later the same day.** It already
had the 16px rule and the payment cards from its own commit; what it lacked was
`.rt-stack` (its two rent ledgers and Section A were 820–900px and still had to
be dragged sideways), the 44px minimum — its ✅/❌ room-status toggles measured
**18px**, less than half the guideline and adjacent to each other — the two-up
tiles, the Gantt hint and `clearFooterBar()`. Both pages now carry the same
patterns under the same names, so a fix to one is a fix worth porting to the
other; check both before assuming a phone problem is page-specific. One
deliberate difference: edi's `min-height:44px` rule also covers `.header button`,
because unlike `index.html` this page keeps 💾 Save Changes in the header, and
that is the control Edi presses after every rent update.

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
