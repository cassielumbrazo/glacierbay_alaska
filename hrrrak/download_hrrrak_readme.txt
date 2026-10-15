HRRR-AK download: Lone Island, Glacier Bay

1. Open a Linux terminal in the project and activate the environment:
   cd /path/to/glacierbay_alaska
   conda activate glacierbay
   # First-time setup (from repository root):
   # conda env create -n glacierbay -f envs/environment.yml
   # Full instructions: envs/set_up_environment.txt
   # To explore the included sample, start notebook 4 instead; no download needed.

2. Check required command-line tools (all must be found):
   command -v bash curl parallel wgrib2 date awk grep mktemp
   # Separate Linux tools: GNU Parallel, wgrib2, curl, Bash, GNU coreutils/date,
   # awk and grep. These are not installed by envs/environment.yml.
   date -d 20190401 +%Y%m%d

3. Run 1_create_bounding_box.ipynb using the glacierbay kernel.
   Copy the desired GRIB_AREA into hrrrak/download_hrrrak_lone_island.sh.
   Current small box: -136.373558:-136.217390 58.681422:58.762504
   Review HRRR_VARS, HRRR_DAY_HOURS, HRRR_FC_HOURS, and PARALLEL_JOBS.
   Current settings: 00,03,06,09,12,15,18,21 UTC runs; forecast leads 5,6,7 hours;
   15 parallel jobs, each using 2 wgrib2 threads. Adjust for available resources.

4. Run from hrrrak so downloaded files stay in that folder:
   cd hrrrak

   # One day (example; replace with your selected date):
   bash download_hrrrak_lone_island.sh 20190401

   # Inclusive date range (exactly two comma-separated dates):
   bash download_hrrrak_lone_island.sh 20190401,20190407

   # Full month (YYYY MM; zero-pad the month):
   bash download_hrrrak_lone_island.sh 2019 04

   # Optional archive: Google (default), AWS, or Azure:
   bash download_hrrrak_lone_island.sh 20190401 AWS
   bash download_hrrrak_lone_island.sh 2019 04 AWS

   Dates select initialization days in UTC; valid time = run time + lead time.
   Two comma-separated dates mean a continuous range, not two separate days.

5. Check output (24 GRIB2 files per complete day with current settings):
   find hrrr.20190401 -name '*.grib2' -type f | wc -l
   find hrrr.20190401 -name '*.grib2' -size 0
   wgrib2 hrrr.20190401/hrrr.t00z.wrfsfcf05.ak.grib2 -s | head
   # File count alone does not confirm valid contents; inspect download errors too.

6. Open ../2_process_hrrrak_grib_files.ipynb in VS Code.
   Select glacierbay; review its input/output paths and dates before running.

Archives: Google (default), AWS, and Azure. Each forecast tries the chosen
archive, then the other two if an HTTP, index, pipeline, or validation step fails.
Availability varies by archive and date; UofU is not supported.

Existing files are decoded and checked for notebook-2 fields before skipping.
A download is written to a private temporary directory and renamed only after
successful validation. Temporary files are removed on success, failure, or
handled interrupt/termination; failed jobs give a nonzero script exit status.
The script uses no FIFOs. SIGKILL or machine failure can leave temporary folders.

SNOD is snow depth and WEASD is snow water equivalent; ASNOW is accumulated
snowfall and is not a replacement for either. APCP accumulation intervals are
retained; notebook 2 explicitly selects the run-total starting at initialization.

Use a separate data folder when changing bounds or fields: field validation does
not prove an existing file matches new bounds. Do not overwrite the included
sample. Notebook 2 currently supports April 2019 and grids no larger than 10 x 10,
with additional Lone Island location checks. Match its expected runs/leads to
the script, and update notebooks 3/4 input filenames for a new sample.
See README.md (in the repository root) for the full workflow and current limits.
