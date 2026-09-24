# Battery Aging Database Schema Documentation

## Overview

This database stores structured information about Li-ion battery aging datasets, their cell models, individual cells, measurement sections, test steps, and raw timeseries data. It is designed to support two complementary use cases: (1) dataset discovery and selection by experimental conditions, and (2) structured retrieval of measurement data for analysis.

The schema is the relational layer of a two-layer architecture. The companion JSON catalog (one entry per dataset, following the `dataset_schema_reference`) provides the full dataset-level taxonomy. The DB stores the per-cell and per-section data that enables cross-dataset queries and direct analysis without requiring manual file inspection.

The measurement data is organized in two parallel branches from `cell`, one for each data type:

```
cell
  ├── checkup  →  checkup_step  →  checkup_rawdata    (RPT and characterization sections)
  └── cycle    →  cycle_step    →  cycle_rawdata       (aging cycle timeseries)
```

---

## Tables

### dataset

Publication identity and high-value discovery fields for each dataset. Fields promoted from the catalog `dataset_metadata` and `aging_matrix` top-level.

| Column | Type | Notes |
|---|---|---|
| `dataset_id` | int PK | Auto-generated |
| `name` | text NOT NULL | Full official dataset name |
| `short_name` | text | Abbreviated identifier (e.g. `"Frie_RWTH_CalendarAging_2024"`) |
| `year` | smallint | Publication or release year |
| `institution` | text | Organization(s) that created the dataset |
| `country` | char(2) | ISO 3166-1 alpha-2 country code |
| `license` | text | Data usage license |
| `paper_url` | text | URL to associated publication |
| `data_url` | text | URL to download the dataset |
| `study_design` | text | Experimental design type (controlled vocabulary: `full_factorial`, `partial_factorial`, `ofat`, `d_optimal`, `latin_hypercube`, `bayesian_adaptive`, `custom`) |
| `num_cells_total` | smallint | Total number of cells in the dataset |
| `num_unique_conditions` | smallint | Number of unique aging parameter combinations |
| `has_rawdata` | boolean | Dataset includes raw cycling timeseries |
| `has_checkup` | boolean | Dataset includes periodic RPT / checkup data |
| `data_size_gb` | real | Total dataset size [GB] |
| `catalog_meta` | jsonb | Display-only and array catalog fields (see note below) |

**`catalog_meta` JSONB content:** `authors`, `contact_email`, `citation`, `funding`, `aging_modes.types` (array of aging types present in the dataset), `eol_criteria`, `eol_threshold_pct`, `test_equipment`, `sampling_rate_hz`, `total_cycles_approx`, `test_duration_months_approx`, `checkup.types`, `checkup.recorded_variables`, `checkup.interval`, `rawdata.recorded_variables`, `rawdata.file_formats`, `rawdata.data_structure`, `data_quality_notes`, `known_issues`, `notes`.

---

### cell_model

Commercial battery cell specifications. One row per distinct cell model. Multiple cells in the same dataset may reference the same `cell_model` if they are physically identical.

| Column | Type | Notes |
|---|---|---|
| `cell_model_id` | int PK | Auto-generated |
| `brand` | text NOT NULL | Manufacturer name (maps to `cell_info.manufacturer`) |
| `commercial_name` | text NOT NULL | Product/model name (e.g. `"INR18650-MJ1"`) |
| `capacity` | real NOT NULL | Nominal capacity [Ah] |
| `chemistry` | cathode_type NOT NULL | Positive electrode chemistry |
| `anode` | anode_type | Negative electrode chemistry |
| `format` | format_type NOT NULL | Physical cell format (coarse); use `size` for size designation |
| `size` | text NOT NULL | Format size (e.g. `"18650"`, `"21700"`, `"4680"`, `"custom"`) |
| `nominal_voltage_v` | real | Nominal voltage [V] |
| `nominal_energy_wh` | real | Rated energy [Wh] |
| `specific_energy_wh_kg` | real | Gravimetric energy density [Wh/kg] |
| `energy_density_wh_l` | real | Volumetric energy density [Wh/L] |
| `mass_g` | real | Cell mass [g] |
| `diameter_mm` | real | Diameter [mm] — cylindrical cells |
| `length_mm` | real | Length [mm] — cylindrical cells |
| `width_mm` | real | Width [mm] — pouch/prismatic cells |
| `height_mm` | real | Height [mm] — pouch/prismatic cells |
| `electrolyte` | text | Electrolyte type/composition |
| `separator` | text | Separator material |
| `datasheet_url` | text | URL to manufacturer datasheet |

