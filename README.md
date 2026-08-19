# ECAL TB H4 — June 2026

- **Run list**
  - [Google Sheet](https://docs.google.com/spreadsheets/d/1hvROf58AUvwlSgFveNDmVWZLXPj80i-xjC784sdWq4A/edit?usp=sharing)
  - List of good electron runs is also available in this repository.

- **Run timestamps**
  - Source file: `timestamps_runs.txt`
  - Generated with:
    ```bash
    cd /eos/cms/store/group/dpg_ecal/comm_ecal/upgrade/testbeam/ECALTB_H4_Jun2026/EB
    rm /eos/user/r/rgargiul/www/timestamps_runs.txt
    for f in $(ls -1d 2*); do
        echo "$f $(ls -lart $f | head -n 2 | tail -n 1 | awk '{print $6" "$7" "$8}')"
    done
    ```

- **Beam information**
  - Beam element logs:
    - Available in the `beamfiles/` folder.
  - Collimator information for each run:
    - `run_collimators_match.csv`
  - Beamline energy spread details:
    - [CERN document](https://cds.cern.ch/record/702402/files/cer-000414329.pdf)
  - Syncrotron radiation besm energy spread RMS (in %): 1.92e-7* E**(5/2), Fig.4 of the paper in the link above
  
- **Reconstructed data**
  - Reconstructed files, using a 3×3 matrix:
    - `/eos/cms/store/group/dpg_ecal/comm_ecal/upgrade/testbeam/ECALTB_H4_Jun2026/Reco`
  - Reconstruction software:
    - [DANTE v2026-260819](https://gitlab.cern.ch/ecal-daq-upgrade/DANTE/-/tags/v2026-260819)
  - Template used:
    - Seed crystal: **ch185**
    - Energy: **100 GeV**
    - Run: **20521**
    - [Template library](https://lfrosina.web.cern.ch/TestBeam/AllTemplates/template_library_default.root)

- **Reconstruction jobs**
  - Runner used for all reconstruction jobs:
    - `process_good_runs_2026_parallel.sh`

- **Merged runs**
  - Details on which runs have been used:
    - `merged_runs_2026.md`
  - Machine-readable version:
    - `merged_runs*.csv`
  - Collimator information for merged runs at **run level**:
    - `beamfiles/colls_runs_*ohm.csv`
  - Collimator information for merged runs at **energy level**:
    - `colls_energies_summary_*`
    - Almost all runs at the same energy have the same collimator settings.
    - The **BES is evaluated directly** in these files (with ```=SQRT( ((D2-C2)/2)^2 + ((F2-E2)/2)^2)/(27*SQRT(3))```)

- **Energy-resolution fits**
  - Fits performed using:
    - [energy-resolution-fitter — `fit.sh`](https://github.com/campaneros/energy-resolution-fitter/blob/main/fit.sh)
    - Results here: [energy-resolution-fitter — `rereco_*.csv`](https://github.com/campaneros/energy-resolution-fitter/blob/main/rereco_340.csv)
