# Lone Island: HRRR-AK and station observations

## Start here: the `envs/` folder

[envs/environment.yml](envs/environment.yml) defines the **glacierbay** Python
environment required for this project. Use it for every notebook. Additional
setup instructions are in [envs/set_up_environment.txt](envs/set_up_environment.txt).

From the `glacierbay_alaska` project folder, create the environment once:

```sh
conda env create -n glacierbay -f envs/environment.yml
conda activate glacierbay
python -m ipykernel install --user --name glacierbay --display-name "Python (glacierbay)"
```

For later sessions, run `conda activate glacierbay`. In VS Code, select
**glacierbay** in the Python interpreter and notebook kernel pickers. Mamba can
be used instead of Conda for environment creation and activation.
If `glacierbay` already exists, activate it rather than recreating it.

## Start with the included sample

**After setting up `glacierbay`, open
[4_explore_hrrrak_netcdf.ipynb](4_explore_hrrrak_netcdf.ipynb) directly and run its
cells in order.** The cleaned April 1–7 sample NetCDF is included:
[hrrrak/lone_island_small_hrrrak_20190401_20190407_crs.nc](hrrrak/lone_island_small_hrrrak_20190401_20190407_crs.nc).
No new download, GRIB processing, or cleaning is needed to start exploring.
The notebook reads this file without changing it. Its plots use local data;
no network access or separate downloader tools are needed.

## Preparing more data

