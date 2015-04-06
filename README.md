hds-report-exceedence
=====================

HYSCRIPT wrapper for report ratings table exceedences using HYCSV

# Version

Version 1.01

# Synopsis

Typically the Ratings Team in a surface water data group requires information on the time and rating number that a timeseries point exceeds the latest rating. To accommodate such a requirement, this HYSCRIPT reports on rating table exceedence in a table output. 

It emulates the type of output produced by a program like HYCSV's HYDSYS.ERR report. HYDSYS.ERR is generated when a program like HYCSV, 

1. Pushes data through a rating, and 
2. Finds a rating exceedence

This script enables all the exceedences to be assembled and output to one, email compliant, html report. The html output can be imported into an email script and sent weekly.

# TODO

### Phase changes
Look back to the last rating.
1. if there is ts but no rating - report
2. if the last rating is phase = T, then take the SDATE of the previous rating as the SDATE for the JSonCall and max & min for the period
3. look forward to the next false (ie ignore true) - if no end date, take now.
 
# Dependencies

# Parameter screen

![Parameter screen](/images/psc.png)

# INI configuration

![INI file](/images/ini.png)
  
# Bugs

Please report any bugs in the issues wiki.

