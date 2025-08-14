-- ===================================================================
-- Epic Wizard - Memory Feature Schema (PostgreSQL)
-- ===================================================================
-- Safe to run on a fresh DB. Wrap in a transaction.
BEGIN;

-- ----------------------------
-- Enum types
-- ----------------------------
CREATE TYPE project_kind      AS ENUM ('comic','story','portfolio','other');
CREATE TYPE project_status    AS ENUM ('draft','active','archived');

CREATE TYPE artifact_kind     AS ENUM ('page','script','image','thumb','note','bundle','other');

CREATE TYPE run_status        AS ENUM ('queued','running','succeeded','failed','canceled');
CREATE TYPE run_check_status  AS ENUM ('queued','running','ok','warn','fail','skipped','error');

CREATE TYPE note_kind         AS ENUM ('advice','info','warning','error','nit','suggestion');
CREATE TYPE note_status       AS ENUM ('open','addressed','dismissed');
CREATE TYPE severity          AS ENUM ('low','medium','high','critical');

CREATE TYPE account_type      AS ENUM ('free','pro','internal','admin');

-- ----------------------------
-- Users & Accounts
-- ----------------------------
CREATE TABLE users (
  id           BIGSERIAL PRIMARY KEY,
  username     VARCHAR(255) NOT NULL UNIQUE,
  email        VARCHAR(255) NOT NULL UNIQUE,
  avatar_url   VARCHAR(555)
);

CREATE TABLE accounts (
  id                    BIGSERIAL PRIMARY KEY,
  user_id               BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  password_hash         VARCHAR(255) NOT NULL,
  account_type          account_type NOT NULL DEFAULT 'free',
  account_verification  BOOLEAN DEFAULT FALSE,
  active_status         BOOLEAN DEFAULT TRUE,
  active_date           DATE
);

-- ----------------------------
-- Phase templates & kinds
-- ----------------------------
CREATE TABLE phase_template (
  id    BIGSERIAL PRIMARY KEY,
  name  VARCHAR(255) NOT NULL
);

CREATE TABLE phase_kind (
  id           BIGSERIAL PRIMARY KEY,
  code         VARCHAR(50)  NOT NULL UNIQUE,
  display_name VARCHAR(50)  NOT NULL,
  order_hint   SMALLINT     NOT NULL DEFAULT 0
);

CREATE TABLE phase_template_step (
  id              BIGSERIAL PRIMARY KEY,
  template_id     BIGINT NOT NULL REFERENCES phase_template(id) ON DELETE CASCADE,
  phase_kind_id   BIGINT NOT NULL REFERENCES phase_kind(id),
  profile_code    VARCHAR(50) NOT NULL,
  order_hint      VARCHAR(50) NOT NULL,
  CONSTRAINT uq_phase_template_step UNIQUE (template_id, order_hint)
);

-- ----------------------------
-- Projects
-- ----------------------------
CREATE TABLE projects (
  id                BIGSERIAL PRIMARY KEY,
  name              VARCHAR(555) NOT NULL UNIQUE,
  description       TEXT,
  kind              project_kind   NOT NULL DEFAULT 'comic',
  status            project_status NOT NULL DEFAULT 'draft',
  created_at        DATE NOT NULL DEFAULT NOW(),
  phase_template_id BIGINT REFERENCES phase_template(id),
  user_id           BIGINT REFERENCES users(id)
);

CREATE INDEX idx_projects_user_status ON projects(user_id, status);

