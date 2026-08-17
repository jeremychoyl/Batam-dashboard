-- ============================================================================
-- SETUP-RECEIPTS.sql — proof-of-payment photo storage
-- Run ONCE in the Supabase SQL editor (Dashboard -> SQL Editor -> New query).
-- Until this runs, the paperclip buttons on /edi say "not switched on yet".
--
-- Creates one PRIVATE bucket shared by both rent trackers. The scope prefix in
-- each filename keeps them apart:
--     edi__room-4__m07__1755423000000.jpg     <- Edi's hostel
--     ace__room-2__m03__1755423000000.jpg     <- Ace Hotel (added later)
--
-- Private, not public: the page fetches each photo with the anon key and shows
-- it as a blob, so a transfer slip is never readable from a bare URL. Payment
-- slips carry names and bank details — a public bucket would put them one
-- guessed filename away from anyone.
--
-- Strings are dollar-quoted ($$...$$) instead of 'single quoted' because iOS
-- turns straight quotes into curly ones when text is retyped, and curly quotes
-- are a syntax error here.
-- ============================================================================

-- 1. The bucket. public=false is the point; do not flip it to true.
insert into storage.buckets (id, name, public)
values ($$receipts$$, $$receipts$$, false)
on conflict (id) do nothing;

-- 2. Anyone with the /edi link may ADD a slip. That matches the page itself,
--    which Edi saves without a password so he can do his own collection.
create policy anon_receipts_insert
  on storage.objects for insert to anon
  with check (bucket_id = $$receipts$$);

-- 3. ...and may READ slips, which is what makes the thumbnails appear.
create policy anon_receipts_select
  on storage.objects for select to anon
  using (bucket_id = $$receipts$$);

-- 4. No delete and no update policy on purpose. Without them a wrong photo can
--    only be superseded by uploading the right one, never wiped — deliberate,
--    because /edi has no password and proof of payment is exactly the kind of
--    record that must not be destroyable by anyone holding the link. Delete a
--    genuinely bad file from the Supabase Storage screen instead.

-- ── Check it worked ─────────────────────────────────────────────────────────
-- Expect one row, public = false:
--   select id, public from storage.buckets where id = $$receipts$$;
-- Expect the two policies above:
--   select policyname from pg_policies
--    where tablename = $$objects$$ and policyname like $$anon_receipts%$$;
