#!/usr/bin/perl
#
# ChileBobs Stratum Connector : Designed for Ycash
#
# stratum pool for solo mining

use strict;

package solo;

use JSON;					

use Digest::SHA qw(sha256);

use Switch;

use IO::Socket;

use IO::Socket::INET;

our $share_target = '0085555555555558000000000000000000000000000000000000000000000000';							# solo share difficulty target

our $block;																# block header assembled from template

my $block_timeout = 300;														# seconds to mine before retasking miners (NOT IMPLEMENTED)

my $miner_timeout = 30;															# seconds before refreshing mining tasks

my $nonce_length = 4;															# nonce size (bytes)

my $debug = 0;

my $client;																# hash for client config


###########################################################################################################################################################
#																	# connect miner to solo pool
sub connect {

	my ($msg) = @_;															# received message

	debug("connect()");

	$client->{$msg->{'miner_id'}} = {												# startup properties for this client

		address => '',														# auth address

		password => '',														# auth password

		extranonce => 0,													# 1 = extranonce capable

		block => -1,														# block being worked on

		refresh => ($main::timestamp + $miner_timeout),										# refresh time

		status => 'connected',

		tx => {},														# sent to miner

		rx => {},														# received from miner

		notify => ''														# timeout preventer
	};

	$main::miner->{$msg->{'miner_id'}}->{'pool'} = 'solo';										# update miner state

	$main::miner->{$msg->{'miner_id'}}->{'status'} = 'connecting';

	main::message("connected to solo pool", $msg->{'miner_id'});									# send message to console

	subscribe($msg);														# subscribe miner
}

###########################################################################################################################################################
#																	# receive message
sub recv {

	my ($msg) = @_;;

	debug("recv()");
	
	switch ($msg->{'rx'}->{'method'}) {												# check method

		case 'mining.subscribe' {												# subscribing to pool

			subscribe($msg);
		}

		case 'mining.authorize' {												# authentication

			authorize($msg);
		}

		case 'mining.extranonce.subscribe' {											# subscribe for extranonce updates

			$client->{$msg->{'miner_id'}}->{'extranonce'} = 1;								# cache this

			push (@main::send_buffer, {											# send ack to miner

				dest => 'miner',

				pool => 'solo',

				miner_id => $msg->{'miner_id'},

				socket => $msg->{'socket'},

				tx => "\{\"id\":$msg->{'rx'}->{'id'},\"result\":true,\"error\":null\}"
			});
		}

		case 'mining.submit' {													# miner sent solution

			$main::miner->{$msg->{'miner_id'}}->{'shares'}++;								# increment share counter

			$main::miner->{$msg->{'miner_id'}}->{'job_id'} = $msg->{'rx'}->{'id'};						# set job_id

			my $raw_block = $block->{'version'};										# assemble the block header

			$raw_block .= $block->{'previousblockhash'};

			$raw_block .= $block->{'merkleroot'};

			$raw_block .= $block->{'finalsaplingroothash'};

			$raw_block .= $msg->{'rx'}->{'params'}[2];									# use timestamp from miner, avoids MTP errors & allow catchup

			$raw_block .= $block->{'bits'};

			$raw_block .= "$main::miner->{$msg->{'miner_id'}}->{'nonce'}$msg->{'rx'}->{'params'}[3]";			# assemble the full nonce

			$raw_block .= $msg->{'rx'}->{'params'}[4];									# equihash solution from miner


			my $header_hash = hash_this($raw_block, 'le');									# get block header hash

			my $share_diff_check = 'false';											# check difficulty

			if ( check_difficulty($main::miner->{$msg->{'miner_id'}}->{'target'}, $header_hash) ) {				# check share diff

				$share_diff_check = 'true';
  			}

			# TODO: check solution? Not worth the effort as we trust our own miner 
			
			push (@main::send_buffer, {											# send ack/nack to miner

				dest => 'miner',

				pool => 'solo',

				miner_id => $msg->{'miner_id'},

				socket => $msg->{'socket'},

				tx => "\{\"id\":$msg->{'rx'}->{'id'},\"result\":$share_diff_check,\"error\":null\}"			# reply with miners job id
			});

			if (check_difficulty($block->{'target'}, $header_hash) ) {							# is this the winning share ???

				$raw_block .= $block->{'transactions'};									# add transactions

				my $resp = `$main::config->{'client'} -datadir=$main::config->{'datadir'} submitblock $raw_block 2>&1`;	# MINE THE BLOCK !!! TADA!!!!!

				main::message("\amined block $block->{'height'}", $msg->{'miner_id'});					# tell terminal & beep
			}														# end of parsing methods
		}
	}
}


