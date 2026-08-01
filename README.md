# Batam-dashboard

Shared live financial model for the **Ace Hotel & Laundry Shophouse**, Batam.

Live at **https://batam-dashboard.vercel.app/** — a single `index.html`,
auto-deployed by Vercel on every push to `main`. No build step, no dependencies
beyond Chart.js and Google Fonts from CDN.

## Tabs

| # | Tab | What it is |
|---|---|---|
| 1–9 | Inputs → Ratings | The investment model. Everything derives from the `in-*` fields via `calc()`. |
| 10 | 📒 Laundry | P&L, cash flow and balance sheet from the accounting software. |
| 11 | 💸 Cash Transfers | Ledger of capital flows between the two partners. |

Tabs 10 and 11 are **deliberately isolated** from tabs 1–9 and from each other —
changing anything in one moves nothing in the others. They share only the Save
button. There are three independent exchange rates: `in-fx` (model), `acc-fx`
(Laundry book rate), `tr-fx` (ledger display).

The only intentional cross-link inside tabs 1–9: the Renovation total drives
**Renovation Cost** on Inputs, which flows into investment, payback and yield.

Note the Laundry tab's panel id is still `accounts` and its saved keys are still
`_acc_*` — only the visible label was renamed, so stored models keep loading.

## Storage

Supabase project `kkhkqxsndinsawvagxhx`, **Free plan**.

- `inputs` — one row (`id=1`) holding the entire model as JSON
- `snapshots` — named versions, restorable from the Inputs tab
- `app_config` — private, holds the edit password; RLS hides it from the anon key

## Writes are password-protected

**Reading is open. Saving, restoring and deleting are not.**

Direct `PATCH` / `POST` / `DELETE` against `inputs` and `snapshots` are rejected
by row-level security. All writes go through `SECURITY DEFINER` functions that
verify the password *inside Postgres*:

| Function | Used by |
|---|---|
| `save_model(pw, payload)` | Save Changes, Restore |
| `add_snapshot(pw, name, payload, summary)` | Save Snapshot, auto-backups |
| `remove_snapshot(pw, id)` | Delete snapshot |

The page never checks the password itself — it forwards what the user typed and
reads back success or failure, so viewing the page source reveals nothing.

> **If you add a feature that writes, call one of these functions.** A direct
> table write will silently affect zero rows and still return HTTP 204.

Two policies exist on each data table and nothing else: `public read inputs` and
`public read snapshots`, both `FOR SELECT USING (true)`. If writes ever start
working without a password, check `pg_policies` for a permissive policy that has
crept back in — enabling RLS does nothing while one exists.

## Safety behaviour

- **Concurrent editing** — the model is polled every 15s. If a second person
  saves while you have unsaved edits, their version is *held* and a banner
  offers "Load their version" / "Keep mine". Nothing is overwritten silently.
- **Reset Defaults** and **Restore snapshot** write an automatic
  `🔒 Auto-backup before …` snapshot first, and abort if that backup fails.
- Closing the tab mid-edit warns.

There are **no database backups** on the Free plan, and `pageinspect` /
`pg_dirtyread` are unavailable, so a bad write is unrecoverable. Take a snapshot
before large edits.

## Live exchange rate

Fetched on every page load from `open.er-api.com` (free, no key, CORS-enabled;
XE publishes no free API). Applied to the model and ledger rates, shown as an
amber `● LIVE · <date>` stamp under the rate box. Typing your own rate unticks
"Use live market rate" so the override survives a refresh.

The Laundry book rate is deliberately **not** auto-updated — those statements
come out of the accounting software at a fixed rate, and restating them at
today's rate would misreport history.

## Reconciliation check

The Cash Transfers ledger ties to the Laundry accounts:

- closing balance = **Cash & Bank**
- total spent, less the salary/CCTV items = **Fixed Assets**

If that tie breaks, one of the two has drifted.

## Editing notes

- Inline `<script>` blocks share one global scope. Declaring the same `const` in
  two blocks throws `SyntaxError` and silently kills the second block. Check with:
  concatenate every inline block and run `node --check`.
- Don't rebuild a table's `innerHTML` on `oninput` — it destroys the field being
  typed into and drops focus after each keystroke. Keep values in a JS object,
  render the markup once, and update only the derived cells.
