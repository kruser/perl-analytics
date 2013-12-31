#!/usr/bin/perl
use strict;
use Text::CSV;

print 'DECLARE @Username uniqueidentifier;'."\n";
print 'DECLARE @EmailSettingsId uniqueidentifier;'."\n";
print 'DECLARE @EmailAddress nvarchar(50);'."\n";

my $csvFile = '/Users/kruser/Downloads/qaiis.csv';
my $csv = Text::CSV->new( { binary => 1, eol => $/ } );
open my $io, "<", $csvFile or die "$csvFile: $!";
while ( my $row = $csv->getline($io) ) {
	my @fields = @$row;
	
	my $email    = @fields[0];
	print "\n";
	print 'SET @EmailAddress = \''.$email.'\''."\n";
	print 'SET @Username = (SELECT ua.BrazosUserName FROM [NEAppDB].[dbo].[UserAliases] ua WHERE ua.NameIdentifier = @EmailAddress);
IF (@Username IS NOT NULL)
BEGIN
	SET @EmailSettingsId = (SELECT bu.EmailSettingsID FROM [NEAppDB].[dbo].[BrazosUsers] bu WHERE bu.Username = @Username);
 
	IF (@EmailSettingsId IS NOT NULL)
	BEGIN
		UPDATE [NEAppDB].[dbo].[BrazosUserEmailSettings] SET [SendActivityDigest] = 0 WHERE [ID] = @EmailSettingsId;
		UPDATE [NEAppDB].[dbo].[BrazosUserEmailSettings] SET [SendAllNotifications] = 0 WHERE [ID] = @EmailSettingsId;
	END
	IF (@EmailSettingsId IS NULL)
	BEGIN
	    SET @EmailSettingsId = NEWID();
		INSERT INTO [NEAppDB].[dbo].[BrazosUserEmailSettings] ([ID], [SendActivityDigest], [SendAnnouncementsNotifications], [SendLevelUpdateNotifications], [SendMyPostCommentedNotifications], [SendNewFollowersNotifications], [SendNewLikesNotifications], [EmailNotificationFrequency], [SendAllNotifications]) VALUES (@EmailSettingsId, 0, 0, 0, 0, 0, 0, 0, 0);
		UPDATE [NEAppDB].[dbo].[BrazosUsers] SET [EmailSettingsID] = @EmailSettingsId WHERE [Username] = @Username;
	END
END';
}
