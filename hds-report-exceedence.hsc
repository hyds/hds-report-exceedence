=setup

[Configuration]
ListFileExtension = TXT

[Window]
Name = HAS
Head = Report Exceedences


[Labels]
SITELIST    = END   20   4 #MESS(SYS.COMMON.SITELIST)
OUT         = END   +0  +1 Report Output

[Fields] 
SITELIST    = 21   4 INPUT   CHAR       30  0  TRUE   0.0 0.0 '0                             ' STN
OUT         = +0  +1 INPUT   CHAR       10  0  FALSE   FALSE  0.0 0.0 'S' $OP

[Perl]

=cut


=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

 This HYSCRIPT reports on RATINGS exceedences capturing max val for the ratings date and time 
 Takes phased changed into consideration
 
=cut

=head1 TODO

  #Phase changes
  #Look back to the last rating.
  #1. if there is ts but no rating - report
  #2. if the last rating is phase = T, then take the SDATE of the previous rating as the SDATE for the JSonCall and max & min for the period
  #3. look forward to the next false (ie ignore true) - if no end date, take now.
  
  # AUTOJOB needs to be on new VM
  
  # AUTOJOB NEEDS LOGGING
  # AUTOJOB NEEDS ON_FAIL LOGGING & EMAILING
  # AUTOJOB NEEDS 
  # could I run an AWS server which sees the Hydstra server through the AMAZON network, and then run node on that server?
  # could I use the Linux Fedora restart & schedule tools akin to PM2 on that to run 
  #   - all email things (if reports fail)
  #   - a logging web page which has access to all the logs of things and alerts for fails etc?
  #   - scheduled processes through sh bash files
  
  # * Need html report for email with a table (check the outlook/gmail etc html capabilities regarting css)?
  # * Need text report to accompany all emails?
  # * Need to merge all HYAUDIT results to one html report?
  # * How do we put this in the AUTOJOB? 
  #   - One job per audit? = multiple emails?
  #   - One job per user email?
  #   - One 
  # 

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
use File::Slurp;
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
  
  my ($dll,$use_hydbutil,%ini,%temp,%errors,%report,@junkfiles);
  
  #Gather parameters and config
  my $script     = lc(FileName($0));
  #IniHash($ARGV[0],\%ini, 0, 0);
  #IniHash($script.'.ini',\%ini, 0 ,0);
  
  #Get config values
  my $temp          = HyconfigValue('TEMPPATH');
  my $junk          = HyconfigValue('JUNKPATH').'documents\\';
  my $docpath       = HyconfigValue('DOCPATH');
  my $inipath       = HyconfigValue('INIPATH');
 
  MkDir($junk);
  
  
  #Gather parameters
  #my %photo_types   = %{$ini{'photo_types'}};
  #my %emails        = %{$ini{'email_setup'}};
  #my $import_dir    = $ini{perl_parameters}{dir};  
  my $reportfile    = $ini{perl_parameters}{out};  
  my $html_template = $inipath.'\\hds\\html\\email.html';
  my $html = read_file( $html_template );

  Prt('-P',"html [$html]\n");
  
  #my $reportfile    = $junk."output.txt";  
  my $nowdat = substr (NowString(),0,8); #YYYYMMDDHHIIEE to YYYYMMDD for default import date
  my $nowtim = substr (NowString(),8,4); #YYYYMMDDHHIIEE to HHII for default import time
  

  my $hydsys_err = $temp.'HYDSYS.ERR';
  #Prt('-P',"report [$reportfile]\n");
  
  try{
    $dll=HydDllp->New();
  }
  catch{
    Prt($prt_fail,NowStr().": *** ERROR An error occured while initialising HYDDLLP\n");
    $use_hydbutil=1;
    
  };
  #Prt($prt_fail,NowStr().": docpath [$docpath] import_dir [$import_dir] photo_types []\n"); #.Dumper(%photo_types)."]\n");

   open my $rep, ">>", $reportfile;
   print $rep "Exceedence Report \n"; 

=skip   
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
  
