# Li-ion Aging Dataset Schema Reference (v2.0)

Schema for cataloging Li-ion battery aging datasets. The JSON template (`dataset_template.json`) is the master reference; this document describes every field.

---

## Top-level structure

```
dataset_template.json
├── dataset_metadata
├── cell_info
├── aging_matrix
│   ├── has_rawdata          ← top-level flag
│   ├── has_checkup          ← top-level flag
│   ├── aging_modes          ← sub-object
│   ├── electrical           ← sub-object
│   ├── thermal              ← sub-object
│   ├── time_protocol        ← sub-object
│   ├── rawdata              ← sub-object (populate when has_rawdata = true)
│   └── checkup              ← sub-object (populate when has_checkup = true)
└── notes
```

---

## Schema Metadata

| Field | Type | Default | Description |
|---|---|---|---|
| `_schema_version` | string | `"2.0"` | Version of this schema |
| `_last_updated` | string | `""` | Date this entry was last modified (ISO 8601) |

---

## `dataset_metadata`

Publication and access information.

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | string | `""` | Full official name of the dataset or recommended naming |
| `short_name` | string | `""` | Abbreviated identifier (e.g., `"Frie_RWTH_CalendarAging_2024"`) |
| `year` | integer | `null` | Publication or dataset release year |
| `paper_url` | string | `""` | URL to the associated scientific publication |
| `data_url` | string | `""` | URL to download or access the dataset |
| `license` | string | `""` | Data usage license (use controlled vocabulary) |
| `institution` | string | `""` | Organization(s) that created the dataset |
| `country` | string | `""` | Country code (ISO 3166-1 alpha-2) |
| `authors` | array | `[]` | List of author names |
| `contact_email` | string | `""` | Contact email for dataset inquiries |
| `citation` | string | `""` | Recommended citation string |
| `funding` | string | `""` | Funding sources, grant numbers, or sponsors |

---

## `cell_info`

Array of cell specification objects. **Always an array**, even for single-cell datasets (one element). Add one object per distinct cell type when the dataset includes multiple cell models.

| Field | Type | Default | Description |
|---|---|---|---|
| `commercial_name` | string | `""` | Product/model name (e.g., `"INR18650-MJ1"`) |
| `manufacturer` | string | `""` | Cell manufacturer (use controlled vocabulary) |
| `form_factor` | string | `""` | Physical format (use controlled vocabulary) |
| `cathode_chemistry` | string | `""` | Positive electrode material (use controlled vocabulary) |
| `anode_chemistry` | string | `""` | Negative electrode material (use controlled vocabulary) |
| `electrolyte` | string | `""` | Electrolyte type/composition (use controlled vocabulary) |
| `separator` | string | `""` | Separator material (use controlled vocabulary) |
| `nominal_capacity_ah` | number | `null` | Rated capacity [Ah] |
| `nominal_voltage_v` | number | `null` | Nominal voltage [V] |
| `nominal_energy_wh` | number | `null` | Rated energy [Wh] |
| `specific_energy_wh_kg` | number | `null` | Gravimetric energy density [Wh/kg] |
| `energy_density_wh_l` | number | `null` | Volumetric energy density [Wh/L] |
| `mass_g` | number | `null` | Cell mass [g] |
| `dimensions_mm` | object | — | Physical dimensions (see sub-object below) |
| `datasheet_url` | string | `""` | URL to manufacturer datasheet |
| `cell_notes` | string | `""` | Additional cell-specific notes |

### `dimensions_mm`

| Field | Type | Default | Description |
|---|---|---|---|
| `diameter` | number | `null` | Diameter [mm] — cylindrical cells |
| `length` | number | `null` | Length [mm] — cylindrical cells |
| `width` | number | `null` | Width [mm] — pouch/prismatic cells |
| `height` | number | `null` | Height [mm] — pouch/prismatic cells |

---

## `aging_matrix`

Describes the experimental design, all aging stressors, and available data.

### Top-level flags

These two boolean flags gate their respective sub-objects. Populate `rawdata` only when `has_rawdata` is true; populate `checkup` only when `has_checkup` is true.

| Field | Type | Default | Description |
|---|---|---|---|
| `has_rawdata` | boolean | `false` | Dataset includes raw cycling timeseries (voltage, current, temperature vs. time) |
| `has_checkup` | boolean | `false` | Dataset includes periodic reference performance tests (RPTs / check-ups) |

---

### `aging_matrix.aging_modes`

High-level description of what is studied and the experimental scope.

