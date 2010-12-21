#!/usr/bin/perl
sub parse_table {
	my ($file)=@_;
	open(TABLE,$file);
	my $table={};
	while(<TABLE>) {
		if ($_ =~ /^(\w+): ([\d- ]+)$/) {
			my @tmp=split(/ /,$2);
			$i=0;
			foreach (@tmp) {
				$table->{$1}->{$i}->{'value'}=$_;
				$i++;	
			}
		} elsif ($_ =~ /^(\w+): ([\w ]+)$/) {
			my @tmp=split(/ /,$2);
			$i=0;
			foreach (@tmp) {
				$table->{$1}->{$i}->{'key'}=$_;
				$i++;	
			}
		}
	}
	close(TABLE);
	my $new_table={};
	for my $tn (keys %$table) {
		$tv=$table->{$tn};
		while(my($k,$v)=each(%$tv)) {
			$new_table->{$tn}->{$v->{'key'}}=$v->{'value'};
		}
	}
	return $new_table;
}
use Data::Dumper;
use Sys::Hostname;
$|=0;
my $interval=10;
$ENV{PATH}="";
my $last=time;
my $type="counter";
while (true) {
	my $snmp=parse_table("/proc/net/snmp");
	while(my($section,$values)=each(%$snmp)) {
		while(my($key,$value)=each(%$values)) {
			printf("PUTVAL %s/netstats/%s-%s/%s interval=%d N:%d\n",hostname,$type,$section,$key,$interval,$value);
		}
	}
	my $netstat=parse_table("/proc/net/netstat");
	while(my($section,$values)=each(%$netstat)) {
		while(my($key,$value)=each(%$values)) {
			printf("PUTVAL %s/netstats/%s-%s/%s interval=%d N:%d\n",hostname,$type,$section,$key,$interval,$value);
		}
	}
	$sleep=(time+$interval)-$last;
	sleep($sleep);
	$last=time;
}