**Format mapping to catalog:** The catalog `form_factor` field encodes format and size together (e.g. `"cylindrical_18650"`). In the DB these are separated: `format = 'cylindrical'` and `size = '18650'`.

---

### cell

An individual physical cell tested in a dataset. Carries the cell's specific experimental assignment as a JSONB object.

| Column | Type | Notes |
|---|---|---|
| `cell_id` | int PK | Auto-generated |
| `cell_model_id` | int NOT NULL | FK → cell_model |
| `dataset_id` | int NOT NULL | FK → dataset |
| `serial_number` | text NOT NULL | Cell identifier from the source dataset |
| `experimental_conditions` | jsonb NOT NULL | Per-cell stressor assignment (see below) |

**`experimental_conditions` JSONB schema** (`experimental_conditions.schema.json`):

| Field | Type | Description |
|---|---|---|
| `aging_type` | string[] | Aging mode(s) for this cell. Values: `storage`, `calendar`, `cycling`, `dynamic` |
| `temperature` | number[] | Aging temperature(s) [°C] |
| `dod` | number[] | Depth of discharge [%] |
| `soc_mean` | number[] | Mean state of charge [%] |
| `c_rate_chg` | number[] | Charge C-rate |
| `c_rate_dch` | number[] | Discharge C-rate |
| `cycling_range` | string | Voltage or SOC cycling window (e.g. `"2.5-4.2"` or `"0-100"`) |
| `storage_level` | number | Storage SOC or voltage setpoint (calendar/storage cells) |
| `cv_cutoff_current_c` | number | CV phase cutoff current as fraction of 1C (e.g. `0.05` for C/20) |
| `charge_protocol` | string | Charge method (e.g. `"cc_cv"`, `"mcc"`, `"pulse"`) |
| `discharge_protocol` | string | Discharge method (e.g. `"cc"`, `"drive_cycle"`) |
| `drive_cycle_profile` | string | Drive cycle name when `discharge_protocol = "drive_cycle"` |
| `ambient_control` | string | Temperature control method (e.g. `"climate_chamber"`, `"room_temperature"`) |
| `total_efc` | int | Total equivalent full cycles in the experiment |
| `total_ah` | int | Total Ah throughput [Ah] |
| `total_exp_days` | int | Total elapsed days of experiment |
| `total_cyc_days` | int | Total cycling days |

---

### checkup

A measurement section for a cell. Each row represents one contiguous block of the experiment: a cycling aging block, a calendar storage period, or an RPT characterization sequence. The `section_type` field tags the kind of section; the `aging_context` JSONB carries section-level summary metrics and conditions, whose relevant fields depend on `section_type`.

| Column | Type | Notes |
|---|---|---|
| `cu_id` | int PK (composite) | Section index for this cell |
| `cell_id` | int PK (composite) | FK → cell |
| `date` | timestamp NOT NULL | Start date/time of the section (ISO 8601) |
| `section_type` | aging_type NOT NULL | Type of this measurement section |
| `origin_id` | text NOT NULL | External identifier for traceability from the source dataset |
| `aging_context` | jsonb NOT NULL | Section-level summary (see below) |

**`aging_context` JSONB schema** (`aging_context.schema.json`):

*All section types:*

| Field | Required | Description |
|---|---|---|
| `start_date` | yes | Section start (ISO 8601 datetime) |
| `end_date` | yes | Section end (ISO 8601 datetime) |
| `temperature_c` | yes | Temperature during this section [°C] |
| `soh` | recommended | State of health at end of section [%], derived from the following RPT |

*Cycling and dynamic sections additionally:*

| Field | Description |
|---|---|
| `ah_throughput` | Ah throughput in this section [Ah] |
| `ah_throughput_cumulative` | Cumulative Ah throughput since BOL [Ah] |
| `efc` | Equivalent full cycles in this section |
| `efc_cumulative` | Cumulative EFC since BOL |
| `mean_soc` | Mean SOC during section [%] |
| `mean_c_rate_chg` | Mean charge C-rate |
| `mean_c_rate_dch` | Mean discharge C-rate |
| `mean_dod` | Mean depth of discharge [%] |
| `cycling_time` | Total active cycling time [h] |
| `rest_time` | Total rest time [h] |

*RPT / checkup sections additionally:*

| Field | Description |
|---|---|
| `charge_crates` | C-rates used for capacity measurements |
| `soc_levels_pct` | SOC levels at which pulse or impedance tests were performed [%] |

*Calendar and storage sections additionally:*

