hds-report-exceedence
=====================

# Version

Version 1.01

# Synopsis

Typically the Ratings Team in a surface water data group requires information on the time and rating number that a timeseries point exceeds the latest rating. To accommodate such a requirement, this HYSCRIPT reports on rating table exceedence in a table output. 

It emulates the type of output produced by a program like HYCSV's HYDSYS.ERR report. HYDSYS.ERR is generated when a program like HYCSV, 

1. Pushes data through a rating, and 
2. Finds a rating exceedence

This script enables all the exceedences to be assembled and output to one, email compliant, html report. The html output can be imported into an email script and sent weekly.

# Phased Ratings Logic

If the scripts finds a phased rating it;

1. Looks forward until the next non-phased rating and takes that rating as the end point for the current rating
2. Takes the phased rating date as the start date for the next rating
3. Uses the dll to get the max & min for the entire duration of the phasing dates

# Output Report

![Output Report](/images/report.png)

# Parameter screen

![Parameter screen](/images/psc.png)

# INI configuration

![INI file](/images/ini.png)

# TODO

### Phase changes

Look back to the last rating.

1. If there is ts but no rating - report
2. If the last rating is phase = T, then 
2.1. Set the startdate for the ts period back 1 week from the start date for ts for the JSonCall get_ts max & min
3. look forward to the next false (ie ignore true) - if no end date, take now

 
# Dependencies

  
# Bugs

Please report any bugs in the issues wiki.

