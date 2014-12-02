=setup

[Configuration]
ListFileExtension = TXT

[Window]
Name = HAS
Head = Report Exceedences


[Labels]
OUT     = END   2 10 Report Output

[Fields] 
OUT     = 3   10 INPUT   CHAR       10  0  FALSE   FALSE  0.0 0.0 'S' $OP

[Perl]

=cut


=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

 This HYSCRIPT enables the HYDSYS.ERR to be a report produced from a rating table exceedence.
  
=cut


use strict;
use warnings;

use Data::Dumper;
use FileHandle; 
use DateTime;
#use Time::localtime;
use Env;
use File::Copy;
use File::stat;
use File::Path qw(make_path remove_tree);
use File::Fetch;
use Try::Tiny;
use Cwd;

use FindBin qw($Bin);

#Hydrological Administration Services Modules
use local::lib "$Bin/HDS/";

#Hydstra modules
use HydDLLp;

#Hydstra libraries
require 'hydlib.pl';
require 'hydtim.pl';

#Globals
my $prt_fail = '-P';
my $level_varnum = '100.00';

main: {
  
  my ($dll,$use_hydbutil,%ini,%temp,%errors,@junkfiles);
  
  #Gather parameters and config
  my $script     = lc(FileName($0));
  #IniHash($ARGV[0],\%ini, 0, 0);
  #IniHash($script.'.ini',\%ini, 0 ,0);
  
  #Get config values
  my $temp          = HyconfigValue('TEMPPATH');
  my $junk          = HyconfigValue('JUNKPATH').'documents\\';
  my $docpath       = HyconfigValue('DOCPATH');
  my $quarantine    = $temp.'\\quarantine_documents\\';
  MkDir($quarantine);
  MkDir($junk);
  
  my $hydsys_err = $temp.'HYDSYS.ERR';
  
  #Gather parameters
  #my %photo_types   = %{$ini{'photo_types'}};
  #my %emails        = %{$ini{'email_setup'}};
  #my $import_dir    = $ini{perl_parameters}{dir};  
  #my $reportfile    = $ini{perl_parameters}{out};  
  my $reportfile    = $junk."output.txt";  
  my $nowdat = substr (NowString(),0,8); #YYYYMMDDHHIIEE to YYYYMMDD for default import date
  my $nowtim = substr (NowString(),8,4); #YYYYMMDDHHIIEE to HHII for default import time
  
  try{
    $dll=HydDllp->New();
  }
  catch{
    Prt($prt_fail,NowStr().": *** ERROR An error occured while initialising HYDDLLP\n");
    $use_hydbutil=1;
    
  };
  #Prt($prt_fail,NowStr().": docpath [$docpath] import_dir [$import_dir] photo_types []\n"); #.Dumper(%photo_types)."]\n");

   my $siteref = $dll->JSonCall({
          'function' => 'get_db_info',
          'version' => 3,
          'params' => {
              'table_name'  => 'vrwmon',
              'field_list'  => ['station'],
              'complex_filter' => [
                   {
                      'fieldname' => 'param',
                      'operator' => 'CONT',
                      'value' => 'CONT',
                   },
                ],
              'return_type' => 'array'
          }
      }, 1000000);
  
  my @rows = @{$siteref->{return}->{rows}};
  
  my $out = "C:\\temp\\exceedDump.txt";
  open my $io, ">", $out;
  print $io "sitref ".HashDump($siteref);
  
  my $repfile = "C:\\temp\\reprilfeexceed.txt";
  
  foreach my $record ( 0 ..  $#rows ){
    my $site = $rows[$record]->{station};
    
    my $varref = $dll->JSonCall({
      'function' => 'get_variable_list', 
      'version' => 1, 
      'params' => {     
        'site_list'  => $site,
        'datasource' => "A"
        }
    },5000);

    my %sitevar;
    my @ret = @{$varref->{return}->{sites}};
    my @variables = @{$ret[0]->{variables}};
    foreach my $varcount ( 0 .. $#variables ){
      my $var = $variables[$varcount]->{variable};
      $sitevar{$var}++;
    }
    
    Prt("-S","sitevar ".HashDump(\%sitevar)."]\n");
    
    next if ( ! defined $sitevar{$level_varnum} );
    
    
    Prt('-S',"site [$site]\n [".HashDump(\%{$rows[$record]})."]");
    #Prt(*HYFILER,"DELETE $site T$varcount /quiet\n");
    #my $job = "HYTRACEX $site A 100.00 141.00 INST 10 MINUTE N N 0 T0 0 00:00_01/01/1990 00:00_01/01/1990 SEARCH /quiet";
    my $junkfile = JunkFile('csv');
    my $paramfile = JunkFile('prm');
    push (@junkfiles,$junkfile);
    push (@junkfiles,$paramfile);
    
    OpenFile(*hPARAM,$paramfile,'>');
    Prt("-S",*hPARAM,qq(DATA $site A 100.00 141.00 INST\n));
    Prt("-S",*hPARAM,qq(TIME DAY 1 0 00:00_01/01/1990 00:00_01/01/1990 END $junkfile NO NO NO "HH:II:EE DD/MM/YYYY"\n));
    close hPARAM;

    my $job = qq(hycsv.exe "\@$paramfile" /quiet);
    
    PrintAndRun( '-RLS',"HYFILER DELETE $site T0 /quiet",0,1,$repfile);
    
    try {
      PrintAndRun( '-RLS',$job,0,1,$repfile) ;
      
    }
    catch {
      Prt('-P',"*** Error returned by previous job step\n");
    };
    
    if ( -e $hydsys_err ){
      open my $errf, "<", $hydsys_err;
          
      while ( my $line = <$errf>){
        $errors{$site}{$line}++;  
        my @exceed_headers = qw(site rating table release varfrom varto time value min max); 
        my @rowarr = split (' ',$line);
        
        foreach my $element ( 0 .. $#rowarr ){
          if ( $rowarr[$element] =~ 
        } 
        
        foreach $text ( @rowarr ){
          if ( $text  ){
          
          }
          
        }
      
      }

      close ($errf);
      
    }
    print $io "errors ".HashDump(\%{$errors{$site}});
  
  }
  
  
  close ($io);
  
  $dll->Close;
  unlink( @junkfiles);
=skip  
  my $hydsyserr = HyconfigValue('TEMPPATH').'HYDSYS.ERR';
  open my $io, "<", $hydsyserr;
    my %report;
    

    
    while ( my $line = <$io> ) {
Site  | Rating Table | Release | VarFrom | VarTo | Time | value | Min | Max 
    
    
        #2014/12/01 15:23:53.090 HYTRACEX Rating table 5 release 0 Exceeded
        #2014/12/01 15:23:53.090 HYTRACEX Site 231704A  VarFrom 100.00  VarTo 141.00
        #2014/12/01 15:23:53.090 HYTRACEX Time 05:20_25/08/2010
        #2014/12/01 15:23:53.090 HYTRACEX value = 0.304490566  Min Table val = 0.305  Max Table val = 2.0
        #2014/12/01 15:23:53.090 HYTRACEX 
              
        my ($date,$report) = split('HYTRACEX',$line);
        
        $report{$site}{report} .= $report.'\n';
      
    }
  }
  
  my @files = $fs->FList($import_dir,'*');
  shift @files;
  if ( $#files < 1 ) {
    Prt('-P',"no files");
  }
  else{
    foreach ( @files ) {
      #open my $fh, "<:encoding(utf8)", $_;
      my @file_dir = split(/\//,$_);
      my $file_name = $file_dir[$#file_dir];
      $file_name =~ s{( |-|~)}{_}gi;
      
      my @file_components = split(/_/,$file_name);
      my $site = $file_components[0]; 
      my $date = $file_components[1]; 
      
      my $siteref = $dll->JSonCall({
          'function' => 'get_db_info',
          'version' => 3,
          'params' => {
              'table_name'  => 'site',
              'field_list'  => ['station', 'stname'],
              'sitelist_filter' => $site,
              'return_type' => 'hash'
          }
      }, 1000000);
      
      
      my $valid = 1;
      my $reason = '';
      if ( ! defined ( $siteref->{return} )){
        Prt('-P',"Not Defined [".HashDump($siteref)."]"); 
        $valid = 0;
        $reason = "Site [$site] not registered in SITE table. Please register in table and re-import the documents";
        
      }
      else{
        my $stname = $siteref->{return}->{rows}->{$site}->{stname};
        
      }
   
      
      my $destination;
      if ( ! $valid ){
        $destination = $quarantine.$file_name;
        $errors{invalid}{$site}{filename} = $destination;
        $errors{invalid}{$site}{reason} = $reason;
      }
      else{
        my $site_docpath = $docpath.'SITE\\'.$site.'\\';
        MkDir( $site_docpath );
        $destination = $site_docpath.$file_name;
        $temp{$site}{files}{$file_name}++;
      }
      
      #if site not registered throw email error
      #if date unlikely throw email error
      #can we recognise file type (e.g. logger file, and then import with PROLOG?
      #If not then send to html error rerpot which gets sent to the nomiated user.
  
      if ( copy( $_, $destination ) ) {
        print NowStr()."   - Saved to [$destination]\n";  
      }
      else {
        Prt($prt_fail,NowStr() . "   *** ERROR - Copy [$_] Failed\n" );
      }
     
    }
    unlink (@files);  
    
    if ( defined ( $errors{invalid} )){
      open my $io, ">>", $reportfile;
      
      print $io "IMPORT DOCUMENTS ERROR REPORT\n";
      
      
      
    }
    else{
      my %hist = ();
      foreach my $site ( keys %temp ){
        my $descript = "Documents Import:\n";
        foreach my $file ( keys %{$temp{$site}{files}} ){
          $descript .= "$file\n";
        }  
        $hist{$site}{DESCRIPT}     = $descript;
        $hist{$site}{STATDATE}     = $nowdat;
        $hist{$site}{STATTIME}     = $nowtim;
        $hist{$site}{KEYWORD}      = 'DOCUMENTS';
        $hist{$site}{STATION}      = $site;
      }  
      
      my $rep = 'C:\\temp\\history_report.txt';
      
      my %params;
      my $history = Import::History->new();
      $history->update({'history'=>\%hist,'params'=>\%params});
    }  
    
    close ($reportfile);
    
  }    
  
  #Archive work area
  #PrintAndRun(HYDBUTIL DELETE history [PUB.$workarea]history "$rep" /FASTMODE);
  
  #Email any issues to the nominated users
  
  
  #update_history(\%history); 
  #error_report = create_error_report(\%errors); 
  #send_errors($error_report); 
  #zd
=cut  
}

1; # End of importer
