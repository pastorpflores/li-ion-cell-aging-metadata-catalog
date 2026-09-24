-- ENUM TYPES

CREATE TYPE "aging_type" AS ENUM (
  'storage',
  'calendar',
  'cycling',
  'dynamic'
);

CREATE TYPE "cathode_type" AS ENUM (
  'NMC',
  'NCA',
  'LFP',
  'LCO',
  'LMO',
  'NMC_LCO',
  'unknown',
  'custom'
);

CREATE TYPE "anode_type" AS ENUM (
  'graphite',
  'graphite_silicon',
  'graphite_silicon_oxide',
  'lto',
  'unknown',
  'custom'
);

CREATE TYPE "format_type" AS ENUM (
  'cylindrical',
  'pouch',
  'prismatic',
  'coin',
  'blade'
);

CREATE TYPE "step_type" AS ENUM (
  'pause',
  'dch_cc',
  'chg_cc',
  'chg_cv',
  'dch_cv',
  'dch_cp',
  'chg_cp',
  'relax_post_chg',
  'relax_post_dch',
  'dch_drive_cycle'
);

-- TABLES

CREATE TABLE "dataset" (
  "dataset_id"             integer  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "name"                   text     NOT NULL,
  -- Discovery / filter columns (promoted from catalog metadata)
  "short_name"             text,
  "year"                   smallint,
  "institution"            text,
  "country"                char(2),         -- ISO 3166-1 alpha-2
  "license"                text,
  "paper_url"              text,
  "data_url"               text,
  "study_design"           text,            -- full_factorial, partial_factorial, ofat, d_optimal, latin_hypercube, bayesian_adaptive, custom
  "num_cells_total"        smallint,
  "num_unique_conditions"  smallint,
  "has_rawdata"            boolean  NOT NULL DEFAULT false,
  "has_checkup"            boolean  NOT NULL DEFAULT false,
  "data_size_gb"           real,
  -- Display-only and array-type catalog fields
  "catalog_meta"           jsonb
  -- catalog_meta carries: authors, contact_email, citation, funding,
  --   aging_modes.types (array), eol_criteria, eol_threshold_pct,
  --   test_equipment, sampling_rate_hz, total_cycles_approx,
  --   test_duration_months_approx, checkup.types, checkup.recorded_variables,
  --   checkup.interval, rawdata.recorded_variables, rawdata.file_formats,
  --   rawdata.data_structure, data_quality_notes, known_issues, notes
);

CREATE TABLE "cell_model" (
  "cell_model_id"          integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "brand"                  text         NOT NULL,    -- maps to cell_info.manufacturer
  "commercial_name"        text         NOT NULL,
  "capacity"               real         NOT NULL,    -- nominal_capacity_ah [Ah]
  "chemistry"              cathode_type NOT NULL,    -- maps to cell_info.cathode_chemistry
  "anode"                  anode_type,              -- maps to cell_info.anode_chemistry
  "format"                 format_type  NOT NULL,    -- coarse format; use size for designation
  "size"                   text         NOT NULL,    -- e.g. '18650', '21700', '26650', '4680', 'custom'
  -- Additional physical specs from cell_info
  "nominal_voltage_v"      real,
  "nominal_energy_wh"      real,
  "specific_energy_wh_kg"  real,
  "energy_density_wh_l"    real,
  "mass_g"                 real,
  -- Dimensions (flat columns; use only the relevant subset per format)
  "diameter_mm"            real,        -- cylindrical
  "length_mm"              real,        -- cylindrical
  "width_mm"               real,        -- pouch / prismatic
  "height_mm"              real,        -- pouch / prismatic
  -- Material and reference
  "electrolyte"            text,
  "separator"              text,
  "datasheet_url"          text
);

