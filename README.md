# Monthly Steps

- open browser & go to git hub https://github.com/rkronvold/time-cost/ (repository is time-cost)
-  open timecostdata.conf & edit dates in input and output files to current month
- Verify input files are in the right places and named correctly to correspond with first few lines of timecostdata.conf (Monthly Hours from Billing folder, Class List Master & LookUps)
- Make folder for output if needed
- Make adjustments or additions to employees or rates in look up file as needed & add employees to vendor list in QB as needed
- Commit changes to timecostdata.conf
- open Ubuntu from shortcut or Windows menu (should be logged in as rkronvold@Glmusr76)
- cd time-cost
- git pull
- ./timecostdata.sh
- 1st 3 steps should take less than 30 seconds
- final steps should take 5-10 minutes
- review sanity checks
- Y to output file
- review output file for anomalies before using Transaction Pro to import into QB
