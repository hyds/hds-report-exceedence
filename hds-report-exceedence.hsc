=setup

[Configuration]
ListFileExtension = TXT

[Window]
Name = HAS
Head = Report Exceedences


[Labels]
SITELIST    = END   20   4 #MESS(SYS.COMMON.SITELIST)
HTML        = END   +0  +1 HTML Output (for email)
OUT         = END   +0  +1 Report Output

[Fields] 
SITELIST    = 21   4 INPUT   CHAR       30  0  TRUE   0.0 0.0 '0                             ' STN
HTML        = +0  +1 INPUT   CHAR       40  0  FALSE   FALSE  0.0 0.0 '&hyd-junkpath.email.html' $OP
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
  IniHash($ARGV[0],\%ini, 0, 0);
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
  my $htmlfile    = $ini{perl_parameters}{html};  
  my $html_template = $inipath.'\\hds\\html\\email.html';
  my $html = read_file( $html_template );

  $report{html} = $html;
  $report{htmlfile} = $htmlfile;
  #my $htmlfile    = $junk."output.txt";  
  my $nowdat = substr (NowString(),0,8); #YYYYMMDDHHIIEE to YYYYMMDD for default import date
  my $nowtim = substr (NowString(),8,4); #YYYYMMDDHHIIEE to HHII for default import time
  
  $report{'title'} = "Hello Title";
  
  my $hydsys_err = $temp.'HYDSYS.ERR';
  #Prt('-P',"INI [".HashDump(\%ini)."[$htmlfile]\n");
  
  try{
    $dll=HydDllp->New();
  }
  catch{
    Prt($prt_fail,NowStr().": *** ERROR An error occured while initialising HYDDLLP\n");
    $use_hydbutil=1;
    
  };
  #Prt($prt_fail,NowStr().": docpath [$docpath] import_dir [$import_dir] photo_types []\n"); #.Dumper(%photo_types)."]\n");

   
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
  my $repfile = "C:\\temp\\reprilfeexceed.txt";
  
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

      my %ratepoints = %{$ratepts->{return}->{rows}->{$site}->{'100.00'}->{141}->{$reftab}};
      #Prt('-P',"RATEPOINTS [".HashDump(\%ratepoints)."]");

      my $count = 0;
      my $releases_count = keys %ratepoints;
      
      my $latest_release;
      
      foreach my $release (sort {$a <=> $b} keys %ratepoints ) {
          if ($count == $releases_count-1){
              $latest_release = $release;
          }
          $count++;
      }
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

      my $min_stage_rating = $rate[0]->{stage}; 
      my $min_stage_rating_release = $rate[0]->{release};
      my $min_stage_rating_table = $rate[0]->{table};
      my $varfrom = $rate[0]->{varfrom};
      my $varto = $rate[0]->{varto};
      
      my $max_stage_rating = $rate[$#rate]->{stage};
      my $max_stage_rating_release = $rate[$#rate]->{release};
      my $max_stage_rating_table = $rate[$#rate]->{table};
     
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
        my $key = qq{$site$reftab$max_stage_rating_release$max_stage_rating};
        $key =~ s{\.}{}g;
        $report{body}{$site}{max}{$key}{'Station'}                         = $site;
        $report{body}{$site}{max}{$key}{'Ref Table'}                       = $reftab;
        $report{body}{$site}{max}{$key}{'Release'}                         = $max_stage_rating_release;
        $report{body}{$site}{max}{$key}{'Stage Max Rating'}                = $max_stage_rating;
        $report{body}{$site}{max}{$key}{'Max Stage'}                       = $max_val;
        $report{body}{$site}{max}{$key}{'Max Stage Time'}                  = $max_str_tim;
      }
      elsif ( $min_val < $min_stage_rating){
        #print $io "$site , $reftab , $max_stage_rating_release , $min_stage_rating, $min_val , $min_str_tim\n";
        my $key = qq{$site$reftab$max_stage_rating_release$min_stage_rating};
        $key =~ s{\.}{}g;
        $report{body}{$site}{min}{$key}{'Station'}                         = $site;
        $report{body}{$site}{min}{$key}{'Ref Table'}                       = $reftab;
        $report{body}{$site}{min}{$key}{'Release'}                         = $max_stage_rating_release;
        $report{body}{$site}{min}{$key}{'Stage Max Rating'}                = $min_stage_rating;
        $report{body}{$site}{min}{$key}{'Max Stage'}                       = $min_val;
        $report{body}{$site}{min}{$key}{'Max Stage Time'}                  = $min_str_tim;
      } 
    } # end If Phase
  } # end ratings loop
  
  $dll->Close;
 
  writeHTML(\%report);
 
}

sub writeHTML {
  my $report_hash = shift;
  my %rep = %{$report_hash};
  #Prt('-P',"rep [".HashDump(\%rep)."]");
  
  my $html          = $rep{html};
  my $report_title  = $rep{title};
  my $htmlfile    = $rep{htmlfile};
  my $report_body   = $rep{body};
  my $report_body = createHtmlTableFromHashRef($report_body);

  my $title   = qq{<title>$report_title</title>};
  my $body    = qq{<body>$report_body</body>};

  $html =~ s{{{title}}}{$title}; 
  $html =~ s{{{body}}}{$body}; 
  unlink($htmlfile);
  open my $html_out, '>', $htmlfile;
  print $html_out $html;
  close ($html_out);
  return 1;
}

sub createHtmlTableFromHashRef{
  my $report_body = shift;
  my %body = %{$report_body};
  my $html = '';  
  
  my $html_table = '<table border="1">';
  foreach my $site (keys %body) {
    my $head = qq{<caption>Site: $site</caption>};
    $html_table.= $head;
      
    my %repbody = %{$body{$site}};
    foreach my $section ( sort keys %repbody) {
      my $sub = qq{<tr><td><b>Rating $section Exceedence</b><br></td></tr>};
      #$html.= $sub;
      $html_table .= $sub;
      
      my %rows = %{$repbody{$section}};
      
      my @headers;
      my %headers;
      #Prt('-S',"repbody [".HashDump(\%repbody)."]");
      #Prt('-S',"rows [".HashDump(\%rows)."]");
      #Prt('-P',"html [$html]");
      
      #uniquify headers
      foreach my $record (keys %rows) {
        my %recd = %{$rows{$record}};
        #Prt('-P',"rec [".HashDump(\%recd)."]");
        foreach my $headder (keys %recd){
          $headers{$headder}++;
        }
      }
      
      #get orderly array
      foreach my $h ( keys %headers){
        push (@headers,$h);
      }
      
      my $tr_head = qq{<tr>};
      foreach my $head ( @headers ){
        $tr_head .= qq{<td>$head</td>}
      }
      $tr_head .= qq{</tr>};
      $html_table .= $tr_head;
      
      foreach my $record (keys %rows) {
        my %recds = %{$rows{$record}};
        my $tr_body = qq{<tr>};
        #Prt('-S',HashDump(\%recds));
        foreach my $head ( @headers ){
          my $val = $recds{$head};
          $tr_body .= qq{<td>$val</td>};  
          #Prt('-P',"head [$head], val [$val]\n");
        }
        $tr_body .= qq{</tr>};
        $html_table .= $tr_body;
      }
    }
  }  
  $html_table .= qq{</table><br><br>};
  $html .= $html_table;
 return $html;
}

1; # End of importer
