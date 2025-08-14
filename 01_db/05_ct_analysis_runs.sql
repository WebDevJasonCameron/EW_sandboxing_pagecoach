-- 2) Each analysis run (optional but very helpful for provenance)
CREATE TABLE analysis_runs (
  id            BIGSERIAL PRIMARY KEY,
  page_id       BIGINT NOT NULL REFERENCES pages(id) ON DELETE CASCADE,
  model         TEXT NOT NULL,                 -- e.g., "gpt-4.1-mini"
  prompt_hash   TEXT,                          -- hash your prompt template
  tokens_in     INTEGER,
  tokens_out    INTEGER,
  ran_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  meta          JSONB DEFAULT '{}'::jsonb      -- { cost_estimate, version, etc. }
);

CREATE INDEX idx_runs_pageid_ranat ON analysis_runs(page_id, ran_at DESC);