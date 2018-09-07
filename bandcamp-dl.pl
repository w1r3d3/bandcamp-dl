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
# ARG can be an URL to a Bandcamp album, e.g. 'https://woodenshjips.bandcamp.com/album/v', or a file path to a local image of your Bandcamp fan page, e.g. 'fanpage.html'.
# To generate such an image file, navigate Chrome to your Bandcamp fan page 'https://bandcamp.com/YOUR-FAN-ACCOUNT-NAME' and step through all lists until all items was
# fetched/loaded. Then store the entire web page as a complete/full HTML file and use this file as the input argument to this tool.
#
use Encode;
use JSON;
use LWP::Simple;

sub convert_filename($)
{
	($fname) = @_;
	$fname =~ s/[\:\*\\\/\?\|<>"]/_/g;
	$fname =~ s/^[\s\.]+|[\s\.]+$//g;
	return encode('cp1252', $fname);
}

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
	
	$input = get($album_url);
	if ($input)
	{
		$input =~ m/^\s+artist:\s*\"(.+)\",/m;
		$artist = $1;
		$input =~ m/^\s+album_title:\s*\"(.+)\",/m;
		$title = $1;
		$input =~ m/^\s+art_id:\s*(\d+)\s*,/m;
		$cover = $1;
		$input =~ m/^\s+trackinfo\s?:(.+),$/m;
		$trackinfo = from_json($1);
		$folder = convert_filename($artist.' - '.$title);
		
		print "\tAlbum: '$artist' - '$title'\n";
		
		print "\tFolder: $folder\n";
		mkdir $folder;
		
		download_file($folder.'/cover.jpg', 'https://f4.bcbits.com/img/a'.$cover.'_10.jpg');
		
		for (@$trackinfo)
		{
			$url = $_->{file}->{'mp3-128'};
			$url =~ s\^//\https?://\;
			$title = $_->{title};
			$track = sprintf('%02d', $_->{track_num});
			download_file($folder.'/'.convert_filename("$track - $title.mp3"), $url);
		}
	}
	else
	{
		print "ERROR: Failed to fetch data from '$album_url'\n";
	}
}

sub main($)
{
	($arg) = @_;
	die "ERROR: No argument specified" if not $arg;
	
	binmode STDOUT, ":encoding(cp850)";
	
	if ($arg =~ /^https?:/)
	{
		print "Download album from '$arg'\n";
		download_album($arg);
	}
	else
	{
		%albums = ();
		
		open($in, '<', $arg) or die "ERROR: Failed to open input file '$arg'";
		while (<$in>)
		{
			chomp;
			$albums{$1}=1 if (m/^\s*<a target=\"_blank\" href=\"(.+)\" class=\"item-link\">/gm);
		}
		close($in);
		
		$albums_sz = scalar keys %albums;
		print "Found $albums_sz albums on page '$arg'\n";
		
		if ($albums_sz > 0)
		{
			$cnt = 0;
			for (sort keys %albums)
			{
				print sprintf("[%d%%] Download album %d of %d", (100*$cnt)/$albums_sz, $cnt+1, $albums_sz)." from '$_'\n";
				download_album($_);
				$cnt++;
			}
		}
	}
}

main(shift);
