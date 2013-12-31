#!/usr/bin/perl
#
#
# @author: Ryan Kruse
# @date: 11/8/2012

use strict;
use JSON -support_by_pp;
use LWP;
use Data::Dumper;
use Getopt::Long;
use List::Util 'max';
use Noesis::Profiles;
use Noesis::Reporting;
use DateTime::Format::Strptime;
use DateTime;
use Date::Parse;

my $outputFile;
my $start;
my $end;

my $appServer           = 'https://msapplication1.noesisenergy.com';
my $elasticSearchServer = 'http://www.noesisenergy.com:9200';
my $browser             = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );

get_options();
my @report = build_report_data();
my $reportGenerator = Noesis::Reporting->new( data => \@report, file => $outputFile, );
if ( $outputFile =~ /\.xlsx?/i )
{
	$reportGenerator->build_excel_doc();
}
else
{
	$reportGenerator->build_csv_report();
}

sub build_report_data()
{
	my @report;

	use DateTime::Format::Strptime;

	my $parser = DateTime::Format::Strptime->new(
		pattern  => '%Y-%m',
		on_error => 'croak',
	);

	my $startDate = str2time( $parser->parse_datetime($start) );
	my $endDate   = str2time( $parser->parse_datetime($end) );

	my $dateFilter = '';

	my $searchUrl     = $elasticSearchServer . '/private_node_index/_search';
	my $searchPayload = '{
   "from":0,
   "size":999999,
   "sort":[
      {
         "created":"desc"
      }
   ],
   "filter":{
      "range":{
         "created":{
            "from":"' . $startDate . '",
            "to":"' . $endDate . '",
            "include_lower":true,
            "include_upper":false
         }
      }
   }
}';

	my $searchRequest = HTTP::Request->new( 'POST', $searchUrl );
	$searchRequest->header( 'Content-Type' => 'application/json' );
	$searchRequest->content($searchPayload);

	my $response          = $browser->request($searchRequest);
	my $json              = new JSON;
	my $searchResultsJson =
	  $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode( $response->content );
	my $usernames     = get_unique_users($searchResultsJson);
	my $profileHelper = new Noesis::Profiles( appServer => $appServer );
	my $userProfiles  = $profileHelper->get_user_profiles($usernames);

	foreach my $hit ( @{ $searchResultsJson->{hits}->{hits} } )
	{
		my $node = $hit->{_source};

		my $row = {};

		$row->{date}  = localtime( $node->{created} );
		$row->{title} = $node->{title};
		push( @report, $row );
	}
	return @report;
}

# returns an array of unique userids
sub get_unique_users()
{
	my $searchResultsJson = shift;
	my $usernames         = {};
	foreach my $hit ( @{ $searchResultsJson->{hits}->{hits} } )
	{
		my $node = $hit->{_source};
		my $body = get_json_body($node); 
		use Data::Dumper;
		print Dumper($body);
	}
	return $usernames;
}

# gets the body of a node assuming a JSON payload, and turns it into an object
sub get_json_body
{
	my $node = shift;

	my $body = $node->{'body:value'};
	$body =~ s/<\/?p>//g;
	$body =~ s/<a\s+.+?<\/a>//g;
	print $body."\n";

	my $json     = new JSON;
	my $jsonBody = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($body);
	return $jsonBody;
}

sub get_options()
{
	my $help;
	GetOptions(
		"output=s" => \$outputFile,
		"start=s"  => \$start,
		"end=s"    => \$end,
		"h"        => \$help,
		"help"     => \$help,
	);

	if ( $help || !$end || !$start )
	{
		usage();
	}
}

sub usage()
{
	print "-h             - prints this help\n";
	print
	  "-output=<file> - (optional) the filename to output to. If it ends in xls, the file will be an Excel doc, else you'll get a CSV\n";
	print "-start=<date>  - (required) the year and month to start. Use YYYY-MM format, like 2012-12\n";
	print "-end=<date>  - (required) the year and month to end. Use YYYY-MM format, like 2012-12\n";
	exit;
}

