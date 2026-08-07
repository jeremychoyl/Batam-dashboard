-- ═══════════════════════════════════════════════════════════════════════════
-- SUPABASE SETUP for the Edi Haron dashboard (/edi)
--
-- STATUS: ✅ ALREADY APPLIED — 7 Aug 2026. Nothing here needs running again.
-- This file is the record of what was done, kept so it can be re-created or
-- undone. Both statements are safe to re-run if the project is ever rebuilt.
--
-- Run in: Supabase dashboard → SQL Editor → New query
--   https://supabase.com/dashboard/project/kkhkqxsndinsawvagxhx/sql/new
-- ═══════════════════════════════════════════════════════════════════════════


-- ── 1. Edi's row ───────────────────────────────────────────────────────────
-- /edi keeps its state in inputs row id=2. Row 1 is the Ace Hotel model and is
-- never touched by anything in this file. The anon key may not INSERT (RLS),
-- so the row has to be created here by the project owner.

insert into public.inputs (id, data) values (2, jsonb_build_object());

-- Note jsonb_build_object() rather than '{}'::jsonb — same empty object, but
-- with no quote characters, which matters when pasting from an iPhone (see
-- the gotchas at the bottom).


-- ── 2. Write access to row 2 ───────────────────────────────────────────────
-- READS already worked: the existing SELECT policy is not restricted by id, so
-- no read policy was needed. WRITES were blocked — a PATCH from the anon key
-- returned 200 OK having changed zero rows. /edi saves with a plain UPDATE and
-- no password (deliberate: Edi updates his own rent collection), so it needs
-- this. `using (id = 2)` cannot match row 1, so row 1 keeps exactly the
-- protection it had before.

create policy anon_write_edi_row on public.inputs
  for update to anon
  using (id = 2)
  with check (id = 2);


-- ── 3. Verify ──────────────────────────────────────────────────────────────
select id, updated_at from public.inputs order by id;
-- Expect rows 1 and 2.

select policyname, cmd, qual, with_check
from pg_policies where tablename = 'inputs' order by policyname;
-- Expect anon_write_edi_row among them, scoped to id = 2.

-- Verified from outside on 7 Aug 2026: writing row 2 with the anon key
-- succeeds; writing row 1 with the same key changes zero rows and leaves its
-- updated_at untouched.


-- ═══════════════════════════════════════════════════════════════════════════
-- GOTCHAS worth remembering
--
-- • iOS Smart Punctuation curls straight quotes, so '{}'::jsonb arrives as
--   '{}'::jsonb with curly quotes and Postgres fails with
--   "42601: unterminated quoted string". It also ate a bracket from
--   `with check (id = 2)`. Prefer SQL with no quote characters, run one
--   statement at a time, or turn Smart Punctuation off
--   (Settings → General → Keyboard).
--
-- • The SQL editor will happily re-run a stale tab: an identical error came
--   back twice with only the timestamp changed, because the pasted text never
--   replaced the old query. Use a NEW query tab if an error looks unchanged.
--
-- • A blocked UPDATE is not an error. PostgREST returns 200 with an empty
--   array, so saveToSupabase() in edi.html sends `Prefer: return=representation`
--   and treats zero returned rows as a failure. Don't remove that — without it
--   a silently-blocked save looks identical to a successful one.
--
--
-- IF YOU LATER WANT A PASSWORD ON /edi
--   Drop the policy below, then ask Claude to add a save_edi_model(pw, payload)
--   function mirroring how save_model checks the password, and to point
--   edi.html back at an RPC call.
--
-- ROLLBACK — remove Edi's dashboard from the database entirely:
--   drop policy if exists anon_write_edi_row on public.inputs;
--   delete from public.inputs where id = 2;
-- Row 1 is unaffected by both statements.
-- ═══════════════════════════════════════════════════════════════════════════