=cut  
  my $out  = $inipath."hds\\html\\emailTemplate.html";
  #my $out = "C:\\temp\\exceed.html";
  
  
  #my $out = $inipath."\\hds\\exceedDump.txt";
  
  open my $io, ">>", $reportfile;
  #print $io "sitref ".HashDump($siteref);
  print $io "site , reftab , release , max_stage_rating, max_val , max_tim\n";
      
  my $repfile = "C:\\temp\\reprilfeexceed.txt";
  
  #Phase changes
  #Look back to the last rating.
  #1. if there is ts but no rating - report
  #2. if the last rating is phase = T, then take the SDATE of the previous rating as the SDATE for the JSonCall and max & min for the period
  #3. look forward to the next false (ie ignore true) - if no end date, take now.
  
  #Prt('-P',"tscall [".HashDump($tscall)."]\n");
  
   my $site = '221001A';
   my $ratper = $dll->JSonCall({'function' => 'get_db_info',
          'version' => 3,
          'params' => {
              'table_name'  => 'rateper',
              'field_list'  => ['sdate','stime','phase','reftab'],
              'complex_filter' => [
                   {
                      'fieldname' => 'varfrom',
                      'operator' => 'EQ',
                      'value' => '100.00',
                   },{
                      'combine'=>'AND',
                      'left'=>'(',           #begin AND
                      'fieldname' => 'varto',
                      'operator' => 'EQ',
                      'value' => '141',
                      'right'=>')',           #end AND
                    },{
                      'combine'=>'AND',
                      'left'=>'(',           #begin AND
                      'fieldname' => 'station',
                      'operator' => 'EQ',
                      'value' => $site,
                      'right'=>')',         #end AND
                    },
                ],
              'return_type' => 'array'
          }
      }, 1000000);

  
  #Prt('-P',"rateper [".HashDump($ratper)."]\n");
  
=skip

{return}
  {rows}
    [0]
      {phase}=false
      {sdate}=19930526
      {stime}=1500.00

