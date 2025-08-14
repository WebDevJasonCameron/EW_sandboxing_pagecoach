-- 1) Pages you analyze
CREATE TABLE pages (
  id           BIGSERIAL PRIMARY KEY,
  url          TEXT NOT NULL UNIQUE,
  url_hash     TEXT NOT NULL,                  -- SHA-256 of normalized URL
  title        TEXT,
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_pages_url_hash ON pages(url_hash);