| Field | Type | Default | Description |
|---|---|---|---|
| `types` | array | `[]` | Types of aging studied. Multiple allowed (e.g., a dataset can include calendar, cycling, and drive-cycle cells simultaneously). Use controlled vocabulary. |
| `constant_halfcycle` | string | `""` | Which halfcycle is identical across all cells. Key for understanding what is the experimental variable. Use controlled vocabulary. |
| `study_design` | string | `""` | Experimental design structure. Use controlled vocabulary. |
| `num_cell_types` | integer | `null` | Number of distinct cell models in the dataset. Must equal the length of the `cell_info` array. |
| `num_cells_total` | integer | `null` | Total number of cells in the dataset |
| `replicate_cells_min` | integer | `null` | Minimum number of cells per condition. Equal to `replicate_cells_max` for uniform designs. |
| `num_unique_conditions` | integer | `null` | Total number of unique aging parameter combinations |
| `eol_criteria` | string | `""` | End-of-life definition. Use controlled vocabulary. |
| `eol_threshold_pct` | number | `null` | Numeric EOL threshold (e.g., `80` for 80% capacity retention) |
| `notes` | string | `""` | Free-text. Describe distribution of cells across modes, groups, or sub-studies. |

---

### `aging_matrix.electrical`

Electrochemical stress parameters applied during aging.

#### Cycling / storage range

Voltage window and SOC window are equivalent representations of the same constraint. Specify the basis once and list all ranges in that basis.

| Field | Type | Default | Description |
|---|---|---|---|
| `cycling_range_basis` | string | `""` | How cycling ranges are defined: `"voltage"` [V] or `"soc"` [%]. |
| `cycling_ranges` | array | `[]` | List of cycling windows as `"low-high"` strings in the units of `cycling_range_basis`. Examples: `["2.5-4.2"]` (V) or `["0-100", "20-80"]` (%). |
| `storage_level_basis` | string | `""` | How calendar storage setpoints are defined: `"voltage"` [V] or `"soc"` [%]. |
| `storage_levels` | array | `[]` | List of storage setpoints in the units of `storage_level_basis`. Examples: `[3.47, 3.87, 4.05]` (V) or `[25, 50, 80, 100]` (%). |
| `dod_pct` | array | `[]` | Depth of discharge values [%]. Include when DOD is reported directly as the primary stressor independently of absolute SOC position. |

#### Current and protocols

| Field | Type | Default | Description |
|---|---|---|---|
| `charge_crates` | array | `[]` | Charge C-rates applied during aging cycles |
| `discharge_crates` | array | `[]` | Discharge C-rates applied during aging cycles |
| `cv_cutoff_current_c` | array | `[]` | CV phase termination current(s) as fraction of 1C (e.g., `[0.05]` for C/20) |
| `charge_protocol` | array | `[]` | Charge method(s). Use controlled vocabulary. |
| `discharge_protocol` | array | `[]` | Discharge method(s). Use controlled vocabulary. |
| `drive_cycle_profiles` | array | `[]` | Named drive cycle profile(s) when `discharge_protocol` includes `"drive_cycle"`. Use controlled vocabulary. |

---

### `aging_matrix.thermal`

Thermal stress parameters. Mirrors the electrical range structure: separate fields for cycling cells, storage cells, and within-test temperature variation.

| Field | Type | Default | Description |
|---|---|---|---|
| `temperature_cycling_c` | array | `[]` | Temperatures at which actively cycling cells are tested [°C] |
| `temperature_storage_c` | array | `[]` | Temperatures at which calendar/storage cells are held [°C] |
| `temperature_range_c` | array | `[]` | For within-test thermal cycling (temperature alternates as stressor). Format: `"low-high"` strings [°C], e.g., `["25-55"]`. |
| `ambient_control` | string | `""` | Method used to maintain temperature. Use controlled vocabulary. |
| `thermal_management` | string | `""` | Cell-level thermal management during aging. Use controlled vocabulary. |

---

### `aging_matrix.time_protocol`

Duration, cycling extent, rest conditions, and data acquisition settings.

| Field | Type | Default | Description |
|---|---|---|---|
| `test_duration_months_approx` | string | `null` | Duration of calendar/storage aging [months] |
| `total_cycles_approx` | string | `null` | Approximate total cycles accumulated across all cells in the dataset, Duration of cycling aging [cycles or EFC] |
| `rest_between_halfcycles_min` | array | `[]` | Rest time(s) between charge and discharge halfcycles within an aging cycle [min] |
| `sampling_rate_hz` | number | `null` | Data recording frequency [Hz]. Null if variable or unknown. |
| `sampling_rate_variable` | boolean | `false` | True if sampling rate differs between test phases (e.g., faster during charge/discharge, slower during rest) |
| `test_equipment` | string | `""` | Cycler/equipment manufacturer and model (e.g., `"BaSyTec CTS"`) |
| `notes` | string | `""` | Free-text for any additional protocol detail not captured above (multi-step switching currents, mechanical pressure, float voltage specifics, etc.) |

---

### `aging_matrix.rawdata`

Populate when `has_rawdata` is true. Describes the cycling timeseries data.

| Field | Type | Default | Description |
|---|---|---|---|
| `recorded_variables` | array | `[]` | Variables available in the raw timeseries. Use controlled vocabulary (`rawdata_recorded_variables`). |
| `file_formats` | array | `[]` | File format(s) of the raw data. Use controlled vocabulary. |
| `data_structure` | string | `""` | How files are organized. Use controlled vocabulary. |
| `data_size_gb` | number | `null` | Total dataset size [GB] |
| `data_quality_notes` | string | `""` | Notes on data quality, completeness, or preprocessing applied |
| `known_issues` | string | `""` | Documented problems, gaps, anomalies, or limitations |

