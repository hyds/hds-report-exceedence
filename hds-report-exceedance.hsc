=setup

[Configuration]
ListFileExtension = HTM

[Window]
Name = HAS
Head = Report exceedances


[Labels]
SITELIST    = END   20   4 #MESS(SYS.COMMON.SITELIST)
OUT         = END   +0  +1 Report Output

[Fields] 
SITELIST    = 21   4 INPUT   CHAR       30  0  TRUE   0.0 0.0 '0                             ' STN
OUT         = +0  +1 INPUT   CHAR       10  0  FALSE   FALSE  0.0 0.0 '#PRINT(P           )'

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

#Hydrological Data Services 
use local::lib "$Bin/HDS/";

#Hydstra modules
use HydDLLp;

#Hydstra libraries
require 'hydlib.pl';
require 'hydtim.pl';

#Globals
my $prt_fail = '-X';
my $level_varnum = '100.00';
my ($dll,$use_hydbutil,$now);
my (%ini,%temp,%errors,%report);
my (@junkfiles);

main: {
  
  
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
  my $site_list    = $ini{perl_parameters}{sitelist};  
  my $htmlfile    = $ini{perl_parameters}{out};  
  my $html_template = $inipath.'\\hds\\html\\email.html';
  my $html = read_file( $html_template );
  $report{html} = $html;
  $report{htmlfile} = $htmlfile;
  $report{'title'} = $script;
  
  $now = NowString();
  my $nowdat = substr ($now,0,8); #YYYYMMDDHHIIEE to YYYYMMDD for default import date
  my $nowtim = substr ($now,8,4); #YYYYMMDDHHIIEE to HHII for default import time
  
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
    
    if (! $ratper->{return}->{rows}){
      $report{footer}{'No rateper'}{$site}++;
      Prt('-S'," - No ratings for [$site]\n");
      next;
    }
    
    my @ratings;
    try {
      @ratings = @{$ratper->{return}->{rows}};
    }
    catch {
      $report{footer}{'Rateper array problem'}{$site}++;
      Prt('-S'," - Rateper array problem [$site]\n");
      next;
    };
    
    if (!@ratings){
      $report{footer}{'No rating for site'}{$site}++;
      Prt('-S'," - No ratings for [$site]\n");
      next;
    }
    
    #if latest RATEPER is ticked then start at the latest rating 
    my $rating = $#ratings; #($start_rating eq 'true')? $#ratings : 0;
    checkRating({site=>$site,rating=>$rating,ratings=>$ratper->{return}->{rows}});
    
    #foreach my $rating ( 0 ..  $#ratings ) {
    #   checkRating({ratings=>\@ratings,rating=>$rating});
    #} # end ratings loop
  }# end site loop
  $dll->Close;
  writeHTML(\%report);
}  # end main

sub checkRating {
  my $rat = shift;
  my %rating_config = %{$rat};
  
  my $rating          = $rating_config{rating};
  my $site            = $rating_config{site};
  my @ratings         = @{$rating_config{ratings}};
  
  # Start/End timestamps for get_ts_values
  print "Checking site ratings [$site] - $rating/$#ratings \n";
  next if ( $ratings[$rating]->{phase} eq 'true');      #assume that we don't want the phased rating as the start point because we check for phases below
  
  my ( $edate, $etime, $end_time, $sdate, $stime, $start_time );
  my $refstn = $ratings[$rating]->{refstn};
  my $reftab = $ratings[$rating]->{reftab};
  
  if ( $rating == $#ratings ) {
    $end_time = $now;                                   #assume that the rating is still valid today; as it is the last rating no phases in future
  }
  else{                                                 #Check forward for phased ratings.  
    for ( my $i=$rating+1; $i <= $#ratings; $i++ ) {
      print " - phased forward [$i/$#ratings]\r";
      if( $ratings[$i]->{phase} eq 'true' ){
        next;
      }
      elsif( $ratings[$i]->{phase} eq 'false' ){
        $edate = $ratings[$i]->{sdate};
        $etime = $ratings[$i]->{stime};
        my ($ehhmm,$ess) = split('\.',$etime);
        $end_time = $edate.sprintf("%04d",$ehhmm).sprintf("%02d",$ess);
        $end_time = ReltoStr( StrtoRel($end_time)-1 );  #yyyymmddhhiiee minus a minute so as not to overlap with the next rating
        last;
      }
    }
  } # End forward check phase ratings
                                                        #Set them now, and then reset if we find a phased rating before the rating sdate/stime
  $sdate = $ratings[$rating]->{sdate};
  $stime = $ratings[$rating]->{stime};
  
  if ( $rating != 0){                                   #Check backward for phased ratings if not the first rating
    for ( my $j=$rating-1; $j >= 0; $j--) {
      print " - phased backward [$j/$#ratings]\r";
      if( $ratings[$j]->{phase} eq 'true' ){
        $sdate = $ratings[$j]->{sdate};                 #just keep resetting 
        $stime = $ratings[$j]->{stime};
        next;
      }
      elsif( $ratings[$j]->{phase} eq 'false' ){
        last;
      }
    }
  } # End backward check phase ratings
    
  my ($hhmm,$ss) = split('\.',$stime);
  $start_time = $sdate.sprintf("%04d",$hhmm).sprintf("%02d",$ss);
    
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
  
  my ( $max_val, $max_tim, $max_str_tim );
  try {
    $max_val = $tscall->{return}->{traces}[0]->{trace}[0]->{v};
    $max_tim = $tscall->{return}->{traces}[0]->{trace}[0]->{t};
    $max_str_tim = StrtoPrm($max_tim);
    if ( $max_val > $max_stage_rating  ){
      my $key = qq{$site$reftab$max_stage_rating_release$max_stage_rating};
      $key =~ s{\.}{}g;
      #$report{body}{$site}{max}{$key}{'Station'}                         = $site;
      $report{body}{$site}{max}{$key}{'Ref Table'}                       = $reftab;
      $report{body}{$site}{max}{$key}{'Release'}                         = $max_stage_rating_release;
      $report{body}{$site}{max}{$key}{'Max Rating'}                      = $max_stage_rating;
      $report{body}{$site}{max}{$key}{'Max Stage'}                       = $max_val;
      $report{body}{$site}{max}{$key}{'Max Time'}                        = $max_str_tim;
    }
  }
  catch {
    $report{footer}{'No max ts value'}{$site}++;
    Prt('-S'," - No max ts trace value [$site]\n");
  };
        
  
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
  
  my ( $min_val, $min_tim, $min_str_tim);
  try{  
    $min_val = $tsmincall->{return}->{traces}[0]->{trace}[0]->{v};
    $min_tim = $tsmincall->{return}->{traces}[0]->{trace}[0]->{t};
    $min_str_tim = StrtoPrm($min_tim);
    if ( $min_val < $min_stage_rating && $min_val > 0){
      my $key = qq{$site$reftab$max_stage_rating_release$min_stage_rating};
      $key =~ s{\.}{}g;
      #$report{body}{$site}{min}{$key}{'Station'}                         = $site;
      $report{body}{$site}{min}{$key}{'Ref Table'}                       = $reftab;
      $report{body}{$site}{min}{$key}{'Release'}                         = $max_stage_rating_release;
      $report{body}{$site}{min}{$key}{'Min Rating'}                      = $min_stage_rating;
      $report{body}{$site}{min}{$key}{'Min Stage'}                       = $min_val;
      $report{body}{$site}{min}{$key}{'Min Time'}                        = $min_str_tim;
    } 
  }
  catch {
    $report{footer}{'No min ts value'}{$site}++;
    Prt('-S'," - No min ts trace value [$site]\n");
  };
  
}

