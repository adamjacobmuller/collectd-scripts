#!/usr/bin/perl
use Sys::Hostname;
$|=0;
my $interval=10;
$ENV{PATH}="";
my $bgpctl="/usr/sbin/bgpctl";
my $pfctl="/sbin/pfctl";
my $vtysh="/usr/bin/vtysh";
my $do_bgpctl=1;
my $do_vtysh=0;
my $do_pfctl_queues=1;
my $do_pfctl_stats=1;
foreach my $arg (@ARGV) {
	if ($arg =~ /-bgpctl=(.*)/) {
		$bgpctl=$1;
	} elsif ($arg =~ /^-pfctl=(.*)$/) {
		$pfctl=$1;
	} elsif ($arg =~ /^-interval=(\d+)$/) {
		$interval=$1;
	} elsif ($arg =~ /^-(?:(no)-)?(bgpctl|vtysh|pfctl-queues|pfctl-stats)/) {
		my $value;
		if ($1 eq "no") {
			$value=0;
		} else {
			$value=1;
		}
		if ($2 eq "bgpctl") {
			$do_bgpctl=$value;
		} elsif ($2 eq "vtysh") {
			$do_vtysh=$value;
		} elsif ($2 eq "pfctl-queues") {
			$do_pfctl_queues=$value;
		} elsif ($2 eq "pfctl-stats") {
			$do_pfctl_stats=$value;
		}
	} else {
		printf("invalid arg %s\n",$arg);
		exit(1);
	}
}
my $last=time;
while (true) {
	if ($do_vtysh) {
		open(VTYSH,sprintf("%s -c \"show ip bgp sum\"|",$vtysh));
		while(<VTYSH>) {
			# Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
			# 10.0.9.26       4 64514       0       0        0    0    0 never    Active     
			# 10.0.9.30       4 64514   70904   70910        0    0    0 02w3d21h       29
			if ($_ =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([^ ]+)\s+([^ ]+)/)  {
				my $peerip=$1;
				my $peeras=$3;
				my $messgaes_received=$4;
				my $messages_sent=$5;
				my $outq=$7;
				my $inq=$8;
				my $prefixes=$10;
				printf("PUTVAL %s/bgp-%s/counter-messgaes_received interval=%d N:%d\n",		hostname,$peerip,$interval,$messages_received);
				printf("PUTVAL %s/bgp-%s/counter-messgaes_sent interval=%d N:%d\n",		hostname,$peerip,$interval,$messages_sent);
				printf("PUTVAL %s/bgp-%s/gauge-outq interval=%d N:%d\n",			hostname,$peerip,$interval,$outq);
				printf("PUTVAL %s/bgp-%s/gauge-inq interval=%d N:%d\n",				hostname,$peerip,$interval,$inq);
				if ($prefixes =~ /^(\d+)$/) {
					printf("PUTVAL %s/bgp-%s/gauge-prefixes interval=%d N:%d\n",		hostname,$peerip,$interval,$prefixes);
				} else {
					printf("PUTVAL %s/bgp-%s/gauge-prefixes interval=%d N:U\n",		hostname,$peerip,$interval);
				}
			} else {
			}
		}
		close(VTYSH);
	}
	if ($do_bgpctl) {
		open(BGPCTL,sprintf("%s -n show summary|",$bgpctl));
		while(<BGPCTL>) {
			if ($_ =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)$/) {
				my $peerip=$1;
				my $peeras=$2;
				my $messgaes_received=$3;
				my $messages_sent=$4;
				my $outq=$5;
				my $prefixes=$7;
				printf("PUTVAL %s/bgp-%s/counter-messgaes_received interval=%d N:%d\n",		hostname,$peerip,$interval,$messages_received);
				printf("PUTVAL %s/bgp-%s/counter-messgaes_sent interval=%d N:%d\n",		hostname,$peerip,$interval,$messages_sent);
				printf("PUTVAL %s/bgp-%s/gauge-outq interval=%d N:%d\n",			hostname,$peerip,$interval,$outq);
				if ($prefixes =~ /^(\d+)$/) {
					printf("PUTVAL %s/bgp-%s/gauge-prefixes interval=%d N:%d\n",		hostname,$peerip,$interval,$prefixes);
				} else {
					printf("PUTVAL %s/bgp-%s/gauge-prefixes interval=%d N:U\n",		hostname,$peerip,$interval);
				}
			}
		}
		close(BGPCTL);
	}

	#printf("do_pfctl_queues= %s\n",$do_pfctl_queues);
	if ($do_pfctl_queues) {
		my $name;
		my $interface;
		my $packets;
		my $bytes;
		my $dropped_packets;
		my $dropped_bytes;
		my $qlength_length;
		my $qlength_max;
		open(PFCTL,sprintf("%s -vsq|",$pfctl));
		while(<PFCTL>) {
			if ($_ =~ /^queue\s+([^ ]+) on ([^ ]+)/) {
				$name=$1;
				$interface=$2;
			} elsif ($_ =~ /pkts:\s+(\d+)\s+bytes:\s+(\d+)\s+dropped pkts:\s+(\d+)\s+bytes:\s+(\d+)/) {
				$packets=$1;
				$bytes=$2;
				$dropped_packets=$3;
				$dropped_bytes=$4;
				printf("PUTVAL %s/pf_queue-%s_%s/counter-packets interval=%d N:%d\n",hostname,$name,$interface,$interval,$packets);
				printf("PUTVAL %s/pf_queue-%s_%s/counter-bytes interval=%d N:%d\n",hostname,$name,$interface,$interval,$bytes);
				printf("PUTVAL %s/pf_queue-%s_%s/counter-dropped_packets interval=%d N:%d\n",hostname,$name,$interface,$interval,$dropped_packets);
				printf("PUTVAL %s/pf_queue-%s_%s/counter-dropped_bytes interval=%d N:%d\n",hostname,$name,$interface,$interval,$dropped_bytes);
			} elsif ($_ =~ /qlength:\s*(\d+)\/\s*(\d+)/) {
				$queue_length=$1;
				$queue_max=$2;
				printf("PUTVAL %s/pf_queue-%s_%s/gauge-queue_length interval=%d N:%d\n",hostname,$name,$interface,$interval,$queue_length);
				printf("PUTVAL %s/pf_queue-%s_%s/gauge-queue_max interval=%d N:%d\n",hostname,$name,$interface,$interval,$queue_max);
			} else {
				chomp;
				printf("BADLINE?: %s\n",$_);
			}
		}
		close(PFCTL);
	}
	#printf("do_pfctl_stats = %s\n",$do_pfctl_stats);
	if ($do_pfctl_stats) {
		my $section;
		my $skip=0;
		open(PFCTL,sprintf("%s -vsi|",$pfctl));
		while(<PFCTL>) {
			if ($_ =~ /Interface Stats for/) {
				$skip=1;
			} elsif ($_ =~ /^(State Table|Source Tracking Table|Counters)/) {
				$skip=0;
				if ($1 eq "State Table") {
					$section="state-table";
				} elsif ($1 eq "Source Tracking Table") {
					$section="source-tracking-table";	
				} elsif ($1 eq "Counters") {
					$section=undef;
				}
			} elsif ($_ =~ /\s+(.*?)\s{2,}(\d+)\s+(?:(\d+\.\d+)\/s)?/) {
				my $key=$1;
				my $value=$2;
				my $type;
				if ($3) {
					$type="counter";
				} else {
					$type="gauge";
				}
				$key =~ s/[ ]+/-/g;
				next if ($skip);
				if ($section) {
					printf("PUTVAL %s/pf/%s-%s/%s interval=%d N:%d\n",hostname,$type,$section,$key,$interval,$value);
				} else {
					printf("PUTVAL %s/pf/%s-%s interval=%d N:%d\n",hostname,$type,$key,$interval,$value);
				}
			}
		}
		close(PFCTL);
	}

	$sleep=(time+$interval)-$last;
	sleep($sleep);
	$last=time;
}