CREATE TABLE "cell" (
  "cell_id"                 integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "cell_model_id"           int     NOT NULL,
  "dataset_id"              int     NOT NULL,
  "serial_number"           text    NOT NULL,
  "experimental_conditions" jsonb   NOT NULL,
  -- experimental_conditions carries per-cell stressor assignment:
  --   aging_type (array), temperature (array), dod (array), soc_mean (array),
  --   c_rate_chg (array), c_rate_dch (array),
  --   cycling_range (string, e.g. "2.5-4.2"),
  --   storage_level (number), cv_cutoff_current_c (number),
  --   charge_protocol (string), discharge_protocol (string),
  --   drive_cycle_profile (string), ambient_control (string),
  --   total_efc (int), total_ah (int), total_exp_days (int), total_cyc_days (int)
  CONSTRAINT cell_cell_model_fk
    FOREIGN KEY ("cell_model_id")
    REFERENCES "cell_model" ("cell_model_id")
    ON DELETE RESTRICT,
  CONSTRAINT cell_dataset_fk
    FOREIGN KEY ("dataset_id")
    REFERENCES "dataset" ("dataset_id")
    ON DELETE RESTRICT
);

-- RPT / CHARACTERIZATION BRANCH: cell → checkup → checkup_step → checkup_rawdata

CREATE TABLE "checkup" (
  "cu_id"         int,
  "cell_id"       int          NOT NULL,
  "date"          timestamp    NOT NULL,
  "section_type"  aging_type   NOT NULL,
  "origin_id"     text         NOT NULL,
  "aging_context" jsonb        NOT NULL,
  -- aging_context carries section-level context; fields depend on section_type:
  --   all sections:    start_date, end_date, temperature_c
  --   cycling/dynamic: ah_throughput, ah_throughput_cumulative, efc,
  --                    efc_cumulative, mean_soc, mean_c_rate_chg, mean_c_rate_dch,
  --                    mean_dod, cycling_time, rest_time, soh
  --   rpt/checkup:     temperature_c, charge_crates, soc_levels_pct, soh
  --   calendar/storage: ah_throughput_cumulative, efc_cumulative, soh
  PRIMARY KEY ("cu_id", "cell_id"),
  CONSTRAINT checkup_cell_fk
    FOREIGN KEY ("cell_id")
    REFERENCES "cell" ("cell_id")
    ON DELETE CASCADE
);

CREATE TABLE "checkup_step" (
  "cu_step_id" integer   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "cu_id"           int       NOT NULL,
  "cell_id"         int       NOT NULL,
  "origin_step_id"  int       NOT NULL,
  "step_type"       step_type NOT NULL,
  "hi_features"     jsonb     NOT NULL,
  CONSTRAINT checkup_step_checkup_fk
    FOREIGN KEY ("cu_id","cell_id")
    REFERENCES "checkup" ("cu_id","cell_id")
    ON DELETE CASCADE,
  CONSTRAINT checkup_step_cell_fk
    FOREIGN KEY ("cell_id")
    REFERENCES "cell" ("cell_id")
    ON DELETE CASCADE
);

CREATE TABLE "checkup_rawdata" (
  "time"             int,
  "cu_step_id"  int   NOT NULL,
  "voltage"          real  NOT NULL,
  "current"          real  NOT NULL,
  "temperature"      real,
  "capacity_step"    real  NOT NULL,
  "soc"              real  NOT NULL,
  PRIMARY KEY ("time", "cu_step_id"),
  CONSTRAINT checkup_rawdata_step_fk
    FOREIGN KEY ("cu_step_id")
    REFERENCES "checkup_step" ("cu_step_id")
    ON DELETE CASCADE
);

-- CYCLING TIMESERIES BRANCH: cell → cycle → cycle_step → cycle_rawdata