###########################################################################################################################################################
#																	# check miner status & keep them working
sub workflow {

	my ($miner_id) = @_;

	switch ($main::miner->{$miner_id}->{'status'}) {

		case 'authorized' {													# authorized, ready for share target

			set_target($miner_id, $share_target);				
		}

		case 'targeted' {													# share target sent, setup complete

			$main::miner->{$miner_id}->{'status'} = 'idle';					
		}

		case 'idle' {														# put idle miners to work

			notify($miner_id, 'true');
		}

		case 'busy' {														# busy miners need work refreshing every 20 seconds

			if ($client->{$miner_id}->{'refresh'} < $main::timestamp) {							# check timestamp 
		
				$client->{$miner_id}->{'refresh'} = ($main::timestamp + $miner_timeout);				# set time for next refresh

				push (@main::send_buffer, {										# sent work to miner

					dest => 'miner',

					pool => 'solo',

					status => 'busy',

					socket => $main::miner->{$miner_id}->{'miner_socket'},

					tx => $client->{$miner_id}->{'notify'}								# cached notify to refresh task
				});
			}
		}
	}
}

###########################################################################################################################################################
#																	# miner is subscribing
sub subscribe {

	my ($msg) = @_;															# received message

	debug ("subscribe()");

	if ($main::miner->{$msg->{'miner_id'}}->{'pool'} eq 'solo') {

		$main::miner->{$msg->{'miner_id'}}->{'version'} = $msg->{'rx'}->{'params'}[0];						# cache miner software

		$main::miner->{$msg->{'miner_id'}}->{'nonce'} = newkey($nonce_length);							# generate nonce

		push (@main::send_buffer, {

			dest => 'miner',

			pool => 'solo',

			miner_id => $msg->{'miner_id'},

			status => 'subscribed',

			socket => $msg->{'socket'},

			tx => "\{\"id\":$msg->{'rx'}->{'id'},\"result\":\[\[\],\"$main::miner->{$msg->{'miner_id'}}->{'nonce'}\",$nonce_length\],\"error\":null\}"
		});
	}
}


###########################################################################################################################################################
#																	# miner is authorizing
sub authorize {

	my ($msg) = @_;															# received message

	debug("authorize()");

	$client->{$msg->{'miner_id'}}->{'address'} = $msg->{'rx'}->{'params'}[0];							# address

	$client->{$msg->{'miner_id'}}->{'password'} = $msg->{'rx'}->{'params'}[1];							# password

	push (@main::send_buffer, {

		dest => 'miner',

		pool => 'solo',

		miner_id => $msg->{'miner_id'},

		status => 'authorized',

		socket => $msg->{'socket'},

		tx => "\{\"id\":$msg->{'rx'}->{'id'},\"result\":true\}"
	});
}


###########################################################################################################################################################
#																	# set target
sub set_target {

	debug("set_target()");

	my ($miner_id, $target) = @_;														

	if ($target eq '') {													# use default target if undefined

		$target = $share_target;
	}

	push (@main::send_buffer, {

		dest => 'miner',

		pool => 'solo',

		miner_id => $miner_id,

		status => 'targeted',

		socket => $main::miner->{$miner_id}->{'miner_socket'},

		tx => "\{\"id\":null,\"method\":\"mining.set_target\",\"params\":\[\"$target\"\]\}"									
	});
}


###########################################################################################################################################################
#																	# miner subscribing for extranonce
sub extranonce_subscribe {

	my ($msg) = @_;															# received message

	push (@main::send_buffer, {

		dest => 'miner',

		pool => 'solo',

		miner_id => $msg->{'miner_id'},

		status => 'extranonce_subscribe',

		socket => $msg->{'socket'},

		tx => "\{\"id\":$msg->{'rx'}->{'id'},\"result\":true,\"error\":null\}"							# yes, we support this					
	});
}


###########################################################################################################################################################
#																	# send new nonce to miner
sub set_extranonce {

	my ($miner_id) = @_;														# received message

	$main::miner->{$miner_id}->{'nonce'} = newkey($nonce_length);								# generate nonce

	push (@main::send_buffer, {

		dest => 'miner',

		pool => 'solo',

		miner_id => $miner_id,

		status => 'set_extranonce',

		socket => $main::miner->{$miner_id}->{'miner_socket'},

		tx => "\{\"id\":null,\"method\":\"mining.set_extranonce\",\"params\":\[\"$main::miner->{$miner_id}->{'nonce'}\",$nonce_length\]\}"	
	});
}


