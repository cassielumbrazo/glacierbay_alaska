# Project environment

Use the existing Conda environment `glacierbay` for all Python execution,
notebook validation, and package management in this project. Do not use the
parent workspace's `.venv` or Conda base environment for this project's work.
Use `conda run -n glacierbay ...` or its Python interpreter directly.

Keep project notebooks configured for the `glacierbay` kernel. Preserve the
distinction between the Lone Island reference point and unconfirmed station
coordinates.

## Notebook rendering

Keep notebooks readable on GitHub: use `%matplotlib inline` for static plots,
and retain real executed outputs when saving notebooks. Preserve existing
outputs during edits. Do not fabricate results or execute incomplete data
processing merely to populate outputs; state which outputs are pending.