| Field | Description |
|---|---|
| `ah_throughput_cumulative` | Cumulative Ah throughput since BOL [Ah] |
| `efc_cumulative` | Cumulative EFC since BOL |

### checkup_step

A single test step within a checkup section. Steps are the unit of raw data acquisition for RPT and characterization data.

| Column | Type | Notes |
|---|---|---|
| `cu_step_id` | int PK | Auto-generated |
| `cu_id` | int NOT NULL | FK → checkup (composite with cell_id) |
| `cell_id` | int NOT NULL | FK → cell |
| `origin_step_id` | int NOT NULL | Step index from the source dataset for traceability |
| `step_type` | step_type NOT NULL | Type of this step (shared enum with `cycle_step`) |
| `hi_features` | jsonb NOT NULL | Derived scalar features for this step (open schema, extended during analysis) |

---

### checkup_rawdata

Raw timeseries measurements recorded during a checkup step. Each row is one sample point.

| Column | Type | Notes |
|---|---|---|
| `time` | int PK (composite) | Relative time within the step [ms] |
| `cu_step_id` | int PK (composite) | FK → checkup_step |
| `voltage` | real NOT NULL | Cell voltage [V] |
| `current` | real NOT NULL | Current, charge positive / discharge negative [A] |
| `temperature` | real | Cell surface or internal temperature [°C] |
| `capacity_step` | real NOT NULL | Cumulative Ah within the step, starting at 0 [Ah] |
| `soc` | real NOT NULL | State of charge [%] |

---

### cycle

An individual aging cycle for a cell. Each row represents one complete charge-discharge cycle. Derived scalar features computed at cycle granularity are stored in `hi_features`; the full timeseries is in `cycle_step → cycle_rawdata`.

| Column | Type | Notes |
|---|---|---|
| `cycle_id` | int PK (composite) | Per-cell sequential cycle identifier |
| `cell_id` | int PK (composite) | FK → cell |
| `date` | timestamp NOT NULL | Start timestamp of the cycle |
| `origin_id` | text NOT NULL | External cycle identifier from the source dataset for traceability |
| `aging_context` | jsonb NOT NULL | Per-cycle experimental conditions (see below) |

**`aging_context` JSONB content:** Carries the conditions under which this specific cycle ran. Most relevant for variable-protocol datasets where temperature, C-rate, SOC window, or drive cycle profile change between cycles. Fields include `temperature_c`, `c_rate_chg`, `c_rate_dch`, `soc_min`, `soc_max`, `dod`, `drive_cycle_profile`, and any other per-cycle stressor values. For constant-protocol datasets, these fields mirror `cell.experimental_conditions` and may be omitted or left minimal.

---

### cycle_step

A major phase within an aging cycle (e.g., CC charge, CV charge, discharge, rest). The `step_type` enum is shared with `checkup_step`.

| Column | Type | Notes |
|---|---|---|
| `cycle_step_id` | int PK | Auto-generated |
| `cycle_id` | int NOT NULL | FK → cycle (composite with cell_id) |
| `cell_id` | int NOT NULL | FK → cycle (composite with cell_id) and FK → cell |
| `step_number` | smallint NOT NULL | Sequential index within the cycle (1, 2, 3...) |
| `step_type` | step_type NOT NULL | Phase type: `chg_cc`, `dch_cc`, `relax_post_dch`, `dch_drive_cycle`, etc. Same enum as `checkup_step`. |
| `hi_features` | jsonb NOT NULL | Step-level derived features: `capacity` [Ah], `energy` [Wh], `duration` [s], `delta_v` [V], `coulombic_efficiency` [%] on discharge steps, and any analysis-specific indicators. Open schema, extended during ingestion. |

---

### cycle_rawdata

Raw timeseries samples within a cycle step. Identical structure to `checkup_rawdata`; references `cycle_step` instead of `checkup_step`.

| Column | Type | Notes |
|---|---|---|
| `time` | int PK (composite) | Relative time within the step [ms] |
| `cycle_step_id` | int PK (composite) | FK → cycle_step |
| `voltage` | real NOT NULL | Cell voltage [V] |
| `current` | real NOT NULL | Current, charge positive / discharge negative [A] |
| `temperature` | real | Cell surface or internal temperature [°C] |
| `capacity_step` | real NOT NULL | Cumulative Ah within the step, starting at 0 [Ah] |
| `soc` | real NOT NULL | State of charge [%] |

---

## Enums

### aging_type
Used for `checkup.section_type`. Tags the type of a measurement section.

