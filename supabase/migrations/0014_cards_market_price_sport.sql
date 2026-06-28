-- 0014: Add market_price + sport columns to cards table.
-- Closes the CardDTO.toCard() gap where pulled cards couldn't reconstruct
-- the view Card's marketPrice/sport (always nil). market_price is the
-- latest ungraded (Raw) price from the rollup; sport disambiguates sports
-- cards (basketball, baseball, …) so the client can filter without a join.

alter table cards add column if not exists market_price numeric;
alter table cards add column if not exists sport text;  -- 'basketball'|'baseball'|'football'|'soccer'|'hockey' (null for non-sports)

-- Backfill sport from the existing sample data conventions if a sport column
-- is empty but the card name/set hints at a sport. This is a no-op on a fresh
-- database; on databases with seeded data it populates sport where possible.
update cards
   set sport = 'basketball'
 where sport is null
   and game = 'sports'
   and (name ilike '%jordan%' or name ilike '%lebron%' or name ilike '%kobe%'
        or name ilike '%curry%' or name ilike '%durant%');

update cards
   set sport = 'baseball'
 where sport is null
   and game = 'sports'
   and (name ilike '%trout%' or name ilike '%mantle%' or name ilike '%jeter%'
        or name ilike '%ruth%' or name ilike '%ohtani%');

update cards
   set sport = 'football'
 where sport is null
   and game = 'sports'
   and (name ilike '%brady%' or name ilike '%mahomes%' or name ilike '%rodgers%'
        or name ilike '%manning%');

update cards
   set sport = 'soccer'
 where sport is null
   and game = 'sports'
   and (name ilike '%messi%' or name ilike '%ronaldo%' or name ilike '%pele%'
        or name ilike '%mbappe%');

update cards
   set sport = 'hockey'
 where sport is null
   and game = 'sports'
   and (name ilike '%gretzky%' or name ilike '%crosby%' or name ilike '%ovechkin%');

-- Index for filtering sports cards by sport.
create index if not exists cards_sport_idx on cards(sport) where sport is not null;
