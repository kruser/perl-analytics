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
my $count     = 10;
my @intervals = ();

my $sessionId = UUID::Generator::PurePerl->new()->generate_v1()->as_string();
my $userGuid  = 'c0f1fd6a-77d0-4fd1-99e9-332b05a03bc2';
my $user      = 'consultant@kruseonline.net';
my $pass      = 'test123';
my $baseUrl;

load_options();
if ($url =~ /(http.+?\.com:\d+)/) {
	$baseUrl = $1;	
	print "Base: $baseUrl\n";
}

print "Testing $url $count times...\n";

my $browser = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
my $cookies = HTTP::Cookies->new();
$browser->cookie_jar($cookies);

loginViaDrupal();
for ( my $i = 0 ; $i < $count ; $i++ ) {
	load_page();
}
print 'Min: '.min(@intervals)." seconds\n";
print 'Max: '.max(@intervals)." seconds\n";
print 'Mean: '.mean(@intervals)." seconds\n";

print Dumper(@intervals);

sub loginViaDrupal() {
	print "Logging in to this site via Drupal...\n";
	my $request =
	  HTTP::Request->new( 'POST',
		"$baseUrl/site/service/userprofile/login" );
	$request->header( 'Content-Type' => 'application/json' );
	$request->content("{\"username\":\"$userGuid\",\"password\":\"$pass\"}");
	my $response = $browser->request($request);
}

sub loginViaAppServer() {
	print "Logging in to this site via App server...\n";

	my $loginUri =
"https://dapp.noesisenergy.com/KeyMaster/RestKeyMaster.svc/json/LoginUsingBrazosIdentity?sessionId=$sessionId&sessionDurationSecs=1728000&email=$user&password=$pass";

	my $req = HTTP::Request->new( GET => $loginUri );
	$req->header( 'Referer', $url );

	my $loginResponse = $browser->request($req);
	my $basicResult   = from_json( $loginResponse->content() );
	foreach my $cookie ( @{ $basicResult->{'CookieContainer'}->{'Cookies'} } ) {
		foreach my $cookieContents ( @{ $cookie->{'Value'} } ) {
			print "setting new cookie......\n";
			$cookies->set_cookie(
				0,
				$cookieContents->{'Name'},
				$cookieContents->{'Value'},
				'/', 'devcms.noesisenergy.com', 4430, 0, 0, 86400, 0
			);
		}
	}
}

sub load_page() {
	my $start = [Time::HiRes::gettimeofday];
	$browser->get( $url, Referer => $url );
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