Follow **notebook 1 → download script → notebook 2 → notebook 3 → notebook 4**
when preparing a new sample. The sections below explain each step. See
[Changing samples](#changing-samples-current-limits) before changing dates or area.

## Project and first sample

This project introduces the user to comparing HRRR-AK model
forecasts with meteorological station observations near **Lone Island, Glacier
Bay National Park, Alaska**.

| Item | Current scope |
| :--- | :--- |
| Island reference point | 58.721963, −136.295474 |
| Coordinate source | Map pin from Google Maps; exact station location unconfirmed |
| Available station years | 2018, 2019, 2020 |
| Initial model sample | April 1–7, 2019 initialization dates; small Lone Island domain |
| Forecast selection | Eight initialization times per day; 5-, 6-, and 7-hour leads |
| Processed sample | 168 forecast records on a 3 × 3 grid |

The notebooks below prepare and explore model data. Station-data loading and
model–observation comparison are future steps.

## 1. Choose the bounding box

Open [1_create_bounding_box.ipynb](1_create_bounding_box.ipynb) and run the cells
in order. It calculates two editable boxes centered on the island reference:

- **Lone Island:** approximately 9 × 9 km for the initial small sample.
- **Glacier Bay region:** approximately 180 × 180 km for regional exploration;
  a provisional extent, not an official park boundary.

The notebook plots both extents and prints a **`GRIB_AREA`** setting for the
download script. Background maps require internet access; set
`show_basemap = False` for an offline diagram.

## Download the GRIB files

Copy the chosen **`GRIB_AREA`** into
[hrrrak/download_hrrrak_lone_island.sh](hrrrak/download_hrrrak_lone_island.sh).
Review its variables, initialization times, forecast leads, and parallel-job
settings before running it.

Follow [hrrrak/download_hrrrak_readme.txt](hrrrak/download_hrrrak_readme.txt) for prerequisites,
command options, and output checks. The download requires Bash, curl, GNU
Parallel, wgrib2, and GNU date in addition to the Python environment.

Run from the data folder so files are saved there. For the current sample:

```sh
conda activate glacierbay
cd hrrrak
bash download_hrrrak_lone_island.sh 20190401,20190407
```

The two dates specify an **inclusive range of initialization days in UTC**.
Downloads go into `hrrrak/hrrr.YYYYMMDD/`. Existing files are skipped only after
validation of GRIB decoding and the fields required by notebook 2;
use a separate output folder when changing the domain or variables.

## 2. Process the GRIB files into NetCDF

Open [2_process_hrrrak_grib_files.ipynb](2_process_hrrrak_grib_files.ipynb).
It inventories downloads, reads selected meteorological fields, checks that the
grids and units agree, and combines forecasts into one NetCDF.

**Current dates:** `sample_start = "2019-04-01"` and
`sample_end = "2019-04-07"`. Wait for the selected downloads to finish. With the
current run/lead settings, each day needs **24 files**; missing files stop the
notebook by default. The partially downloaded April 8 folder is excluded.

**Output:** `hrrrak/lone_island_small_hrrrak_20190401_20190407.nc`.

The file retains native units, initialization times, forecast leads, and UTC
valid times. Valid times extend into April 8 because of forecast lead times.
`precip_total` is accumulated from initialization to valid time, not an hourly
precipitation amount.

## 3. Check and clean the spatial metadata

Open [3_clean_hrrrak_netcdf.ipynb](3_clean_hrrrak_netcdf.ipynb).
It checks values, units, forecast timing, and grid locations, then recovers the
**native polar stereographic CRS** from an original GRIB file. It restores
projected `x`/`y` coordinates in meters and verifies them against latitude and
longitude before saving.

**Output:** `hrrrak/lone_island_small_hrrrak_20190401_20190407_crs.nc`.

This step preserves all weather values and units. It does not fill gaps,
resample the grid, or extract a point time series. Keep the original GRIB files
available when running this notebook; it uses one to verify projection metadata.

## 4. Explore the cleaned dataset

Open [4_explore_hrrrak_netcdf.ipynb](4_explore_hrrrak_netcdf.ipynb).
It reads the cleaned `_crs.nc` file and guides the student through:

- Inspecting variables, coordinates, units, and attributes.
- Understanding initialization time, lead time, and valid time.
- Selecting the nearest model grid-cell center to the Lone Island reference.
- Plotting the small grid and an air-temperature time series.
- Exploring other variables through exercises and recording findings.

The point selection remains in memory, and the input file is unchanged. This
notebook uses the CRS saved by notebook 3 and does not need the original GRIB
files. Start here using the included sample; notebook 3 is needed only when
regenerating cleaned data. The selected model cell represents an area, not a
verified station point.

## Changing samples: current limits

The current notebooks intentionally protect the small Lone Island sample.
**The larger box in notebook 1 cannot be processed by notebook 2 unchanged.**

| Setting | Where to update or review |
| :--- | :--- |
| Spatial extent | Set sizes in notebook 1; copy its `GRIB_AREA` into the download script. Use a separate data folder for different bounds or fields. |
| Download dates | Supply initialization dates to `hrrrak/download_hrrrak_lone_island.sh`. Two dates mean an inclusive range; runs use UTC. |
| Runs and leads | Keep the script's `HRRR_DAY_HOURS` / `HRRR_FC_HOURS` consistent with notebook 2's `run_hours` / `lead_hours`. |
| Processing dates | Set notebook 2's `sample_start` and `sample_end`. Its discovery pattern and date guard currently restrict processing to **April 2019**. Other months require an explicit reviewed code change. |
| Spatial checks | Notebook 2 rejects grids larger than **10 × 10 cells** and locations outside the Lone Island neighborhood. Keep these checks; a larger/new region requires deliberate adaptation and validation. |
| Raw and cleaned filenames | Notebook 2 names its output from the initialization-date range. Update notebook 3's `input_path` and notebook 4's `input_path` to the intended files; both currently name the April 1–7 sample explicitly. Notebook 3 adds `_crs` to its input stem. |
| CRS assumptions | Notebook 3 supports this sample's northern polar stereographic grid on the GRIB model sphere (Earth shape 6). Verify projection and grid checks for new data; do not assign an arbitrary EPSG code. |

Keep missing-file, unit, timing, and grid checks enabled. Update explanatory
Markdown and sample labels when changing samples. Notebooks 2 and 3 replace
their derived output on rerun; use a separate folder/name to preserve the
included sample. Run notebook 4 directly to avoid regenerating it.

## Save outputs for GitHub

GitHub displays saved notebook outputs; it does not run Python. After running a
notebook with the **glacierbay** kernel, **save it with its outputs** (`Ctrl+S`)
and commit the `.ipynb`. Plotting notebooks use `%matplotlib inline` to embed
static figures. Keep those outputs when saving so that everyone can view the
figures and tables directly in the GitHub browser.

