package Noesis::Profiles;

use strict;
use JSON -support_by_pp;
use LWP;

my $browser = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );

sub new
{
	my ( $proto, %params ) = @_;
	my $package = ref($proto) || $proto;

	my $this = { appServer => undef, };

	foreach my $key ( keys %params )
	{
		$this->{$key} = $params{$key};
	}
	
	bless( $this, $package );
	return $this;
}

# Given a hash where the username GUIDs are the keys, returns a new hash of public profile objects
sub get_user_profiles
{
	my $this = shift;
	my $usernames   = shift;
	my $profileHash = {};

	my @usernamesArray = keys %$usernames;

	# get 20 users at a time
	while ( my @list = splice( @usernamesArray, 0, 20 ) )
	{
		my $usernameCsv;
		for my $key (@list)
		{
			if ($usernameCsv)
			{
				$usernameCsv .= ',';
			}
			$usernameCsv .= '"' . $key . '"';
		}
		my $url         = $this->{appServer} . "/KeyMaster/RestKeyMaster.svc/json/GetPublicProfiles?usernames=[$usernameCsv]";
		my $resp        = $browser->get($url);
		my $json        = new JSON;
		my $profileJson =
		  $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode( $resp->content );
		for my $profile ( @{ $profileJson->{'Profiles'} } )
		{
			$profileHash->{ $profile->{'Username'} } = $profile;
		}
	}
	return $profileHash;
}

1;
