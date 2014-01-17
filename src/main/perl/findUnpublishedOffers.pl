#!/usr/bin/perl
#
# Measures how long it takes to get the provided page
use Getopt::Long;
use Time::HiRes;
use Benchmark qw(:all);
use Benchmark ':hireswallclock';
use LWP;
use HTTP::Cookies;
use Data::Dumper;
use JSON;
use UUID::Generator::PurePerl;
use Statistics::Basic qw(:all);
use List::Util qw( min max );

my $url;

load_options();
print "Finding unplished offers on $url ...\n";

my $browser = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
my $json    = new JSON;

# Build up all of the existing offers
my $request = HTTP::Request->new( 'POST', "$url/default_node_index/_search" );
$request->header( 'Content-Type' => 'application/json' );
$request->content(
	'{
   "from":0,
   "size":9999,
   "query":{
      "query_string":{
         "query":"type:adCampaign AND status:1"
      }
   },
   "fields": ["field_related_offers:nid"]
}'
);
my $response = $browser->request($request);
my $offerIds = $json->decode( $response->content );

my $offersAdCampaignMap = {};
my @offerIdArray        = ();
foreach my $hit ( @{ $offerIds->{hits}->{hits} } ) {
	my $fields = $hit->{fields};
	if ( $fields->{'field_related_offers:nid'} ) {
		my @nodeIds = @{ $fields->{'field_related_offers:nid'} };
		foreach my $id (@nodeIds) {
			push( @offerIdArray, $id );
			if ( !$offersAdCampaignMap->{$id} ) {
				$offersAdCampaignMap->{$id} = ();
			}
			push( @{ $offersAdCampaignMap->{$id} }, $hit->{'_id'} );
		}
	}
}

# Now find any unpublished nodes
$request = HTTP::Request->new( 'POST', "$url/default_node_index/_search" );
$request->header( 'Content-Type' => 'application/json' );
$request->content( '
	{
   "from":0,
   "size":9999,
   "query":{
      "query_string":{
         "query":"status:0"
      }
   },
   "filter": {
       "terms": {
          "nid": ['.join(',', @offerIdArray).']
       }
   }
}
'
);
$response = $browser->request($request);
my $unpublishedOffers = $json->decode( $response->content );

print "Unpublished nodes that are in an AdCampaign...\n";
foreach my $hit ( @{ $unpublishedOffers->{hits}->{hits} } ) {
	my $offer = $hit->{_source};
	my $nid = $offer->{'nid'};
	my $title = $offer->{'title'};
	print 'NodeId: '.$nid.' ("'.$title.'") in AdCampaign(s): '.join(', ',@{$offersAdCampaignMap->{$nid}})."\n";
}

# load all of the startup options
sub load_options() {
	GetOptions( "url=s" => \$url, );

	die("A 'url' field of the elastic search index is required") if ( !$url );
}
