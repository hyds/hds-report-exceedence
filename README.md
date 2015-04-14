hds-report-exceedance
=====================
Version 1.01

# Synopsis

Typically the Ratings Team in a surface water data group requires information on the time and rating number that a timeseries point exceeds the latest rating. To accommodate such a requirement, this HYSCRIPT reports on rating table exceedance in a table output. 

It emulates the type of output produced by a program like HYCSV's HYDSYS.ERR report. HYDSYS.ERR is generated when a program like HYCSV, 

1. Pushes data through a rating, and 
2. Finds a rating exceedance

HYCSV will error when an exceedance is found, so the workflow was to run it, find an exceedance, fix it, run HYCSV again to find the next exceedance, etc. This exceedance script however enables all the exceedances to be assembled and reported in one output.

It is also email compliant so that the html output can be imported into the body of an email and sent weekly to RATINGS administrators.

# Phased Ratings Logic

If the scripts finds a phased rating it;

* Looks forward until the next non-phased rating and takes that rating as the end point for the current rating
* Takes the preceeding phased rating date as the start date for the next rating
* Uses the dll to get the max & min for the phasing dates

# Output Report

![Output Report](/images/report.png)

# Parameter screen

![Parameter screen](/images/psc.png)

# INI configuration

![INI file](/images/ini.png)
 
# Dependencies

###Hydrological Data Services 
local::lib "$Bin/HDS/";

###Kisters modules
HydDLLp;

###Kisters libraries
'hydlib.pl';
'hydtim.pl';
  
# Bugs

Please report any bugs in the issues wiki.