| Value | Description |
|---|---|
| `storage` | Cell stored without cycling; temperature probably not controlled |
| `calendar` | Controlled-temperature storage aging |
| `cycling` | Periodic charge-discharge aging |
| `dynamic` | Application profile or dynamic current profile aging |

### cathode_type

| Value | Description |
|---|---|
| `NMC` | Nickel Manganese Cobalt (all ratios: NMC111, NMC532, NMC622, NMC811) |
| `NCA` | Nickel Cobalt Aluminum |
| `LFP` | Lithium Iron Phosphate |
| `LCO` | Lithium Cobalt Oxide |
| `LMO` | Lithium Manganese Oxide |
| `NMC_LCO` | NMC/LCO blend |
| `unknown` | Chemistry not documented |
| `custom` | Chemistry present but not in this list |

### anode_type

| Value | Description |
|---|---|
| `graphite` | Standard graphite anode |
| `graphite_silicon` | Graphite with silicon additive (Si wt% may be noted in catalog_meta) |
| `graphite_silicon_oxide` | Graphite with SiOx additive |
| `lto` | Lithium titanate (Li₄Ti₅O₁₂) |
| `unknown` | Anode chemistry not documented |
| `custom` | Anode material present but not in this list |

### format_type

| Value |
|---|
| `cylindrical` |
| `pouch` |
| `prismatic` |
| `coin` |
| `blade` |

### step_type

| Value | Description |
|---|---|
| `pause` | Rest period at the start of a step sequence |
| `dch_cc` | Discharge at constant current |
| `chg_cc` | Charge at constant current |
| `chg_cv` | Charge at constant voltage (CV phase) |
| `dch_cv` | Discharge at constant voltage |
| `dch_cp` | Discharge at constant power |
| `chg_cp` | Charge at constant power |
| `relax_post_chg` | Relaxation period after charge |
| `relax_post_dch` | Relaxation period after discharge |
| `dch_drive_cycle` | Discharge with application drive-cycle current profile |

---

## Database implementation

### Deletion logic (referential integrity)

RPT branch:
- Deleting a `cell` cascades to all its `checkup`, `checkup_step`, and `checkup_rawdata` rows.
- Deleting a `cell_model` or `dataset` is blocked (RESTRICT) if any `cell` references it.
- Deleting a `checkup` cascades to its `checkup_step` and `checkup_rawdata` rows.
- Deleting a `checkup_step` cascades to its `checkup_rawdata` rows.

Cycling branch:
- Deleting a `cell` cascades to all its `cycle`, `cycle_step`, and `cycle_rawdata` rows.
- Deleting a `cycle` cascades to its `cycle_step` and `cycle_rawdata` rows.
- Deleting a `cycle_step` cascades to its `cycle_rawdata` rows.

### Indexing strategy

- **GIN indexes** on all JSONB columns: `catalog_meta`, `experimental_conditions`, `checkup.aging_context`, `checkup_step.hi_features`, `cycle.aging_context`, `cycle_step.hi_features`.
- **Btree indexes** on `dataset.year`, `dataset.country`, `dataset.institution` for common discovery filters.
- **Btree indexes** on `checkup.cell_id`, `checkup_step.(cu_id, cell_id)`, `checkup_rawdata.(cu_step_id, time)` for RPT branch joins and ordering.
- **Btree indexes** on `cycle.cell_id`, `cycle_step.(cycle_id, cell_id)`, `cycle_rawdata.(cycle_step_id, time)` for cycling branch joins and ordering.

### Relationship to the JSON catalog

The JSON catalog (one `.json` entry per dataset) is the authoritative dataset-level metadata record. The DB `dataset` table stores the subset of catalog fields needed for SQL-level discovery queries. The full catalog entry is accessible via `dataset.catalog_meta` or by reading the companion JSON file. The shared controlled vocabularies (chemistry, format, aging type, study design) are the bridge between the two layers: a value valid in the catalog is valid in the DB.

---

## Notes

- JSONB fields follow documented JSON schemas in `json_schemas/`. The `hi_features` schema is intentionally open (`additionalProperties: true`) to accommodate analysis-specific derived features.
- The `checkup` table is unified across all section types (cycling, calendar, storage, dynamic, RPT). The `section_type` field and the conditional structure of `aging_context` distinguish them. There is no separate table for RPT data versus aging data.
- The `experimental_conditions` JSONB on `cell` is the per-cell projection of the dataset-level `aging_matrix` in the catalog: same fields, same controlled vocabulary, cell-level granularity.
