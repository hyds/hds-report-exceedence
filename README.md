hds-report-exceedance
=====================
Version 1.01

# Synopsis

Typically the Ratings Team in a surface water data group requires information on the time and rating number that a timeseries point exceeds the latest rating. To accommodate such a requirement, this ```HYSCRIPT``` reports on rating table exceedance in a table output. 

It emulates the type of output produced by a program like ```HYCSV```'s ```HYDSYS.ERR``` report. ```HYDSYS.ERR``` is generated when a program like ```HYCSV```, 

1. Pushes data through a rating, and 
2. Finds a rating exceedance

```HYCSV``` or ```HYTAB``` will error when an exceedance is found. So the workflow was to run it, find an exceedance, fix it, run HYCSV again to find the next exceedance, etc. 

The ```hds-report-exceedance``` ```HYSCRIPT``` enables all the exceedances to be assembled and reported in one output. It is also email compliant report so that the html output can be imported into the body of an email and sent weekly to RATINGS administrators.

# Phased Ratings Logic

For each non-phased rating, the script takes a rating and;

* Looks forward for the next non-phased rating and takes that rating as the end datetime for the timeseries maxmin lookup 
* Looks backward for the next non-phased rating and takes second earliest phased rating as the start datetime for the timeseries maxmin lookup
* Uses the dll to get the max & min for the phasing dates

A phased rating is accommodated by the above procedure

# Output Report

![Output Report](/images/report.png)

# Parameter screen

![Parameter screen](/images/psc.png)

# HYXPLORE Menu Location

All ```HYSCRIPTS``` produced by HDS are linked into the ```HYXPLORE``` menus and stored in the company fav folder under the HDS sub-folder:

![Hyxplore Menu](/images/hyxplore.png)

# HYSCRIPT Physical Location

The physical location of all ```HYSCRIPTS``` produced by HDS are stored in the ```INIPATH``` directory under the subdirectory named ```HDS```. This is a relative directory configured in the ```HYCONFIG.INI``` file. There will also be a GitHub repository associated with the script that stores a versioned copy.

A typical location for the script might be: 

```
>C:\hydstra\hyd\dat\ini\hds\hds-report-exceedance.hsc
```

But you will need to consult HYCONFIG setup appropriate to your system.

 
# Dependencies



###Hydrological Data Services Modules
* /HDS/ Directory

###Kisters modules
* HydDLLp

###Kisters libraries
* hydlib.pl
* hydtim.pl
  
# Bugs

Please report any bugs in the issues wiki.

