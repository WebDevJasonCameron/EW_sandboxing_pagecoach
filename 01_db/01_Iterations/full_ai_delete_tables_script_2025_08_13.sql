-- ===================================================================
-- Epic Wizard - Teardown Script (PostgreSQL)
-- Drops indexes, tables, and enum types so you can re-create cleanly.
-- ===================================================================
BEGIN;

-- -----------------------------------
-- 1) Drop indexes explicitly (optional safety)
--    (Tables would auto-drop their indexes, but this avoids name clashes
--     in case of partial prior runs or renames.)
-- -----------------------------------
DROP INDEX IF EXISTS idx_projects_user_status;

DROP INDEX IF EXISTS idx_artifacts_project_phase;
DROP INDEX IF EXISTS idx_artifacts_parent;
DROP INDEX IF EXISTS idx_artifacts_kind;

DROP INDEX IF EXISTS idx_artifact_version_artifact;

DROP INDEX IF EXISTS idx_runs_version;
DROP INDEX IF EXISTS idx_runs_status;
DROP INDEX IF EXISTS idx_runs_model_profile;
DROP INDEX IF EXISTS idx_runs_started_at;

DROP INDEX IF EXISTS idx_run_check_run;
DROP INDEX IF EXISTS idx_run_check_kind;
DROP INDEX IF EXISTS idx_run_check_stat;

DROP INDEX IF EXISTS idx_notes_run_status_sev;
DROP INDEX IF EXISTS idx_notes_tags_gin;
DROP INDEX IF EXISTS idx_notes_anchors_gin;
DROP INDEX IF EXISTS idx_notes_extra_gin;

-- -----------------------------------
-- 2) Drop tables (reverse dependency order)
-- -----------------------------------
DROP TABLE IF EXISTS notes                 CASCADE;
DROP TABLE IF EXISTS run_check             CASCADE;
DROP TABLE IF EXISTS check_kind            CASCADE;

DROP TABLE IF EXISTS analysis_runs         CASCADE;

DROP TABLE IF EXISTS artifact_version      CASCADE;
DROP TABLE IF EXISTS artifacts             CASCADE;

-- Optional helper tables (only if you created them)
DROP TABLE IF EXISTS pages                 CASCADE;
DROP TABLE IF EXISTS script                CASCADE;

DROP TABLE IF EXISTS projects              CASCADE;

DROP TABLE IF EXISTS phase_template_step   CASCADE;
DROP TABLE IF EXISTS phase_kind            CASCADE;
DROP TABLE IF EXISTS phase_template        CASCADE;

DROP TABLE IF EXISTS accounts              CASCADE;
DROP TABLE IF EXISTS users                 CASCADE;

-- -----------------------------------
-- 3) Drop enum types (after tables are gone)
-- -----------------------------------
DROP TYPE IF EXISTS account_type;
DROP TYPE IF EXISTS severity;
DROP TYPE IF EXISTS note_status;
DROP TYPE IF EXISTS note_kind;
DROP TYPE IF EXISTS run_check_status;
DROP TYPE IF EXISTS run_status;
DROP TYPE IF EXISTS artifact_kind;
DROP TYPE IF EXISTS project_status;
DROP TYPE IF EXISTS project_kind;

COMMIT;