###########################################################################################################################################################
#																	# send work to miner
sub notify {

	my ($miner_id, $flag) = @_;

	if ($flag eq 'true') {													# miner to start new task

		$main::miner->{$miner_id}->{'notify_id'}++;
	}

	else {															# refresh current task

		$flag = 'false';
	}
																# cache task for refresh
																
	$client->{$miner_id}->{'notify'} = "\{\"id\":null,\"method\":\"mining.notify\",\"params\":\[\"" . sprintf("%x", $main::miner->{$miner_id}->{'notify_id'}) . "\",\"$block->{'version'}\",\"$block->{'previousblockhash'}\",\"$block->{'merkleroot'}\",\"$block->{'finalsaplingroothash'}\",\"$block->{'curtime'}\",\"$block->{'bits'}\",$flag,\"ZcashPoW\"\]\}"; 

	push (@main::send_buffer, {												# sent work to miner

		dest => 'miner',

		pool => 'solo',

		miner_id => $miner_id,

		status => 'busy',

		socket => $main::miner->{$miner_id}->{'miner_socket'},

		tx => $client->{$miner_id}->{'notify'}
	});
}


###########################################################################################################################################################
#									
sub node_rpc {																# talk to the node
	
	my ($command) = @_;

	my $resp = `$main::config->{'client'} -datadir=$main::config->{'datadir'} $command 2>&1`;

	my $eval = eval { decode_json($resp) };

	if (!$@) {

		return(decode_json($resp));
	}
}


###########################################################################################################################################################
#								
sub newkey {																# generate new hex string key

	my $length = $_[0] * 2;														# convert bytes to hex string length

	my @chars = ();

	my $key = '';

	@chars = ('a'..'f', '0'..'9');

	$key .= $chars[rand @chars] for 1..$length;			

	return($key);
}


###########################################################################################################################################################
#
sub int_to_hex {															# returns hex : uint32_le = &int_to_hex(integer, 32, 'r')

	my $places = $_[1] / 4;														# length of hex (bytes)

	my $template = "\%0$places" . 'x';												# template for sprintf conversion

	my $hex = sprintf("$template", $_[0]);												# convert integer to hex

	if ($_[2] eq 'r') {														# reverse byte order

		return(reverse_bytes($hex));
	}

	return($hex);															# given byte order
}


###########################################################################################################################################################
#
sub reverse_bytes {															# reverse byte order of hex-encoded string

	my $hex = '';

	my $bytes = length($_[0]);

	while ($bytes > 0) {

		$hex .= substr($_[0], ($bytes - 2), 2);

		$bytes -= 2;
	}

	return($hex);
}


###########################################################################################################################################################
#								
sub compact_size {															# generate compactSize string from integer (or hex-encoded data if $_[2] = 's'

	my $length;

	my $compact = '';

	if ($_[1] eq 's') {

		$length = length($_[0]) / 2;												# hex string, convert to length in bytes
	}

	else {																# integer 

		$length = $_[0];
	}

	if ($length < 253) {														# 8-bit

		$compact = sprintf("%02x", $length);

	        return($compact);
	}

	elsif ( ($length >= 253) && ($length <= 65535) ) {										# 16-bit, little-endian

		$compact = sprintf("%04x", $length);
		
		$compact = reverse_bytes($compact);

		return("fd$compact");
	}

	elsif ( ($length > 65556) && ($length <= 4294967295)) {										# 32-bit, little-endian

		$compact = sprintf("%08x", $length);

		$compact = reverse_bytes($compact);

		return("fe$compact");
	}
	else {																# 64-bit, little-endian

		$compact = sprintf("%016x", $length);

		$compact = reverse_bytes($compact);

		return("ff$compact");
	}
}


###########################################################################################################################################################
#	
sub merkleroot {															# generate merkleroot from array-ref of transaction ids

	my @hashes = ();

	foreach (@{$_[0]}) {														# dereference, data is hex-encoded

		push @hashes, $_;													# txids are little-endian
	}

	if ( (scalar @hashes) == 1 ) {													# if its an empty block (1 tx)

		return($hashes[0]);													# return coinbase txn hash as merkleroot
	}

	while ((scalar @hashes) > 1) {													# loop through array until there's only one value left

		if ( ((scalar @hashes) % 2) != 0 )  {											# duplicate last hash if there's an odd number

			push @hashes, $hashes[((scalar @hashes) - 1)];
		}

		my @joinedHashes;

		while (my @pair = splice @hashes, 0, 2) {										# get a pair of hashes

			push @joinedHashes, hash_this(reverse_bytes("$pair[1]$pair[0]"), 'le');						# get the hash
		}

		@hashes = @joinedHashes;												# replace hashes with joinedHashes
	}

	return($hashes[0]);														# returns hex-encoded big-endian
}


