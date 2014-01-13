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

#my $url = 'https://devcms.noesisenergy.com:4430/site/service/userprofile/login';
#my $url = 'http://brazos.noesisenergy.com:8080/site/service/userprofile/login';
my $url = 'https://cambridge-cms.noesisenergy.com:4430/site/service/userprofile/login';
my $count     = 10;
my @intervals = ();
my $payload   = '{"user":"admin","password":"Brazos78759"}';

print "Testing $url $count times...\n";

for ( my $i = 0 ; $i < $count ; $i++ ) {
	run_login();
}
print 'Min: ' . min(@intervals) . " seconds\n";
print 'Max: ' . max(@intervals) . " seconds\n";
print 'Mean: ' . mean(@intervals) . " seconds\n";

print Dumper(@intervals);

sub run_login() {

	my $browser = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
	my $cookies = HTTP::Cookies->new();
	$browser->cookie_jar($cookies);

	my $req = HTTP::Request->new( POST => $url );
	$req->content_type('application/json');
	$req->content($payload);

	my $start    = [Time::HiRes::gettimeofday];
	my $response = $browser->request($req);
	$elapsed = Time::HiRes::tv_interval( $start, [Time::HiRes::gettimeofday] );
	push( @intervals, $elapsed );
}
