-- ═══════════════════════════════════════════════════════════════════════════
-- ONE-TIME SETUP for the Edi Haron dashboard (/edi)
--
-- Run in: Supabase dashboard → SQL Editor → New query → paste → Run
--   https://supabase.com/dashboard/project/kkhkqxsndinsawvagxhx/sql/new
--
-- Why it can't be done from the page: the anon key may read and update, but
-- RLS blocks INSERT, so row 2 has to be created by the project owner.
-- Nothing here touches row 1 (the Ace Hotel model).
-- ═══════════════════════════════════════════════════════════════════════════


-- ── STEP 1 ── Create Edi's row. Safe to re-run.
insert into public.inputs (id, data)
values (2, '{}'::jsonb)
on conflict (id) do nothing;

select id, updated_at from public.inputs order by id;
-- Expect two rows: 1 and 2.


-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 2 — ONLY IF SAVING STILL FAILS
--
-- /edi saves with a plain UPDATE and no password, by choice. If pressing Save
-- reports "nothing was saved", the UPDATE policy on `inputs` does not let the
-- anon key write. This adds a policy that lets it write ROW 2 ONLY, leaving
-- row 1 as protected as it is today.
-- ═══════════════════════════════════════════════════════════════════════════

-- create policy "anon may update Edi's row"
--   on public.inputs
--   for update
--   to anon
--   using (id = 2)
--   with check (id = 2);


-- ═══════════════════════════════════════════════════════════════════════════
-- IF YOU LATER WANT A PASSWORD ON /edi
-- Ask Claude to put it back: it needs a save_edi_model(pw, payload) function
-- mirroring save_model's password check, and the policy above dropped again.
--
-- ROLLBACK — remove Edi's dashboard from the database entirely:
--   drop policy if exists "anon may update Edi's row" on public.inputs;
--   delete from public.inputs where id = 2;
-- ═══════════════════════════════════════════════════════════════════════════