sub writeHTML {
  my $report_hash = shift;
  my %rep = %{$report_hash};
  
  my $html          = $rep{html};
  my $report_title  = $rep{title};
  my $htmlfile      = $rep{htmlfile};
  my $rep_body      = $rep{body};
  my $rep_footer    = $rep{footer};
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
      $report_footer .= "-- End --"; 
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
  
  #open my $ht, '>', $htmlf;
  #print $ht $htm;
  OpenFile(*hREPORT,$htmlf,">");
  #OpenFile(*hOUTPUT,HyconfigValue('JUNKPATH').'exceedances.txt',">");
  #close ($ht);
  Prt('-R',$htm);
  close (hREPORT);
  return 1;
}

sub createHtmlBodyFromHashRef{
  my $report_body = shift;
  my %body = %{$report_body};
  my $html = '';  
    
  foreach my $site (keys %body) {
    my $head = qq{<caption colspan="5">Site: $site</caption>};
    my $html_table = '<table border="1">';
    $html_table.= $head;
      
    my %repbody = %{$body{$site}};
    foreach my $section ( sort keys %repbody) {
      my $ucfirt_section = ucfirst($section);
      
      my %rows = %{$repbody{$section}};
      
      my @headers;
      my %headers;

      #uniquify headers
      foreach my $record ( keys %rows) {
        my %recd = %{$rows{$record}};
        foreach my $headder (keys %recd){
          $headers{$headder}++;
        }
      }
      
      #get orderly array
      foreach my $h ( sort keys %headers){
        push (@headers,$h);
      }
      
      my $colspan = $#headers+1;
      
      my $sub = qq{<tr><td colspan="$colspan"><div class="tabhead">$ucfirt_section Rating Exceedance</div></td></tr>};
      $html_table .= $sub;
      
      my $tr_head = qq{<tr>};
      foreach my $head ( @headers ){
        $tr_head .= qq{<td>$head</td>}
      }
      $tr_head .= qq{</tr>};
      $html_table .= $tr_head;
      
      foreach my $record (keys %rows) {
        my %recds = %{$rows{$record}};
        my $tr_body = qq{<tr>};
        foreach my $head ( @headers ){
          my $val = $recds{$head};
          $tr_body .= qq{<td>$val</td>};  
        }
        $tr_body .= qq{</tr>};
        $html_table .= $tr_body;
      }
    }
    $html_table .= qq{</table><br>};
    $html .= $html_table;
  }
 return $html;
}

sub createHtmlFooterFromHashRef{
  my $report_footer = shift;
  my %footer = %{$report_footer};
  my $html = '';  

  my $header = qq{<div class="footer">Notes:</div>};
  my $table = '<table border="1">';
  $html .= $header;
  my @headers; 
  foreach my $h ( sort keys %footer){
    push (@headers,$h);
  }
      
  foreach my $head ( @headers ){
    my $sub = qq{<tr><td><b>$head</b></td>};
    $table .= $sub;
    my $tr_footer = qq{<td>};
    foreach my $site ( sort keys %{ $footer{$head} }) {
        $tr_footer .= qq{$site, };  
    }
    $tr_footer .= qq{</td>};
    $table .= qq{$tr_footer</tr>};
  }
  $table .= qq{</table>};
  $html .= $table;
  return $html;
}

1; # End of exceedence report
