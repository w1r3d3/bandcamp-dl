#!/usr/bin/perl
#
# __________                    .___                                     ________        /\ .____     
# \______   \_____    ____    __| _/____ _____    _____ ______           \______ \      / / |    |    
#  |    |  _/\__  \  /    \  / __ |/ ___\\__  \  /     \\____ \   ______  |    |  \    / /  |    |    
#  |    |   \ / __ \|   |  \/ /_/ \  \___ / __ \|  Y Y  \  |_> > /_____/  |    `   \  / /   |    |___ 
#  |______  /(____  /___|  /\____ |\___  >____  /__|_|  /   __/          /_______  / / /    |_______ \
#         \/      \/     \/      \/    \/     \/      \/|__|                     \/  \/             \
#
# Bandcamp Downloader v1
# USAGE: bandcamp_dl.pl ARG
#
# ARG can be an URL to a Bandcamp album, e.g. 'https://woodenshjips.bandcamp.com/album/v' or a file path to a local image of your Bandcamp fan page, e.g. 'fanpage.html'.
# To generate such an image file, navigate Chrome to your Bandcamp fan page 'https://bandcamp.com/YOUR-FAN-ACCOUNT-NAME' and step through all lists until all items was
# fetched/loaded. Then store the entire web page as a complete/full HTML file and use this file as the input argument to this tool.
#
use JSON;
use LWP::Simple;

sub download_file($$)
{
	($fname, $url) = @_;
	
	if (-e $fname && -s $fname)
	{
		print "\tSkip '$fname', file exists already\n";
	}
	else
	{
		print "\tGet '$fname' from '$url'\n";
		$data = get($url) or print "\t\tERROR: Failed to download!\n";
		if (defined $data)
		{
			open($out, '>:raw', $fname) or print "\t\tERROR: Failed to create file!\n";
			if (defined $out)
			{
				print $out $data or print "\t\tERROR: Failed to write file!\n";
				close $out;
			}
		}
	}
}

sub download_album($)
{
	($album_url) = @_;
	
	$input = get($album_url) or die "ERROR: Failed to fetch input data from '$album_url'";
	$input =~ m/^\s+artist: \"(.+)\"/m;
	$artist = $1;
	$input =~ m/^\s+album_title: \"(.+)\"/m;
	$title = $1;
	$input =~ m/^\s+art_id: (\d+)/m;
	$cover = $1;
	$input =~ m/^\s+trackinfo\s?:(.+),$/m;
	$trackinfo = from_json($1);
	
	$album = "$artist - $title";
	$album =~ s/[^A-Za-z0-9\-\.\s']/_/g;
	print "Download album '$album'...\n";
	{
		mkdir $album;
		for (@$trackinfo)
		{
			$url = $_->{file}->{'mp3-128'};
			$url =~ s\^//\http://\;
			$title = "$_->{title}";
			$title =~ s/[^A-Za-z0-9\-\.\s']/_/g;
			$fname = sprintf("$album/%02d $title.mp3", $_->{track_num});
			download_file($fname, $url);
		}
		
		$url = 'https://f4.bcbits.com/img/a'.$cover.'_10.jpg';
		$fname = "$album/cover.jpg";
		download_file($fname, $url);
	}
}

sub main($)
{
	($arg) = @_;

	die "ERROR: Invalid arguments!\n" if not $arg;

	local $/ = undef;
	open FILE, $arg;
	if (defined FILE)
	{
		binmode FILE;
		$input = <FILE>;
		close FILE;
		
		%albums=();
		for ($input =~ m/^\s*<a target=\"_blank\" href=\"(.+)\" class=\"item-link\">/gm)
		{
			$albums{$_}++ or $albums{$_}=1;
		}
		
		$albums_sz = scalar keys %albums;
		print "Found $albums_sz albums on page '$arg'\n";
		if ($albums_sz > 0)
		{
			print "Start downloading now!\n";
			$cnt = 0;
			for (sort keys %albums)
			{
				print sprintf("[%.0f%%] Download album %d of %d", (100.0*$cnt)/$albums_sz, $cnt+1, $albums_sz)." from '$_'\n";
				download_album($_);
				$cnt++;
			}
		}
	}
	else
	{
		download_album($arg);
	}
}

main(shift);