-- ----------------------------
-- Artifacts & Versions
-- ----------------------------
CREATE TABLE artifacts (
  id             BIGSERIAL PRIMARY KEY,
  project_id     BIGINT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  phase_kind_id  BIGINT REFERENCES phase_kind(id),
  kind           artifact_kind NOT NULL,
  ref_id         VARCHAR(100),
  parent_id      BIGINT REFERENCES artifacts(id) ON DELETE SET NULL,
  content_hash   VARCHAR(64),
  title          VARCHAR(555),
  idx_in_phase   SMALLINT,
  created_at     DATE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_artifacts_project_phase ON artifacts(project_id, phase_kind_id, idx_in_phase);
CREATE INDEX idx_artifacts_parent         ON artifacts(parent_id);
CREATE INDEX idx_artifacts_kind           ON artifacts(kind);

CREATE TABLE artifact_version (
  id             BIGSERIAL PRIMARY KEY,
  artifact_id    BIGINT NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
  version_number INT    NOT NULL,
  content_hash   VARCHAR(64)  NOT NULL,      -- sha256 hex (or BYTEA if you prefer)
  content_uri    VARCHAR(255) NOT NULL,      -- storage path (S3/file)
  created_at     DATE NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_artifact_version UNIQUE (artifact_id, version_number),
  CONSTRAINT uq_artifact_content_hash UNIQUE (content_hash)
);

CREATE INDEX idx_artifact_version_artifact ON artifact_version(artifact_id DESC, created_at DESC);

-- Optional helper tables if you want them separate (you can skip if you
-- model pages/scripts purely as artifacts of kind 'page'/'script'):
CREATE TABLE pages (
  id         BIGSERIAL PRIMARY KEY,
  name       VARCHAR(255) NOT NULL UNIQUE,
  source_uri VARCHAR(500),
  meta       JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE script (
  id          BIGSERIAL PRIMARY KEY,
  filename    VARCHAR(255) NOT NULL,
  language    VARCHAR(155),
  storage_uri VARCHAR(555),
  meta        JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- ----------------------------
-- Analysis runs & checks
-- ----------------------------
-- Note: tie runs to *artifact_version* only (artifact_id is derivable)
CREATE TABLE analysis_runs (
  id                  BIGSERIAL PRIMARY KEY,
  artifact_version_id BIGINT NOT NULL REFERENCES artifact_version(id) ON DELETE CASCADE,
  model_provider      VARCHAR(50)  NOT NULL,
  model_name          VARCHAR(90)  NOT NULL,
  profile_code        VARCHAR(50)  NOT NULL,
  input_hash          VARCHAR(64),
  status              run_status   NOT NULL DEFAULT 'queued',
  started_at          DATE,
  finished_at         DATE,
  prompt_tokens       BIGINT,
  completion_tokens   BIGINT,
  dollar_cost         DOUBLE PRECISION,
  meta                JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX idx_runs_version        ON analysis_runs(artifact_version_id);
CREATE INDEX idx_runs_status         ON analysis_runs(status);
CREATE INDEX idx_runs_model_profile  ON analysis_runs(profile_code, model_provider, model_name);
CREATE INDEX idx_runs_started_at     ON analysis_runs(started_at DESC);

CREATE TABLE check_kind (
  id           BIGSERIAL PRIMARY KEY,
  profile_code VARCHAR(50)  NOT NULL,
  code         VARCHAR(50)  NOT NULL UNIQUE, -- e.g., 'contrast_low'
  display_name VARCHAR(100) NOT NULL,
  weight       NUMERIC(6,2) NOT NULL DEFAULT 1.0
);

CREATE TABLE run_check (
  id              BIGSERIAL PRIMARY KEY,
  analysis_run_id BIGINT NOT NULL REFERENCES analysis_runs(id) ON DELETE CASCADE,
  check_kind_id   BIGINT NOT NULL REFERENCES check_kind(id),
  status          run_check_status NOT NULL,
  score_delta     NUMERIC(6,2),
  details         JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX idx_run_check_run   ON run_check(analysis_run_id);
CREATE INDEX idx_run_check_kind  ON run_check(check_kind_id);
CREATE INDEX idx_run_check_stat  ON run_check(status);

-- ----------------------------
-- Notes
-- ----------------------------
CREATE TABLE notes (
  id              BIGSERIAL PRIMARY KEY,
  analysis_run_id BIGINT NOT NULL REFERENCES analysis_runs(id) ON DELETE CASCADE,
  kind            note_kind   NOT NULL,
  status          note_status NOT NULL DEFAULT 'open',
  severity        severity    NOT NULL DEFAULT 'medium',
  body            TEXT        NOT NULL,
  tags            TEXT[]      NOT NULL DEFAULT '{}',
  anchors         JSONB       NOT NULL DEFAULT '[]'::jsonb,  -- e.g., [{artifact_id, page, bbox, selector}]
  extra           JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at      DATE        NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notes_run_status_sev ON notes(analysis_run_id, status, severity);
CREATE INDEX idx_notes_tags_gin       ON notes USING GIN (tags);
CREATE INDEX idx_notes_anchors_gin    ON notes USING GIN (anchors);
CREATE INDEX idx_notes_extra_gin      ON notes USING GIN (extra);

COMMIT;
