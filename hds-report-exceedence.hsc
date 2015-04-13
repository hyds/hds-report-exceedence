=setup

[Configuration]
ListFileExtension = TXT

[Window]
Name = HAS
Head = Report exceedances


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

 This HYSCRIPT reports on RATINGS exceedances capturing max val for the ratings date and time 
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
  my $site_list    = $ini{perl_parameters}{sitelist};  
  my $htmlfile    = $ini{perl_parameters}{html};  
  my $html_template = $inipath.'\\hds\\html\\email.html';
  my $html = read_file( $html_template );
  $report{html} = $html;
  $report{htmlfile} = $htmlfile;
  #my $htmlfile    = $junk."output.txt";  
  my $nowdat = substr (NowString(),0,8); #YYYYMMDDHHIIEE to YYYYMMDD for default import date
  my $nowtim = substr (NowString(),8,4); #YYYYMMDDHHIIEE to HHII for default import time
  
  $report{'title'} = $script;
  
  my $hydsys_err = $temp.'HYDSYS.ERR';
  #Prt('-P',"INI [".HashDump(\%ini)."[$htmlfile]\n");
  
  try{
    $dll=HydDllp->New();
  }
  catch{
    Prt($prt_fail,NowStr().": *** ERROR An error occured while initialising HYDDLLP\n");
    $use_hydbutil=1;
    
  };
  
  my $sitelistref = $dll->JSonCall({ 'function'=> 'get_site_list', 
      'version'=> 1,
      'params'=> {
        'site_list'=> $site_list
      } 
  });
  
  my @sites = @{$sitelistref->{return}->{sites}};
  if ( !@sites ) {
    Prt('-S', "$script The site list does not resolve to any valid sites" );
    exit;
  }
  
  foreach my $site ( @sites ){
    Prt('-S',"Checking site [$site]\n");
    my $ratper = $dll->JSonCall({'function' => 'get_db_info',
      'version' => 3,
      'params' => {
          'table_name'  => 'rateper',
          'field_list'  => ['sdate','stime','phase','reftab','refstn'],
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

    my @ratings;
    try {
      @ratings = @{$ratper->{return}->{rows}};
    }
    catch {
      $report{footer}{'No rateper'}{$site}++;
      Prt('-S'," - No ratings for [$site]\n");
      next;
    };
    
    #treat phased changes
    
    
    foreach my $rating ( 0 ..  $#ratings ) {
      print "checking rating [$rating] \n";
        my $next_rating;
    
      #if ( $ratings[$rating]->{phase} eq 'false' ){
        #print "no phased rating\n";  
        #my $next_rating = $rating + 1;
        if( $rating + 1 >  $#ratings ){
          #Prt('-P',"last rating [$rating] out of [$#ratings]");
          $next_rating = -1;
        }
        elsif ( $ratings[$rating+1]->{phase} eq 'false' ){
          print "no phased rating\n";  
          $next_rating = $rating + 1;
        }
        elsif( $ratings[$rating+1]->{phase} eq 'true' ){
          my $phase_rating_count = 1;
          $next_rating = 'phased';
=skip LOOK FORWARD FOR NEXT NON-PHASE CHANGE          
          foreach my $rat ( $rating + 1 ..  $#ratings ) {
            #Prt('-P',"phased rat number [$#ratings]\n");
            if ( $rat > $#ratings ) {
              $next_rating = -1;
            }
            else{
              if( $ratings[$rat]->{phase} eq 'true' ){
                print "Phased rating [$phase_rating_count]\n";  
                $next_rating = $rat + 1;
                $phase_rating_count++;
                next;
              }
            }
          }
=cut          
        }
        
        my $refstn = $ratings[$rating]->{refstn};
        my $reftab = $ratings[$rating]->{reftab};
        my $sdate = $ratings[$rating]->{sdate};
        my $stime = $ratings[$rating]->{stime};
        
        my ($hhmm,$ss) = split('\.',$stime);
        my $start_time = $sdate.sprintf("%04d",$hhmm).sprintf("%02d",$ss);
        my $phased_time = ReltoStr( StrtoRel($start_time)-10080 ) ;
        $start_time = ( $next_rating eq 'phased')?  $phased_time: $start_time; # 1440 min a day = 1440 * 7 for a week = 10080
        
        #if it's the last rating then take now as the time for max min.
        #if it's a phased rating do I need to check agasint each of the ratings, not just get the max min within the one rating.
        #Str times are strings of the form 'yyyymmddhhiiee'

        my $edate = $ratings[$next_rating]->{sdate};
        my $etime = $ratings[$next_rating]->{stime};
        
        my ($ehhmm,$ess) = split('\.',$etime);
        my $end_time = $edate.sprintf("%04d",$ehhmm).sprintf("%02d",$ess);
        my $adjusted_end = ReltoStr(StrtoRel($end_time)-1);
        my $end_time = ( $next_rating == -1 )? NowString() : $adjusted_end; #yyyymmddhhiiee minus a minute so as not to overlap with the next rating
        
        my $ratepts = $dll->JSonCall({'function' => 'get_db_info',
            'version' => 3,
            'params' => {
                'table_name'  => 'ratepts',
                'sitelist_filter'=>$refstn,
                'return_type' => 'hash',
                'filter_values'=> {
                  'station'=> $refstn,
                  'table'=>$reftab,
                  'varfrom'=> 100,
                  'varto'=> 141,
                },

            },
        }, 1000000);

        my %ratepoints;
        try {
          %ratepoints = %{$ratepts->{return}->{rows}->{$refstn}->{'100.00'}->{141}->{$reftab}};
        }
        catch {
          $report{footer}{'No ratepts'}{$refstn}++;
          Prt('-S'," - No ratepts for [$site]\n");
          next;
        };
    
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
                'sitelist_filter'=>$refstn,
                'return_type' => 'array',
                'filter_values'=> {
                  'station'=> $refstn,
                  'table'=>$reftab,
                  'varfrom'=> 100,
                  'varto'=> 141,
                  'release'=>$latest_release,
                },

            },
        }, 1000000);
        
        my @rate;
        try {
          @rate = @{$ratept->{return}->{rows}};
        }
        catch {
          $report{footer}{'No ratept'}{$refstn}++;
          Prt('-S'," - No ratept for [$site]\n");
          next;
        };
                
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
            'site_list'=> $site, 
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
        
        my $max_val;
        try {
          $max_val = $tscall->{return}->{traces}[0]->{trace}[0]->{v};
        }
        catch {
          $report{footer}{'No ts trace'}{$site}++;
          Prt('-S'," - No ts trace [$site]\n");
          next;
        };
        
        my $max_tim = $tscall->{return}->{traces}[0]->{trace}[0]->{t};
        
        my $max_str_tim = StrtoPrm($max_tim);
        
        my $tsmincall = $dll->JSonCall({ 'function'=> 'get_ts_traces', 
          'version'=> 2,
          'params'=> {
            'site_list'=> $site, 
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
          #$report{body}{$site}{max}{$key}{'Station'}                         = $site;
          $report{body}{$site}{max}{$key}{'Ref Table'}                       = $reftab;
          $report{body}{$site}{max}{$key}{'Release'}                         = $max_stage_rating_release;
          $report{body}{$site}{max}{$key}{'Max Rating'}                      = $max_stage_rating;
          $report{body}{$site}{max}{$key}{'Max Stage'}                       = $max_val;
          $report{body}{$site}{max}{$key}{'Max Time'}                        = $max_str_tim;
        }
        elsif ( $min_val < $min_stage_rating && $min_val > 0){
          #print $io "$site , $reftab , $max_stage_rating_release , $min_stage_rating, $min_val , $min_str_tim\n";
          my $key = qq{$site$reftab$max_stage_rating_release$min_stage_rating};
          $key =~ s{\.}{}g;
          #$report{body}{$site}{min}{$key}{'Station'}                         = $site;
          $report{body}{$site}{min}{$key}{'Ref Table'}                       = $reftab;
          $report{body}{$site}{min}{$key}{'Release'}                         = $max_stage_rating_release;
          $report{body}{$site}{min}{$key}{'Min Rating'}                      = $min_stage_rating;
          $report{body}{$site}{min}{$key}{'Min Stage'}                       = $min_val;
          $report{body}{$site}{min}{$key}{'Min Time'}                        = $min_str_tim;
        } 
      #} # end If Phase
    } # end ratings loop
  }# end site loop
  
  $dll->Close;
 
  writeHTML(\%report);
 
}

# Rating table 1
# 
# 2m 1/1/2000 
# 2.1m 2/1/2000 Rating Table 2 2.5m
# 
# Less than the start date of the next rating table
# If block boundary is at midnight
# 
# 



sub writeHTML {
  my $report_hash = shift;
  my %rep = %{$report_hash};
  #Prt('-P',"rep [".HashDump(\%rep)."]");
  
  my $html          = $rep{html};
  my $report_title  = $rep{title};
  my $htmlfile    = $rep{htmlfile};
  my $rep_body   = $rep{body};
  my $rep_footer   = $rep{footer};
  my $report_body; 
  my $report_footer; 
  my $body;
  my $footer;
  
  my $html_title   = qq{<title>$report_title</title>};
  my $rep_title = qq{<div class="title">Rating Exceedance Report</div>};
  $report_body .= $rep_title;
  my $date = NowStr();
  my $subtitle = qq{<div class="date">$date</div>};
  $report_body .= $subtitle;
  
  if (!$rep_body){
    $report_body = qq{<div class="noexceed">No Exceedances found</div>};
  }
  else{
    try {
      $report_body .= createHtmlBodyFromHashRef($rep_body);
    }
    catch{
      Prt('-R',"problem generating html body");
      exit;
    };
    
    try {
      $report_footer .= createHtmlFooterFromHashRef($rep_footer);
    }
    catch{
      $report_footer .= "no footer produced"; #Prt('-R',"problem generating html footer");
    }
  }
  $body    = qq{<body>$report_body</body>};
  $footer  = qq{<footer>$report_footer</footer>};
  $html =~ s{{{title}}}{$html_title}; 
  $html =~ s{{{body}}}{$body}; 
  $html =~ s{{{footer}}}{$footer}; 
  createHTML($htmlfile,$html);
  
  return 1;
}

sub createHTML{
  my $htmlf = shift; 
  my $htm = shift;
  
  #my $htm = $html_ref->{htm};
  unlink($htmlf);
  open my $ht, '>', $htmlf;
  print $ht $htm;
  close ($ht);
  return 1;
}

sub createHtmlBodyFromHashRef{
  my $report_body = shift;
  my %body = %{$report_body};
  my $html = '';  
    
  foreach my $site (keys %body) {
    my $head = qq{<caption colspan="6">Site: $site</caption>};
    my $html_table = '<table border="1">';
    $html_table.= $head;
      
    my %repbody = %{$body{$site}};
    foreach my $section ( sort keys %repbody) {
      my $ucfirt_section = ucfirst($section);
      my $sub = qq{<tr><td colspan="6"><b>$ucfirt_section Rating Exceedance</b><br></td></tr>};
      #$html.= $sub;
      $html_table .= $sub;
      
      my %rows = %{$repbody{$section}};
      
      my @headers;
      my %headers;
      #Prt('-S',"repbody [".HashDump(\%repbody)."]");
      #Prt('-S',"rows [".HashDump(\%rows)."]");
      #Prt('-P',"html [$html]");
      
      #uniquify headers
      foreach my $record ( keys %rows) {
        my %recd = %{$rows{$record}};
        #Prt('-P',"rec [".HashDump(\%recd)."]");
        foreach my $headder (keys %recd){
          $headers{$headder}++;
        }
      }
      
      #get orderly array
      foreach my $h ( sort keys %headers){
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
    $html_table .= qq{</table><br><br>};
    $html .= $html_table;
  }
 return $html;
}

sub createHtmlFooterFromHashRef{
  my $report_footer = shift;
  my %footer = %{$report_footer};
  my $html = '';  

  my $head = qq{<footer>Exceptions</footer>};
  my $table = '<table border="1">';
  $table .= $head;
  #get orderly array
  #$report{footer}{'No ts trace'}{$site}++;
  #$report{body}{$site}{max}{$key}{'Ref Table'}                       = $reftab;
  my @headers; 
  foreach my $h ( sort keys %footer){
    push (@headers,$h);
  }
      
  foreach my $head ( @headers ){
    my $sub = qq{<tr><td><b>$head</b></td></tr>};
    $html .= $sub;
    my $tr_footer = qq{<tr>};
    foreach my $site ( sort keys %{ $footer{$head} }) {
        $tr_footer .= qq{<td>$site</td>};  
    }
    $tr_footer .= qq{</tr>};
    $html .= $tr_footer;
  }
  return $html;
}

1; # End of importer