---

### `aging_matrix.checkup`

Populate when `has_checkup` is true. Describes the periodic characterization tests (RPTs). These conditions are often different from the aging conditions (e.g., RPT always run at 25 °C regardless of aging temperature).

| Field | Type | Default | Description |
|---|---|---|---|
| `types` | array | `[]` | Types of characterization performed at each checkup. Use controlled vocabulary (`checkup_types`). |
| `recorded_variables` | array | `[]` | Variables recorded or derived at each checkup and tracked over aging (e.g., capacity, resistance, EIS). Use controlled vocabulary (`checkup_recorded_variables`). |
| `interval` | object | — | Checkup frequency (see sub-object below) |
| `temperature_c` | array | `[]` | Temperature(s) at which checkups are performed [°C]. Specify even when standardized (e.g., `[25]`), as it often differs from aging temperature. |
| `charge_crates` | array | `[]` | C-rates used for capacity measurements during checkup (e.g., `[0.1, 0.5, 1.0]`) |
| `soc_levels_pct` | array | `[]` | SOC points at which pulse or impedance tests are performed during checkup [%] |
| `notes` | string | `""` | Free-text for checkup protocol details (rest times, cutoff currents, interval variations by group, etc.) |

### `aging_matrix.checkup.interval`

| Field | Type | Default | Description |
|---|---|---|---|
| `value` | number | `null` | Numeric interval value |
| `unit` | string | `""` | Unit for the interval value. Use controlled vocabulary: `"cycles"`, `"efc"`, `"days"`, `"weeks"`, `"months"`. |

---

## `notes`

| Field | Type | Default | Description |
|---|---|---|---|
| `notes` | string | `""` | Free-form field for any additional information not covered elsewhere |

---

## Controlled Vocabularies

All categorical fields reference the `_controlled_vocabularies` section in `dataset_template.json`. Key vocabularies:

| Vocabulary key | Used by field |
|---|---|
| `aging_modes_types` | `aging_matrix.aging_modes.types` |
| `constant_halfcycle` | `aging_matrix.aging_modes.constant_halfcycle` |
| `study_design` | `aging_matrix.aging_modes.study_design` |
| `eol_criteria` | `aging_matrix.aging_modes.eol_criteria` |
| `cycling_range_basis` | `aging_matrix.electrical.cycling_range_basis` |
| `storage_level_basis` | `aging_matrix.electrical.storage_level_basis` |
| `charge_protocol` | `aging_matrix.electrical.charge_protocol` |
| `discharge_protocol` | `aging_matrix.electrical.discharge_protocol` |
| `drive_cycle_profiles` | `aging_matrix.electrical.drive_cycle_profiles` |
| `ambient_control` | `aging_matrix.thermal.ambient_control` |
| `thermal_management` | `aging_matrix.thermal.thermal_management` |
| `rawdata_recorded_variables` | `aging_matrix.rawdata.recorded_variables` |
| `file_formats` | `aging_matrix.rawdata.file_formats` |
| `data_structure` | `aging_matrix.rawdata.data_structure` |
| `checkup_types` | `aging_matrix.checkup.types` |
| `checkup_recorded_variables` | `aging_matrix.checkup.recorded_variables` |
| `checkup_interval_unit` | `aging_matrix.checkup.interval.unit` |
| `form_factor` | `cell_info.form_factor` |
| `cathode_chemistry` | `cell_info.cathode_chemistry` |
| `anode_chemistry` | `cell_info.anode_chemistry` |
| `manufacturer` | `cell_info.manufacturer` |
| `license` | `dataset_metadata.license` |
| `country` | `dataset_metadata.country` |

---

## Usage Notes

1. **Default values:**
   - Numeric fields: `null`
   - String fields: `""`
   - Array fields: `[]`
   - Boolean fields: `false`

2. **Controlled vocabularies:** Prefer values from the controlled vocabulary. Use `"custom"` when the concept exists but is not listed. Use `"unknown"` when the information is genuinely unavailable.

3. **Units are encoded in field names:**
   - `_ah` = Ampere-hours · `_v` = Volts · `_wh` = Watt-hours
   - `_c` = Degrees Celsius · `_hz` = Hertz · `_pct` = Percent
   - `_min` = Minutes · `_gb` = Gigabytes · `_g` = Grams · `_mm` = Millimeters

4. **Conditional sections:** Only populate `aging_matrix.rawdata` when `has_rawdata` is `true`. Only populate `aging_matrix.checkup` when `has_checkup` is `true`.

5. **Cycling ranges format:** Always use `"low-high"` strings (e.g., `"2.5-4.2"` or `"0-100"`). Do not use nested arrays or objects.

6. **`_controlled_vocabularies` section:** Present in the template as a reference only. Remove it from individual dataset files before finalizing.
