-- ═══════════════════════════════════════════════════════════════════════════
-- ONE-TIME SETUP for the Edi Haron dashboard (/edi)
--
-- Run this in the Supabase SQL editor:
--   Supabase dashboard → your project → SQL Editor → New query → paste → Run
--
-- Why it can't be done from the page: the anon key is allowed to READ and to
-- UPDATE, but RLS blocks INSERT, so row 2 has to be created by the project
-- owner. Until this runs, /edi loads and works but cannot save, and says so.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── STEP 1 ── Create Edi's row. Safe to re-run; it won't touch row 1.
insert into public.inputs (id, data)
values (2, '{}'::jsonb)
on conflict (id) do nothing;


-- ── STEP 2 ── Find out how the existing save_model checks the password, so
-- the new function checks it exactly the same way. RUN THIS ON ITS OWN FIRST
-- and read the output:
--
--     select prosrc from pg_proc where proname = 'save_model';
--
-- Copy the `if ... then raise exception 'wrong password'` line out of it and
-- paste it over the marked line in STEP 3 below. The template assumes the
-- password lives in a table called `app_config`; adjust to match yours.


-- ── STEP 3 ── The save function for row 2. Mirrors save_model, but writes
-- id = 2 instead of id = 1.
create or replace function public.save_edi_model(pw text, payload jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- ▼▼▼ REPLACE THIS LINE with the same password check save_model uses ▼▼▼
  if pw is distinct from (select value from public.app_config where key = 'edit_password') then
    raise exception 'wrong password';
  end if;
  -- ▲▲▲ REPLACE THIS LINE ▲▲▲

  update public.inputs
     set data = payload,
         updated_at = now()
   where id = 2;
end;
$$;

grant execute on function public.save_edi_model(text, jsonb) to anon;


-- ── STEP 4 ── Confirm it worked.
select id, updated_at from public.inputs order by id;
-- Expect two rows: 1 (Ace Hotel) and 2 (Edi Haron).

-- Then open https://batam-dashboard.vercel.app/edi and press Save Changes.
-- The header should go from "⚠ cloud setup not run yet" to "✓ saved".


-- ═══════════════════════════════════════════════════════════════════════════
-- ROLLBACK, if you ever want Edi's dashboard gone from the database:
--   drop function if exists public.save_edi_model(text, jsonb);
--   delete from public.inputs where id = 2;
-- Row 1 (the Ace Hotel model) is never touched by any statement above.
-- ═══════════════════════════════════════════════════════════════════════════