CREATE TABLE "cycle" (
  "cycle_id"      int,
  "cell_id"       int        NOT NULL,
  "date"          timestamp  NOT NULL,
  "origin_id"     text       NOT NULL,  -- external cycle identifier for traceability
  "aging_context" jsonb      NOT NULL,
  -- aging_context carries conditions for this specific cycle; relevant when
  -- experimental conditions vary between cycles (variable-protocol datasets):
  --   temperature_c, c_rate_chg, c_rate_dch, soc_min, soc_max, dod,
  --   drive_cycle_profile, and any other per-cycle stressor values
  PRIMARY KEY ("cycle_id", "cell_id"),
  CONSTRAINT cycle_cell_fk
    FOREIGN KEY ("cell_id")
    REFERENCES "cell" ("cell_id")
    ON DELETE CASCADE
);

CREATE TABLE "cycle_step" (
  "cycle_step_id" integer    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "cycle_id"      int        NOT NULL,
  "cell_id"       int        NOT NULL,
  "step_number"   smallint   NOT NULL,  -- sequential index within cycle (1, 2, 3...)
  "step_type"     step_type  NOT NULL,  -- shared enum with checkup_step
  "hi_features"   jsonb      NOT NULL,
  -- hi_features carries step-level derived features:
  --   capacity [Ah], energy [Wh], duration [s], delta_v [V],
  --   coulombic_efficiency (on discharge steps), and analysis-specific indicators
  CONSTRAINT cycle_step_cycle_fk
    FOREIGN KEY ("cycle_id", "cell_id")
    REFERENCES "cycle" ("cycle_id", "cell_id")
    ON DELETE CASCADE,
  CONSTRAINT cycle_step_cell_fk
    FOREIGN KEY ("cell_id")
    REFERENCES "cell" ("cell_id")
    ON DELETE CASCADE
);

CREATE TABLE "cycle_rawdata" (
  "time"           int,
  "cycle_step_id"  int   NOT NULL,
  "voltage"        real  NOT NULL,
  "current"        real  NOT NULL,
  "temperature"    real,
  "capacity_step"  real  NOT NULL,
  "soc"            real  NOT NULL,
  PRIMARY KEY ("time", "cycle_step_id"),
  CONSTRAINT cycle_rawdata_cycle_step_fk
    FOREIGN KEY ("cycle_step_id")
    REFERENCES "cycle_step" ("cycle_step_id")
    ON DELETE CASCADE
);

-- JSONB GIN INDEXES (one per JSONB column)

CREATE INDEX idx_dataset_catalogmeta_gin
  ON dataset USING GIN (catalog_meta);

CREATE INDEX idx_cell_expconds_gin
  ON cell USING GIN (experimental_conditions);

CREATE INDEX idx_checkup_agingctx_gin
  ON checkup USING GIN (aging_context);

CREATE INDEX idx_checkup_step_hifeatures_gin
  ON checkup_step USING GIN (hi_features);

CREATE INDEX idx_cycle_agingctx_gin
  ON cycle USING GIN (aging_context);

CREATE INDEX idx_cycle_step_hifeatures_gin
  ON cycle_step USING GIN (hi_features);

-- Btree indexes for common filters and joins

CREATE INDEX IF NOT EXISTS idx_dataset_year         ON dataset (year);
CREATE INDEX IF NOT EXISTS idx_dataset_country      ON dataset (country);
CREATE INDEX IF NOT EXISTS idx_dataset_institution  ON dataset (institution);

CREATE INDEX IF NOT EXISTS idx_checkup_cell_id          ON checkup (cell_id);
CREATE INDEX IF NOT EXISTS idx_checkup_step_cu_cell     ON checkup_step (cu_id, cell_id);
CREATE INDEX IF NOT EXISTS idx_checkup_rawdata_step_time ON checkup_rawdata (cu_step_id, time);

CREATE INDEX IF NOT EXISTS idx_cycle_cell_id            ON cycle (cell_id);
CREATE INDEX IF NOT EXISTS idx_cycle_step_cycle_cell    ON cycle_step (cycle_id, cell_id);
CREATE INDEX IF NOT EXISTS idx_cycle_rawdata_step_time  ON cycle_rawdata (cycle_step_id, time);
