#!/usr/bin/perl

#	<VirtualHost *:80>
#	        ServerName sfw.c2.com
#	        Header add Access-Control-Allow-Origin "*"
#	        ScriptAlias / /home/httpd/cgi-bin/sfw/
#	</VirtualHost>

my $SEP = "\263";
my ($title, $slug, $path);
$_ = $ENV{'PATH_INFO'};

if (/^\/([a-z-]+)\.json/) { &servePage($1) }
elsif (/^\/favicon\.(ico|png)/) { print "Content-type: image/png\n\n", `cat favicon.png`; }
elsif (/^\/client\.js\b/) { print "Content-type: text/html\n\n", `cat repo/client/client.js`; }
elsif (/^\/style\.css\b/) { print "Content-type: text/css\n\n", `cat repo/client/style.css`; }
elsif (/^\/(\w+)\.png\b/) { print "Content-type: text/css\n\n", `cat repo/client/$1.png`; }
elsif (/^\/$/) { print "Content-type: text/html\n\n", `cat welcome-visitors.html`; }
elsif (/^\/system\/sitemap.json/) { &serveSitemap() }
else {  print "Content-type: text/html\n\n", `cat welcome-visitors.html`; }

sub sitemapEntry {
        ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat("wiki.wdb/$_");
        $title = $slug = $_;
        $title =~ s/([a-z])([A-Z])/$1 $2/g;
        $slug =~ s/([a-z])([A-Z])/$1-$2/g;
        $slug = lc $slug;
        return <<;
{"slug":"$slug", "title":"$title", "date":${mtime}000}

}

sub serveSitemap {
	print "Content-type: text/json\n\n";
	@pages = split "\n", `ls -t wiki.wdb | head -300`;
	print "[", join(",", map(&sitemapEntry(), @pages)), "]\n";
}

sub servePage {
	$title = $slug = $path = $_[0];
	$path =~ s/-([a-z])/\U$1/g;
	$path =~ s/^([a-z])/wiki.wdb\/\U$1/;
	$title =~ s/^([a-z])/\U$1/;
	$title =~ s/-([a-z])/ \U$1/g;
	print "Status: 404 Not Found\r\n" unless -f $path;
	print "Content-type: text/plain\n\n";
	&convert($path);
}

sub randomid {
	sprintf("%08d",rand(10**8)).sprintf("%08d",rand(10**8));
}

sub page {
	my ($slug,$title,$story,$d) = @_;
	$id = randomid();
	my $a = <<;
{"date": $d,  "id": "$id", "type": "create", "item": {"title": "$title", "story": $story}}

	$page =~ s/}$/,"journal":[]}/;
	print <<;
{"title": "$title", "story": $story, "journal": [$a]}

}

sub InPlace {
	my ($num) = (@_);
	my ($ref) = $InPlace[$num];
	$ref =~ s/^http:([^\/])/http:\/\/c2.com\/$1/;
	my $site = $1 if $ref =~ /https?:\/\/([^\/]+)*/;
	return "[$ref $site]" unless $ref =~ /\.(gif|jpg|jpeg|png)$/;
	my $id = randomid();
	push @page, <<;
{"type":"image", "url":"$ref", "text":"$site", "id":"$id"}

	return "";
}

sub InternalLink {
	my ($title) = $_[0];
	$title =~ s/([a-z])([A-Z])/$1 $2/g;
	"[[$title]]";
}

sub paragraph {
	my ($text) = @_;
	$InPlace=0;
	while ($text =~ s/\b(https?):[^\s<>\[\]"'\(\)]*[^\s<>\[\]"'\(\)\,\.\?]/$SEP$InPlace$SEP/) { $InPlace[$InPlace++] = $&; }
	$text =~ s/\b([A-Z][a-z]+([A-Z][a-z]+)+)\b/&InternalLink($1)/geo;
	$text =~ s/'''(.*?)'''/<b>$1<\/b>/g;
	$text =~ s/''(.*?)''/<i>$1<\/i>/g;
	$text =~ s/^\s*\*+//;
	$text =~ s/\\/\\\\/g;
	$text =~ s/\r?\n/\\n/g;
	$text =~ s/\t/\\t/g;
	$text =~ s/"/\\"/g;
	$text =~s/$SEP(\d+)$SEP/&InPlace($1)/geo;
	$id = randomid();
	return <<;
{"type": "paragraph", "text": "$text", "id": "$id"}

}

sub code {
	$id = randomid();
	s/\\/\\\\/g;
	s/\r?\n/\\n/g;
	s/\t/  /g;
	s/"/\\"/g;
	return <<;
{"type": "code", "text": "$_", "id": "$id"}

}

sub convert {
	($path) = @_;
	$page = $1 if $path=~/([A-Za-z]+)$/;
	#print "$path\n";
	my $d = `date +%s -r $path`;
        $d =~ s/\n/000/;
	$db = `cat $path`;
	%db = split $SEP, $db;
	$date =$db{'date'};
	$text =$db{'text'};

	@lines = split /\r?\n/, $text;
	@page = ();
	$line = 0;
	while($line <= $#lines) {
		$_ = $lines[$line++];
		if (/^\s$/) {
			# ignore
		} elsif (/^----+$/) {
			push @page, paragraph "<hr>";

		} elsif (/^\s+[^\*]/) {
			while($lines[$line] =~ /^\s[^\*]/) {
				$_ .= "\n" . $lines[$line++];
			}
			push @page, code $_ if /\S/;
		} else {
			while($lines[$line] =~ /^\w/) {
				$_ .= "\n" . $lines[$line++];
			}
			push @page, paragraph $_ if /\S/;
		}
	}
	push @page, paragraph "See original on  http://c2.com/cgi/wiki?$page";
	$page = join ',', @page;
	page $slug, $title, "[$page]", $d;
}

