-- Vision-result cache: avoids re-billing the model for the same card photo.

create table if not exists scan_cache (
    content_hash text primary key,     -- sha256 of image + OCR + game hint
    result       jsonb not null,
    created_at   timestamptz not null default now()
);
create index if not exists scan_cache_created_idx on scan_cache(created_at);

-- Service-role only (Edge Functions) — RLS on, no policies.
alter table scan_cache enable row level security;
