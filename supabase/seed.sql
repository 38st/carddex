-- Seed data for local/dev: a realistic Card Ladder-style market for the 8
-- tracked cards. Runs after migrations on `supabase start` / `supabase db reset`.
-- Mirrors the app's bundled SampleData so the live API returns familiar values.

-- Catalog rows (FK target for sales + grade values) -------------------------
insert into cards (id, game, name, set_name, number, rarity, image_url) values
  ('sports-fleer86-57',  'sports',  'Michael Jordan RC',      '1986 Fleer',          '57',     null,         'https://blog.justcollect.com/hs-fs/hubfs/Jordan-1.jpg'),
  ('sports-topps03-111', 'sports',  'LeBron James RC',        '2003 Topps Chrome',   '111',    'Refractor',  null),
  ('sports-bowman00-236','sports',  'Tom Brady RC',           '2000 Bowman',         '236',    null,         'https://www.joesalbums.com/cdn/shop/files/tom_brady_2000_bowman_rookie_football_card.jpg'),
  ('sports-topps11-175', 'sports',  'Mike Trout RC',          '2011 Topps Update',   'US175',  null,         null),
  ('sports-mega04-71',   'sports',  'Lionel Messi RC',        '2004 Megacracks',     '71',     null,         null),
  ('sports-opc79-18',    'sports',  'Wayne Gretzky RC',       '1979 O-Pee-Chee',     '18',     null,         null),
  ('pkm-base-4',         'pokemon', 'Charizard',              'Base Set',            '4/102',  'Holo Rare',  'https://images.pokemontcg.io/base1/4_hires.png'),
  ('ygo-lob-001',        'yugioh',  'Blue-Eyes White Dragon', 'Legend of Blue Eyes', 'LOB-001','Ultra Rare', 'https://images.ygoprodeck.com/images/cards/89631139.jpg')
on conflict (id) do nothing;

-- Per-grade value + population (population/change carried on the top grade) ---
insert into card_grade_values (card_id, grade, market_price, population, change_30d) values
  ('sports-fleer86-57',  'PSA 10',  95000,   320,  6.8),
  ('sports-fleer86-57',  'PSA 9',   12000,   null, 6.8),
  ('sports-fleer86-57',  'Raw',     1800,    null, 6.8),
  ('sports-topps03-111', 'PSA 10',  28000,   1840, -3.1),
  ('sports-topps03-111', 'PSA 9',   3500,    null, -3.1),
  ('sports-topps03-111', 'Raw',     650,     null, -3.1),
  ('sports-bowman00-236','PSA 10',  52000,   760,  11.2),
  ('sports-bowman00-236','PSA 9',   2800,    null, 11.2),
  ('sports-bowman00-236','Raw',     900,     null, 11.2),
  ('sports-topps11-175', 'PSA 10',  4200,    5400, -1.4),
  ('sports-topps11-175', 'PSA 9',   900,     null, -1.4),
  ('sports-topps11-175', 'Raw',     220,     null, -1.4),
  ('sports-mega04-71',   'PSA 10',  18000,   410,  8.5),
  ('sports-mega04-71',   'PSA 9',   1200,    null, 8.5),
  ('sports-mega04-71',   'Raw',     300,     null, 8.5),
  ('sports-opc79-18',    'PSA 10',  1600000, 2300, 2.2),
  ('sports-opc79-18',    'PSA 9',   5000,    null, 2.2),
  ('sports-opc79-18',    'Raw',     900,     null, 2.2),
  ('pkm-base-4',         'PSA 10',  12000,   9100, 4.1),
  ('pkm-base-4',         'PSA 9',   1600,    null, 4.1),
  ('pkm-base-4',         'Raw',     320,     null, 4.1),
  ('ygo-lob-001',        'PSA 10',  6500,    3200, 1.1),
  ('ygo-lob-001',        'PSA 9',   600,     null, 1.1),
  ('ygo-lob-001',        'Raw',     90,      null, 1.1)
on conflict (card_id, grade) do update
  set market_price = excluded.market_price,
      population   = excluded.population,
      change_30d   = excluded.change_30d;

-- Recent completed sales -----------------------------------------------------
insert into card_sales (card_id, grade, price, platform, sold_at) values
  ('sports-fleer86-57',  'PSA 9', 12250, 'eBay',      now() - interval '2 days'),
  ('sports-fleer86-57',  'PSA 9', 11800, 'Goldin',    now() - interval '6 days'),
  ('sports-fleer86-57',  'Raw',   1750,  'eBay',      now() - interval '9 days'),
  ('sports-topps03-111', 'PSA 9', 3450,  'eBay',      now() - interval '1 days'),
  ('sports-topps03-111', 'PSA 10',27500, 'PWCC',      now() - interval '8 days'),
  ('sports-bowman00-236','PSA 9', 2900,  'eBay',      now() - interval '3 days'),
  ('sports-bowman00-236','Raw',   850,   'eBay',      now() - interval '5 days'),
  ('sports-topps11-175', 'PSA 9', 910,   'eBay',      now() - interval '2 days'),
  ('sports-mega04-71',   'PSA 9', 1250,  'eBay',      now() - interval '4 days'),
  ('sports-opc79-18',    'PSA 9', 4950,  'Heritage',  now() - interval '7 days'),
  ('pkm-base-4',         'PSA 9', 1650,  'eBay',      now() - interval '1 days'),
  ('pkm-base-4',         'Raw',   320,   'TCGplayer', now() - interval '4 days'),
  ('ygo-lob-001',        'PSA 9', 610,   'eBay',      now() - interval '5 days');

-- Index history: overall "Case Index" + per-category, 365 daily points --------
insert into market_index_points (category, as_of, value)
select null,
       (current_date - d)::date,
       round((820 + (365 - d) * (1284.5 - 820) / 365.0 + 15 * sin(d / 9.0))::numeric, 2)
from generate_series(0, 364) as d
on conflict (category, as_of) do nothing;

insert into market_index_points (category, as_of, value)
select c.cat,
       (current_date - d)::date,
       round((c.base + (365 - d) * (c.target - c.base) / 365.0 + c.amp * sin(d / 8.0))::numeric, 2)
from (values
  ('basketball', 700, 980,  18),
  ('football',   600, 920,  14),
  ('baseball',   800, 760,  10),
  ('soccer',     500, 770,  12),
  ('hockey',     900, 1010, 8),
  ('pokemon',    700, 870,  11)
) as c(cat, base, target, amp),
generate_series(0, 364) as d
on conflict (category, as_of) do nothing;
