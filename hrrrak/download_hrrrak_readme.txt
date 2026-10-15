HRRR-AK download: Lone Island, Glacier Bay

1. Open a Linux terminal in the project and activate the environment:
   cd /home/cassie/python/repos/glacierbay_alaska
   conda activate glacierbay
   # First-time setup: envs/set_up_environment.txt (environment.yml is in envs/).

2. Check required command-line tools (all must be found):
   command -v bash curl parallel wgrib2 date
   # Requires GNU Parallel and GNU date (date -d).

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
   bash download_hrrrak_lone_island.sh 20190401,20190404

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

Existing nonempty GRIB files are skipped. Use a separate output folder when
changing the bounding box or variables to avoid reusing an older subset.
