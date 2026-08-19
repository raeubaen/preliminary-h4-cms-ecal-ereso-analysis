Run list:
```
https://docs.google.com/spreadsheets/d/1hvROf58AUvwlSgFveNDmVWZLXPj80i-xjC784sdWq4A/edit?usp=sharing
```

List of good electron runs in this repo

Beamfiles in the ```beamfiles``` folder

Beamline energy spread details:
```
https://cds.cern.ch/record/702402/files/cer-000414329.pdf
```

Reconstructed files here (3x3 matrix): 
```
/eos/cms/store/group/dpg_ecal/comm_ecal/upgrade/testbeam/ECALTB_H4_Jun2026/Reco
```

Reconstruction from:
```
https://gitlab.cern.ch/ecal-daq-upgrade/DANTE/-/tags/v2026-260819
```

Template used (seed crystal @ 100 GeV, ch185, from run 20521):
```
https://lfrosina.web.cern.ch/TestBeam/AllTemplates/template_library_default.root
```

Runner (all reco jobs):
```
process_good_runs_2026_parallel.sh
```

Details on which runs have been used in:
```
merged_runs_2026.md
```

Fits made using:
```
https://github.com/campaneros/energy-resolution-fitter/blob/main/fit.sh
```


Timestamps of runs (to be uploaded yet):
```
timestamps_runs.txt
```
made with
```
cd /eos/cms/store/group/dpg_ecal/comm_ecal/upgrade/testbeam/ECALTB_H4_Jun2026/EB; rm /eos/user/r/rgargiul/www/timestamps_runs.txt; for f in $(ls -1d 2*); do ls -lartd $f | head -n 2 | tail -n 1 | awk '{print $6" "$7" "$8" "$9}' | awk -F "_" '{print $1}' >> /eos/user/r/rgargiul/www/timestamps_runs.txt; done
```
