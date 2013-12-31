#!/usr/bin/perl
#
# POSTS a typical Noesis Energy search against the provided URL and measures the speed of return
use Getopt::Long;
use Time::HiRes;
use Benchmark qw(:all);
use Benchmark ':hireswallclock';
use LWP;
use HTTP::Cookies;
use Data::Dumper;
use JSON;
use Statistics::Basic qw(:all);
use List::Util qw( min max );

my $url;
my $count     = 10;
my @intervals = ();
my $payload   =
'{"query":{"filtered":{"query":{"query_string":{"query":"*"}},"filter":{"and":{"filters":[{"or":{"filters":[{"not":{"fquery":{"query":{"query_string":{"query":"type:adCampaign OR type:incentive OR type:page OR type:page_simple OR type:product OR type:lighting_option OR type:marketo_form OR status:0"}}}}},{"fquery":{"query":{"query_string":{"query":"(field_state:ALL OR field_state:\'TX\') AND type:incentive"}}}}]}},{"or":{"filters":[{"geo_distance":{"field_point:latlon":[-97.7412885,30.369600599999995],"distance":75,"unit":"mi"}},{"missing":{"field":"field_point:latlon","existence":true,"null_value":true}}]}}]}}}},"from":0,"size":15,"sort":[{"sticky":{"order":"desc"}},{"last_comment_timestamp":{"order":"desc"}}],"facets":{"type":{"terms":{"field":"type","size":100}},"field_energy_advisor":{"terms":{"field":"field_energy_advisor","size":10}}}}';

load_options();
print "Testing $url $count times...\n";

my $browser = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
my $cookies = HTTP::Cookies->new();
$browser->cookie_jar($cookies);

for ( my $i = 0 ; $i < $count ; $i++ ) {
	run_search();
}
print 'Min: ' . min(@intervals) . " seconds\n";
print 'Max: ' . max(@intervals) . " seconds\n";
print 'Mean: ' . mean(@intervals) . " seconds\n";

print Dumper(@intervals);

sub run_search() {

	my $req = HTTP::Request->new( POST => $url );
	$req->content_type('application/json');
	$req->content($payload);

	my $start    = [Time::HiRes::gettimeofday];
	my $response = $browser->request($req);
	$elapsed = Time::HiRes::tv_interval( $start, [Time::HiRes::gettimeofday] );
	push( @intervals, $elapsed );
}

# load all of the startup options
sub load_options() {
	GetOptions(
		"url=s"   => \$url,
		"count=i" => \$count,
	);

	die("A 'url' is required") if ( !$url );
}
