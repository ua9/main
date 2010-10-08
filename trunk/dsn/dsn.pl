#!/usr/bin/perl

my $message = do {local (@ARGV,$/); <STDIN>};
%exit_codes = ("OK", 0, "DATAERR", 65, "TERM", 1);


sub getHeader
{
	my $message = $_[0];
	my $header_name = $_[1];
	my $header_partnum = $_[2];
	$message =~ /^\Q${header_name}\E:[ \t]*([^\n]+\n([\t ]+[^\n]+\n)*)/msi;
	my $header = $1;
	$header =~ s/\n\s*//ms;
	if ( length($header_partnum) > 0 )
	{
		if ( $header_partnum =~ /^\d+$/ )
		{
			my @header_parts = split(/\s*;\s*/, $header);
			$header = $header_parts[$header_partnum];
		}
		else
		{
			$header =~ /(^|;)\s*\Q${header_partnum}\E=((\x22|\x27)?)([^;]+)(\2)/;
			$header = $4;
		}
	}
	trim($header);
	return $header;
}

sub trim
{
	$_[0] =~ s/(\A\s+)|(\s+\z)//g;
}

sub splitMessage
{
	my $message = $_[0];
	my $boundary = getHeader($message, "content-type", "boundary");
	$message =~ s/--\Q$boundary\E--//;
	return split(/--\Q$boundary\E/ms, $message);
}

sub findByContentType
{
	my @message_parts = @{@_[0]};
	my $contentType = $_[1];
	my $count = @message_parts;
	for($i = 0; $i < $count; $i++)
	{
		my $header = getHeader($message_parts[$i], 'content-type');
		if(getHeader($message_parts[$i], 'content-type') eq $contentType)
		{
			return $i;
		}
	}
	return -1;
}

sub myexit
{
	print $_[1]."\n";
	exit $_[0];
}

sub getReports
{
	my $dsn_part = $_[0];
	my @subparts = ();
	foreach $subpart (split("\n\n", $dsn_part))
	{
		if ( getHeader($subpart, "final-recipient") ne "" )
		{
			push @subparts, $subpart;
		}
	}
	return @subparts;
}

sub getEmail
{
	$_[0] =~ /([^@\s<,;]+@[^>\s,;]+)/;
}

my @message_parts = splitMessage($message);

$report_type = getHeader($message, "content-type", "report-type");
if ( $report_type ne "delivery-status" )
{
	myexit($exit_codes{"DATAERR"}, "Looks like it does not have delivery status report.");
}

my $dsnPart = findByContentType(\@message_parts, "message/delivery-status");
if ( $dsnPart == -1 )
{
	myexit($exit_codes{"DATAERR"}, "Cant find delivery status message part.");
}

my $messagePart = findByContentType(\@message_parts, "message/rfc822");
if ( $messagePart == -1 )
{
	$messagePart = findByContentType(\@message_parts, "text/rfc822-headers");
}
if ( $messagePart == -1 )
{
	myexit($exit_codes{"DATAERR"}, "Cant find source message or source message headers.");
}

my $listId = getHeader($message_parts[$messagePart], "x-list-id");
if ( $listId !~ /^\d+$/ )
{
	myexit($exit_codes{"DATAERR"}, "Cant find maillist id.");
}

my @reports = getReports($message_parts[$dsnPart]);
if ( @reports == 0)
{
	myexit($exit_codes{"DATAERR"}, "Cant find reports.");
}

foreach $report (@reports)
{
	my $action = getHeader($report, "action");
	if ( $action eq "" )
	{
		print "Cant find action in report:" . $report."\n";
		next;
	}
	my $recipient = getHeader($report, "final-recipient", "1");
	if ( $recipient eq "" )
	{
		print "Cant find recipient in report:" . $report."\n";
		next;
	}
	print "$recipient $action\n";
}

myexit($exit_codes{"OK"}, "Done successfully");