############################################################################################################################################################
#
sub new_block() {															# generate/refresh template for new block

	debug("new_block() : init");

	my $template = node_rpc('getblocktemplate');											# block template

	$block->{'sigops'} = 0;

	my @txid;															# array of transaction ids

	my @txraw;

	my $txn_data = $template->{'coinbasetxn'}->{'data'};										# coinbase transaction data

	push @txid, $template->{'coinbasetxn'}->{'hash'};										# coinbase txid

# TODO: max fees, sort by yoshis per Kb & do the big ones first
# TODO: anti-spam, sort by size & do the small ones first
# TODO: anti-span, ignore txns over a given size

	foreach my $tx ( @{$template->{'transactions'}} ) {										# append transactions

		last if ( ( (length($txn_data) / 2) + (length($tx->{'data'}) / 2) + (((scalar(@txid) / 2) * 32) + 600) ) > $block->{'sizelimit'} ); 	# block size limit (NB: header is 540 bytes, not 600)
	
		last if (($block->{'sigops'} + $tx->{'sigops'}) >= $block->{'sigoplimit'});						# sigops limit reached

		$block->{'sigops'} += $tx->{'sigops'};											# track sigops

		push @txid, $tx->{'hash'};												# add txid 

		$txn_data .= $tx->{'data'};												# add transaction data
	}

	$block->{'height'} = $template->{'height'};

	$block->{'merkleroot'} = reverse_bytes(merkleroot(\@txid));									# generate merkleroot of txids

	$block->{'transactions'} = compact_size( scalar(@txid) ) . $txn_data;								# compact size of transaction count & transaction raw data

	$block->{'target'} = $template->{'target'};											# target (NOT REVERSED)

	$block->{'version'} = int_to_hex($template->{'version'}, 32, 'r');								# version (REVERSED)

	$block->{'previousblockhash'} = reverse_bytes($template->{'previousblockhash'});						# previous block hash (REVERSED)

	$block->{'finalsaplingroothash'} = reverse_bytes($template->{'finalsaplingroothash'});						# sapling root (REVERSED)

	$block->{'curtime'} = int_to_hex($template->{'curtime'}, 32, 'r');								# timestamp from template, real time causes MTP bug

	$block->{'bits'} = reverse_bytes($template->{'bits'});										# bits (REVERSED)

	$block->{'txid'} = \@txid;													# arrayref of txids

	$block->{'txn_data'} = $txn_data;												# transaction data as hex-string


	foreach my $miner_id (keys %{$client}) {											# new nonce for all miners

		set_extranonce($miner_id);									
	}

	foreach my $miner_id (keys %{$client}) {											# new work to all miners

		notify($miner_id, 'true');									
	}
}


###########################################################################################################################################################
#	
sub hash_this {																# returns a hash as big endian (Usage: "hex-encoded-string", 'le|be')

	if ($_[1] eq 'le') {

		return(reverse_bytes(unpack("H*", sha256(sha256(pack "H*", $_[0])))));		
	}
	elsif ($_[1] eq 'be') {

		return(unpack("H*", sha256(sha256(pack "H*", $_[0]))));			
	}
}


###########################################################################################################################################################
#																	FUNCTION : compare hexstring hashes
sub check_difficulty {

	my @target = split(//, $_[0]);													# split into chars

	my @hash = split(//,$_[1]);

	foreach my $tgt (@target) {													# compare hashes char by char

		if (hex($hash[0]) == hex($tgt) ) {											# values are equal

			shift(@hash);													# move to next hash char
		}

		elsif (hex($hash[0]) > hex($tgt) ) {											# hash is higher, fail

			return(0);
		}

		else {															# hash is lower, success

			return(1);
		}
	}

	return(1);															# hash & target identical, never gonna happen			
}


###########################################################################################################################################################
#																	FUNCTION : local debugging
sub debug {

	my ($message) = @_;

	if ($debug) {

		print "solo : $message\n";
	}
}

1;
