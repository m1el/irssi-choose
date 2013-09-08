use strict;
use Irssi;
use POSIX;
use URI::Escape;
use List::Util qw(shuffle);
use Math::BigInt;
use Math::BigInt::Random qw(random_bigint);
our %IRSSI = (
	authors=> 'Hue hue',
	contact=> 'Wizord@Rizon',
	name=> 'choose.pl',
	description=> 'get choice or order of things for lazy people',
	license=> 'WTFPL v2',
);

our $maxlength = 768;
our $orderlimit = 1000;
our @allowed = ("#commie-subs");
our $intre = qr/(-?\s*\d+)/;
our $floatre = qr/(-?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)/;

sub parse_intrange {
	my $_ = shift;
	my $matches = /^$intre-$intre$/ || /^$intre\s+-\s+$intre$/;
	if (!$matches) {
		return;
	}
	my @result = sort {$a->bcmp($b);} map {s/\s+//g;Math::BigInt->new($_);} ($1, $2);
	return @result;
}

sub parse_floatrange {
	my $_ = shift;
	my $matches = /^$floatre-$floatre$/ || /^$floatre\s+-\s+$floatre$/;
	if (!$matches) {
		return;
	}
	return sort map {+$_;} ($1, $2);
}

sub parse_list {
	my $_ = shift;
	if (/,/) {
		return map {s/^\s+|\s+$//g;$_;} split /,/, $_;
	} else {
		return split / +/;
	}
}

sub choose_response {
	my $_ = shift;
	my ($a, $b, @ls);
	if (($a, $b) = parse_intrange($_)) {
		my $range = $b->copy()->bsub($a);
		return $a->copy()->badd(random_bigint(min => 0, max => $range))->bstr();
	}
	if (($a, $b) = map{+$_;}parse_floatrange($_)) {
		return sprintf("%f", $a + rand($b - $a));
	}
	if (@ls = parse_list($_)) {
		return $ls[int(rand($#ls))];
	}
}

sub order_response {
	my ($a, $b, $r, $ls);
	my $_ = shift;
	if (($a, $b) = parse_intrange($_)) {
		if ($b->copy()->bsub($a)->bdiv(2)->babs()->bcmp($orderlimit) == -1) {
			my @resp = map{$a->copy()->badd($_);}(0 .. $b->copy()->bsub($a)->as_int());
			return join ", ", shuffle @resp;
		} else {
			my (%h, $d, @resp);
			for my $i(0..$orderlimit-1) {
				my $range = $b->copy()->bsub($a);
				1 while ($h{$d=$a->copy()->badd(random_bigint(min=>0, max=>$range))});
				$h{$d} = 1;
				push(@resp, $d->bstr());
			}
			undef %h;
			return join ", ", @resp;
		}
	}
	if (my @ls = parse_list($_)) {
		return join ", ", shuffle @ls;
	}
}

sub max { my($x,$y)=@_; $x > $y ? $x : $y; }
sub min { my($x,$y)=@_; $x < $y ? $x : $y; }

sub sanitize {
	my $_ = shift;
	s/\bxd\b/ecksdee/i;
	s/^[.!\\#]/(RTSMW) $&/;
	if (length($_) > $maxlength) {
		$_ = substr($_, 0, max($maxlength - 3, 0)) . "...";
	}
	return $_;
}

sub privmsg {
	my ($server, $data, $nick, $address, $chan) = @_;
	$chan = $chan || $nick;
	return if !($chan ~~ @allowed);
	my ($cmd, $args) = split(/ +/, $data, 2);
	if (lc $cmd =~ /^\.(?:o|order)$/) {
		my $resp = order_response($args);
		if ($resp) {
			$resp = sanitize("$nick: $resp");
			$server->command("MSG $chan " . $resp);
		}
	}
	if (lc $cmd =~ /^\.(?:c|choose)$/) {
		my $resp = choose_response($args);
		if ($resp) {
			$resp = sanitize("$nick: $resp");
			$server->command("MSG $chan " . $resp);
		}
	}
	return 0;
}
#print sanitize(order_response($ARGV[0]));
Irssi::signal_add_last("event privmsg", "privmsg");
Irssi::signal_add_last("message public", "privmsg");
Irssi::signal_add_last("message own_public", "privmsg");