=cut
  my @ratings = @{$ratper->{return}->{rows}};
  foreach my $rating ( 0 ..  $#ratings ) {
    #Prt('-P',"Phase [".$ratings[$rating]->{phase}."]\n");
    print "checking rating [$rating] \n";
    if ( $ratings[$rating]->{phase} eq 'false' ){
      print "no phased rating\n";  
      my $next_rating = $rating + 1;
      
      my $reftab = $ratings[$rating]->{reftab};
      my $sdate = $ratings[$rating]->{sdate};
      my $stime = $ratings[$rating]->{stime};
      
      my ($hhmm,$ss) = split('\.',$stime);
      my $start_time = $sdate.sprintf("%04d",$hhmm).sprintf("%02d",$ss);
      my $edate = $ratings[$next_rating]->{sdate};
      my $etime = $ratings[$next_rating]->{stime};
      my ($ehhmm,$ess) = split('\.',$etime);
      my $end_time = $edate.sprintf("%04d",$ehhmm).sprintf("%02d",$ess);

      print "start_time [$start_time] end_time [$end_time]\n";
    
      my $ratepts = $dll->JSonCall({'function' => 'get_db_info',
          'version' => 3,
          'params' => {
              'table_name'  => 'ratepts',
              'sitelist_filter'=>$site,
              'return_type' => 'hash',
              'filter_values'=> {
                'station'=> $site,
                'table'=>$reftab,
                'varfrom'=> 100,
                'varto'=> 141,
              },

          },
      }, 1000000);

      #my @rateponits = @{$ratepts->{return}->{rows}};
      my %ratepoints = %{$ratepts->{return}->{rows}->{$site}->{'100.00'}->{141}->{$reftab}};
      #Prt('-P',"RATEPOINTS [".HashDump(\%ratepoints)."]");

      my $count = 0;
      my $releases_count = keys %ratepoints;
      
      my $latest_release;
      
      #foreach my $release (sort { $ratepoints{$a} <=> $ratepoints{$b} or $a cmp $b } keys %ratepoints) {
      foreach my $release (sort {$a <=> $b} keys %ratepoints ) {
          if ($count == $releases_count-1){
              $latest_release = $release;
          }
          $count++;
      }

      #Prt('-P'," release count [$releases_count], Latest release [$latest_release]\n");
      
      my $ratept = $dll->JSonCall({'function' => 'get_db_info',
          'version' => 3,
          'params' => {
              'table_name'  => 'ratepts',
              'sitelist_filter'=>$site,
              'return_type' => 'array',
              'filter_values'=> {
                'station'=> $site,
                'table'=>$reftab,
                'varfrom'=> 100,
                'varto'=> 141,
                'release'=>$latest_release,
              },

          },
      }, 1000000);

      
      my @rate = @{$ratept->{return}->{rows}};
      #Prt('-P',"RATEPOINTS [".HashDump(\@rate)."]");
      #print $io HashDump(\@rate);

      my $min_stage_rating = $rate[0]->{stage}; 
      my $min_stage_rating_release = $rate[0]->{release};
      my $min_stage_rating_table = $rate[0]->{table};
      my $varfrom = $rate[0]->{varfrom};
      my $varto = $rate[0]->{varto};
      
      my $max_stage_rating = $rate[$#rate]->{stage};
      my $max_stage_rating_release = $rate[$#rate]->{release};
      my $max_stage_rating_table = $rate[$#rate]->{table};
      
      #Prt('-P',"RATEPOINTS OUPUT: \nmin_stage [$min_stage_rating]\nrelease [$min_stage_rating_release]\nmax_stage [$max_stage_rating]\n release [$max_stage_rating_release]");
      
      
=skip      
      my $ratepts = $dll->JSonCall({'function' => 'get_db_info',
          'version' => 3,
          'params' => {
              'table_name'  => 'ratepts',
              'complex_filter' => [
                   {
                      'fieldname' => 'varfrom',
                      'operator' => 'EQ',
                      'value' => '100.00',
                   },{
                      'combine'=>'AND',
                      'left'=>'(',           #begin AND
                      'fieldname' => 'varto',
                      'operator' => 'EQ',
                      'value' => '141',
                      'right'=>')',           #end AND
                    },{
                      'combine'=>'AND',
                      'left'=>'(',           #begin AND
                      'fieldname' => 'table',
                      'operator' => 'EQ',
                      'value' => $reftab,
                      'right'=>')',           #end AND
                    },{
                      'combine'=>'AND',
                      'left'=>'(',           #begin AND
                      'fieldname' => 'station',
                      'operator' => 'EQ',
                      'value' => $site,
                      'right'=>')',         #end AND
                    },
                ],
              'return_type' => 'array'
          }
      }, 1000000);
=cut
      #print $io HashDump($ratepts);
      #close ($io);
      #Prt('-P',"ratepts [".HashDump($ratepts)."]\n");
      
      #my @rateponits = @{$ratepts->{return}->{rows}};
      #my $max_stage = $rateponits[$#rateponits]->{stage};
      #my $release = $rateponits[$#rateponits]->{release};
      #Prt('-P',"max_stage [$max_stage]\n");

=skip

{return}
  {rows}
    [0]
      {datecreate}=18991230
      {datemod}=20000522
      {dbver14}=false
      {disch}=0.00000
      {release}=1
      {rqual}=150
      {stage}=-1.000000
      {station}=221001A
      {table}=1
      {timecreate}=0
      {timemod}=816
      {usercreate}=
      {usermod}=NUR
      {varfrom}=100.00
      {varto}=141
    [1]
      {datecreate}=18991230
      {datemod}=20000522
      {dbver14}=false
      {disch}=0.00000
      {release}=1
      {rqual}=150
      {stage}=0.194000
      {station}=221001A
      {table}=1
      {timecreate}=0
      {timemod}=816
      {usercreate}=
      {usermod}=NUR
      {varfrom}=100.00
      {varto}=141
    [2]

=cut      
      
      my $tscall = $dll->JSonCall({ 'function'=> 'get_ts_traces', 
        'version'=> 2,
        'params'=> {
          'site_list'=> '221001a', 
          'datasource'=> 'A', 
          'varfrom'=> '100.00', 
          'varto'=> '100.00', 
          'start_time'=> $start_time, 
          'end_time'=> $end_time, 
          'data_type'=> 'max', 
          'interval'=> 'period', 
          'multiplier'=> '1'
        }
      },100000);
      
      #Prt('-P',"tscal [".HashDump($tscall)."]\n");
      
      my $max_val = $tscall->{return}->{traces}[0]->{trace}[0]->{v};
      my $max_tim = $tscall->{return}->{traces}[0]->{trace}[0]->{t};
      
      my $max_str_tim = StrtoPrm($max_tim);
      
      my $tsmincall = $dll->JSonCall({ 'function'=> 'get_ts_traces', 
        'version'=> 2,
        'params'=> {
          'site_list'=> '221001a', 
          'datasource'=> 'A', 
          'varfrom'=> '100.00', 
          'varto'=> '100.00', 
          'start_time'=> $start_time, 
          'end_time'=> $end_time, 
          'data_type'=> 'min', 
          'interval'=> 'period', 
          'multiplier'=> '1'
        }
      },100000);
      
      #Prt('-P',"tscal [".HashDump($tscall)."]\n");
      
      my $min_val = $tsmincall->{return}->{traces}[0]->{trace}[0]->{v};
      my $min_tim = $tsmincall->{return}->{traces}[0]->{trace}[0]->{t};
      my $min_str_tim = StrtoPrm($min_tim);
  
      if ( $max_val > $max_stage_rating  ){
        #print $io "$site , $reftab , $max_stage_rating_release , $max_stage_rating, $max_val , $max_str_tim\n";
        my $key = $site.'~'.$reftab.'~'.$max_stage_rating_release.'~'.$max_stage_rating;
        $report{body}{$station}{max}{$key}{'Station'}                         = $site;
        $report{body}{$station}{max}{$key}{'Ref Table'}                       = $reftab;
        $report{body}{$station}{max}{$key}{'Release'}                         = $max_stage_rating_release;
        $report{body}{$station}{max}{$key}{'Stage Max Rating'}                = $max_stage_rating;
        $report{body}{$station}{max}{$key}{'Max Stage'}                       = $max_val;
        $report{body}{$station}{max}{$key}{'Max Stage Time'}                  = $max_str_tim;
      }
      elsif ( $min_val < $min_stage_rating){
        #print $io "$site , $reftab , $max_stage_rating_release , $min_stage_rating, $min_val , $min_str_tim\n";
        my $key = $site.'~'.$reftab.'~'.$max_stage_rating_release.'~'.$min_stage_rating;
        $report{body}{$station}{min}{$key}{'Station'}                         = $site;
        $report{body}{$station}{min}{$key}{'Ref Table'}                       = $reftab;
        $report{body}{$station}{min}{$key}{'Release'}                         = $max_stage_rating_release;
        $report{body}{$station}{min}{$key}{'Stage Max Rating'}                = $min_stage_rating;
        $report{body}{$station}{min}{$key}{'Max Stage'}                       = $min_val;
        $report{body}{$station}{min}{$key}{'Max Stage Time'}                  = $min_str_tim;
      } 
       # print $io "$site , $reftab , $max_stage_rating_release , $max_stage_rating, $max_val , $max_str_tim\n";

      #Prt('-P',"max_val [$max_val] max_tim [$max_tim]\n");
    } # end If Phase
  } # end ratings loop

  
  
  #foreach my $record ( 0 ..  $#rows ){
   # my $site = $rows[$record]->{station};
=skip   
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
    
    
    #Prt('-S',"site [$site]\n [".HashDump(\%{$rows[$record]})."]");
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

    my $job = qq(hycsv.exe "\@$paramfile");
    
    PrintAndRun( '-RLS',"HYFILER DELETE $site T0 /quiet",0,1,$repfile);
    
    try {
      PrintAndRun( '-PRLS',$job,0,1,$repfile) ;
      
    }
    catch {
      Prt('-P',"*** Error returned by previous job step\n");
    };
    
    unlink( @junkfiles);
    
    if ( -e $hydsys_err ){
      open my $errf, "<", $hydsys_err;
          
      while ( my $line = <$errf>){
          print $rep $line."\n";
 =skip        
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
  =cut      
      }

      close ($errf);
      
    }
    #print $io "errors ".HashDump(\%{$errors{$site}});
  
    close ($rep);
  #}
=cut  

  print $io '</body></html>';
  close ($io);
  
  $dll->Close;
 
  writeHTML(\%report);
 
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

sub writeHtml {
  my %rep = {};

  my $report_title  = $rep{title};
  my $report_body   = $rep{body};

  my $report_body = createHtmlTableFromHashRef($report_body);

  my $title   = qq{<title>$report_title</title>};
  my $body    = qq{<body>$report_body</body>};

  $html =~ s{ \{\{title\}\} }{ $title }; 
  $html =~ s{ \{\{body\}\} }{ $body }; 

  return $html;
}

sub createHtmlTableFromHashRef{
  my @names = qw(NAME AGE SEX HOMEPAGE);
  my @data  = [@names, 'KEY'];

  my %reporthash = %{};
  for my $k (keys %$report) {
      my @t = @{$data->{$k}}{@names};
      $t[-1] = qq{<a href="$t[-1]">$t[-1]</a>};        
      push @data, [@t, $k]
  }        

 return $htmlTable;
}

1; # End of importer
