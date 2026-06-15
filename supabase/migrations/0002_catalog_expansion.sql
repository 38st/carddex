-- Catalog expansion: sets (for completion tracking), richer cards, fuzzy search.

create table if not exists sets (
    id            text primary key,           -- catalog-native set id, e.g. 'base1', 'mh2'
    game          card_game not null,
    name          text not null,
    code          text,                        -- e.g. 'MH2', 'LOB', 'SV1'
    series        text,
    release_date  date,
    total_cards   int,                         -- printed set size (for completion %)
    printed_total int,                         -- incl. secret rares
    symbol_url    text,
    logo_url      text,
    updated_at    timestamptz not null default now()
);
create index if not exists sets_game_idx on sets(game);

alter table cards add column if not exists set_id text references sets(id);
alter table cards add column if not exists variant text;             -- 'holo','reverse','1st-edition',...
alter table cards add column if not exists number_normalized text;   -- digits only
alter table cards add column if not exists name_normalized text;     -- lower/unaccented
alter table cards add column if not exists supertype text;
alter table cards add column if not exists external_ids jsonb default '{}'::jsonb;
alter table cards add column if not exists last_priced_at timestamptz;
alter table cards add column if not exists search_tsv tsvector;

create index if not exists cards_game_set_idx   on cards(game, set_id);
create index if not exists cards_name_norm_idx  on cards(game, name_normalized);
create index if not exists cards_number_norm_idx on cards(game, number_normalized);
create index if not exists cards_search_tsv_idx on cards using gin(search_tsv);
create extension if not exists pg_trgm;
create index if not exists cards_name_trgm_idx  on cards using gin(name_normalized gin_trgm_ops);

create or replace function cards_tsv_update() returns trigger language plpgsql as $$
begin
    new.search_tsv :=
          setweight(to_tsvector('simple', coalesce(new.name, '')), 'A')
       || setweight(to_tsvector('simple', coalesce(new.set_name, '')), 'B')
       || setweight(to_tsvector('simple', coalesce(new.number, '')), 'C');
    return new;
end $$;
drop trigger if exists cards_tsv_trg on cards;
create trigger cards_tsv_trg before insert or update on cards
    for each row execute function cards_tsv_update();

alter table sets enable row level security;
create policy "sets are public read" on sets for select using (true);
