#!/usr/bin/perl
# Pull EAP users from ElasticSearch
#
# @author: Ryan Kruse
# @date: 05/03/2013

use strict;
use JSON -support_by_pp;
use LWP;
use LWP::Simple;
use Getopt::Long;
use Data::Dumper;
use Noesis::Reporting;

my $browser = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
$browser->cookie_jar( {} );

#create_eap_user_sql();
get_eap_locations();

# Get the EAP locations from their user profile and associated company
sub get_eap_locations()
{
	my $companyLocations = get_company_locations();

	my $searchUrl     = 'http://www.noesisenergy.com:9200/userpublicprofiles/_search';
	my $searchPayload = '{
   "from":0,
   "size":9999999,
   "fields" : [ "Username", "Email", "Companies.Location", "FirstName", "LastName" ],
   "query":{
      "query_string":{
         "query":"EAPMember:true"
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

	my @report = ();
	foreach my $hit ( @{ $searchResultsJson->{hits}->{hits} } )
	{
		my $fields = $hit->{'fields'};
		if ($fields)
		{
			my $row      = {};
			my $username = $fields->{'Username'};
			$row->{'Username'} = $username;
			$row->{'Name'}     = $fields->{'FirstName'} . ' ' . $fields->{'LastName'};
			$row->{'E-mail'}   = $fields->{'Email'};
			$row->{'Profile Location'} = ( defined $fields->{'Companies.Location'} ) ? @{ $fields->{'Companies.Location'} }[0] : '';
			$row->{'Channel Location'} = ( defined $companyLocations->{$username} ) ? $companyLocations->{$username} : '';
			push( @report, $row );
		}
	}

	my $reportGenerator = Noesis::Reporting->new( data => \@report, file => 'eap-locations.csv', );
	$reportGenerator->build_csv_report();
}

# returns a hash of locations with the key being the username and the value being the location field
sub get_company_locations()
{
	my $searchUrl     = 'http://www.noesisenergy.com:9200/default_node_index/_search';
	my $searchPayload = '{
   "from":0,
   "size":9999999,
   "fields" : [ "field_sponsor_contact:name", "field_location" ],
   "query":{
      "query_string":{
         "query":"type:channel AND field_energy_advisor:true AND field_location:*"
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

	my $result = {};
	foreach my $hit ( @{ $searchResultsJson->{hits}->{hits} } )
	{
		my $fields = $hit->{'fields'};
		if ($fields)
		{
			my $username = $fields->{'field_sponsor_contact:name'};
			my $location = $fields->{'field_location'};
			$result->{$username} = $location;
		}
	}
	return $result;
}

# create SQL script for setting the EAP users up in Drupal
sub create_eap_user_sql()
{
	my $searchUrl     = 'http://www.noesisenergy.com:9200/userpublicprofiles/_search';
	my $searchPayload = '{
   "from":0,
   "size":9999999,
   "fields" : [ "Username" ],
   "query":{
      "query_string":{
         "query":"EAPMember:true"
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

	foreach my $hit ( @{ $searchResultsJson->{hits}->{hits} } )
	{
		my $nodeId = $hit->{'_id'};
		my $fields = $hit->{'fields'};
		if ($fields)
		{
			my $username = $fields->{'Username'};
			printf(
"INSERT INTO field_data_field_eap (entity_type, bundle, deleted, entity_id, revision_id, language, delta, field_eap_value) SELECT 'user', 'user', 0, u.uid, u.uid, 'und', 0, 1 FROM users u WHERE u.name = '%s';\n",
				$username );
			printf(
"INSERT INTO field_revision_field_eap (entity_type, bundle, deleted, entity_id, revision_id, language, delta, field_eap_value) SELECT 'user', 'user', 0, u.uid, u.uid, 'und', 0, 1 FROM users u WHERE u.name = '%s';\n",
				$username );
		}
	}
}

