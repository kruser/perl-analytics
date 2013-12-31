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

my $outputFile;
my $month;

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

	my $dateFilter = '';
	if ($month)
	{
		$dateFilter .= ' AND CreatedWhen:\"' . $month . '\"';
	}

	my $searchUrl     = $elasticSearchServer . '/notifications/_search';
	my $searchPayload = '{
   "from":0,
   "size":9999999,
   "sort":[
      {
         "CreatedWhen":"desc"
      },
      "_score"
   ],
   "query":{
      "query_string":{
         "query":"((Kind:Sponsor OR AdornmentsFlat.MarketingReferral:true)'
	  . $dateFilter
	  . ') AND NOT Recipients.DisplayName:\"050dfd70-fca2-450e-95d9-3a636b21b882\" AND NOT Recipients.DisplayName:\"f6c52441-f8f1-47e9-92b5-6c0feec28a2e\" AND NOT Recipients.DisplayName:\"21cfc3de-e58d-421e-8d02-83fec0d794a1\" AND NOT Recipients.DisplayName:\"e04b1d8d-2029-4241-a46a-db62dc71fa0a\" AND NOT Recipients.DisplayName:\"19b9eed8-4120-4158-8348-f33bce6876ee\" AND NOT Adornments.Entries.Value:\"*.noesis.com\""
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

	#print "Date|Referral Type|Sponsor|Sponsor Email|Sponsor Id|User|User Email|User ID|Content Title|Content URL\n";

	foreach my $hit ( @{ $searchResultsJson->{hits}->{hits} } )
	{
		my $notification    = $hit->{_source};
		my $sponsorUsername = get_recipient_of_notification($notification);
		my $sponsorProfile  = $userProfiles->{$sponsorUsername};

		if ( defined $sponsorProfile )
		{
			my $row = {};
			$row->{created}         = $notification->{CreatedWhen};
			$row->{notification}    = $notification->{Kind};
			$row->{sponsor}         = $sponsorProfile->{FirstName} . ' ' . $sponsorProfile->{LastName};
			$row->{sponsorEmail}    = $sponsorProfile->{Email};
			$row->{sponsorUsername} = $sponsorUsername;
			my $userId = get_adornment_value( 'userId', $notification->{Adornments}->{Entries} );
			if ($userId)
			{
				my $userProfile = $userProfiles->{$userId};
				$row->{lead}         = $userProfile->{FirstName} . ' ' . $userProfile->{LastName};
				$row->{leadEmail}    = $userProfile->{Email};
				$row->{leadUsername} = $userId;
			}
			else
			{
				$row->{lead}      = get_adornment_value( 'Name',  $notification->{Adornments}->{Entries} );
				$row->{leadEmail} = get_adornment_value( 'Email', $notification->{Adornments}->{Entries} );
				$row->{leadUsername} = 'unknown';
			}

			# one of these has the node title
			$row->{contentTitle} = get_adornment_value( 'contentTitle', $notification->{Adornments}->{Entries} );
			$row->{contentTitle} .= get_adornment_value( 'WebinarName', $notification->{Adornments}->{Entries} );

			my $contentId = get_adornment_value( 'contentId', $notification->{Adornments}->{Entries} );
			if ( !$contentId )
			{
				$contentId = get_adornment_value( 'ContentId', $notification->{Adornments}->{Entries} );
			}
			my $contentUrl = 'unknown';
			if ($contentId)
			{
				$contentUrl = 'http://www.noesisenergy.com/site/node/' . $contentId;
			}
			$row->{contentUrl} = $contentUrl;
			push( @report, $row );
		}
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
		my $notification = $hit->{_source};

		my $sponsorUsername = get_recipient_of_notification($notification);
		if ($sponsorUsername)
		{
			$usernames->{$sponsorUsername} = 1;
		}

		my $userId = get_adornment_value( 'userId', $notification->{Adornments}->{Entries} );
		if ($userId)
		{
			$usernames->{$userId} = 1;
		}
	}
	return $usernames;
}

sub get_recipient_of_notification()
{
	my $notification = shift;
	my $recepient    =
	  ( defined $notification->{Recipients}[0]->{Username} )
	  ? $notification->{Recipients}[0]->{Username}
	  : $notification->{Recipients}[0]->{DisplayName};
	return $recepient;
}

# get a given adornment given an array of them
sub get_adornment_value()
{
	my $adornmentKey = shift;
	my $adornments   = shift;

	for my $entry ( @{$adornments} )
	{
		if ( $entry->{Key} eq $adornmentKey )
		{
			return $entry->{'Value'};
		}
	}
}

sub get_options()
{
	my $help;
	GetOptions(
		"output=s" => \$outputFile,
		"month=s"  => \$month,
		"h"        => \$help,
		"help"     => \$help,
	);

	if ( $help )
	{
		usage();
	}
}

sub usage()
{
	print "-h             - prints this help\n";
	print
	  "-output=<file> - (optional) the filename to output to. If it ends in xls, the file will be an Excel doc, else you'll get a CSV\n";
	print
	  "-month=<date>  - (optional) the year and month to filter by. Use YYYY-MM format, like 2012-12. You can also just specify a year.\n";
	exit;
}

