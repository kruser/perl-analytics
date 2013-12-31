package Noesis::Reporting;

#
# Utilities to build a CSV or xlsx report from a Perl array of hashtables.
#
use strict;
use Excel::Writer::XLSX;
use Text::CSV::Slurp;


#
# @param data - a two dimensional array of rows and columns
# @param file - the filename that we're going to print to. Can be optional if printing an CSV, in which case we'll use STDOUT
sub new
{
	my ( $proto, %params ) = @_;
	my $package = ref($proto) || $proto;

	my $this = {
		data   => undef,
		file   => undef,
	};

	foreach my $key ( keys %params )
	{
		$this->{$key} = $params{$key};
	}

	bless( $this, $package );
	return $this;
}

# Builds a new excel doc based on the data array
sub build_excel_doc()
{
	my $this      = shift;
	my $workbook  = Excel::Writer::XLSX->new( $this->{file} );
	my $worksheet = $workbook->add_worksheet();

	my $col = 0;
	my $row = 0;
	my $headerPrinted;

	foreach my $reportRow ( @{ $this->{data} } )
	{
		$row++;
		$col = 0;
		foreach my $key ( sort keys %{$reportRow} )
		{
			if ( !$headerPrinted )
			{
				$worksheet->write( 0, $col, $key );
			}
			$worksheet->write( $row, $col, $reportRow->{$key} );
			$col++;
		}
		$headerPrinted = 1;
	}
}

# prints a csv based on the data array to $this->file or to STDOUT if $outputFile isn't defined
sub build_csv_report()
{
	my $this = shift;
	my $csv = Text::CSV::Slurp->create( input => \@{ $this->{data} } );
	if ( $this->{file} )
	{
		open( FH, ">" . $this->{file} );
		print FH $csv;
		close FH;
	}
	else
	{
		print $csv;
	}
}

1;
