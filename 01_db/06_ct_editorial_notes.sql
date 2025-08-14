-- 3) Editorial notes (the “memory”)
CREATE TYPE IF NOT EXISTS note_type AS ENUM ('reading_order', 'bubble', 'panel_flow', 'composition', 'other');
CREATE TYPE IF NOT EXISTS note_status AS ENUM ('open', 'resolved', 'dismissed');

CREATE TABLE IF NOT EXISTS editorial_notes (
  id              BIGSERIAL PRIMARY KEY,
  page_id         BIGINT NOT NULL REFERENCES pages(id) ON DELETE CASCADE,
  analysis_run_id BIGINT REFERENCES analysis_runs(id) ON DELETE SET NULL,
  kind            note_type NOT NULL,
  status          note_status NOT NULL DEFAULT 'open',
  severity        SMALLINT,                     -- 1–5 if you want
  body            TEXT NOT NULL,                -- the concrete suggestion
  anchors         JSONB DEFAULT '{}'::jsonb,    -- { panel: 3, bbox:{x,y,w,h}, xpath:"//..." }
  tags            TEXT[] DEFAULT '{}',          -- {"layout","pacing"}
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notes_pageid ON editorial_notes(page_id);
CREATE INDEX IF NOT EXISTS idx_notes_status ON editorial_notes(status);
CREATE INDEX IF NOT EXISTS idx_notes_tags_gin ON editorial_notes USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_notes_anchors_gin ON editorial_notes USING GIN(anchors jsonb_path_ops);