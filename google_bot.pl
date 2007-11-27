#!/usr/bin/perl


our $VERSION = '.01'; # Still in development but can give an idea.


# Replace username and password

# Messages and their replies
my %mes = ('hi'=> 'Hello',
	'what is your name' => 'Enter here your name',	
	'u there?'=> 'No i am not ',
	'u there'=> 'No i am not ',

);

# Crude script - Abhishek jain - contact him for more information 



###############################################################################
# Modified XMPPClient Example originally by Nicholas Perez 2006, 2007. 
# 
#LICENSE: Please see the included Readme file for details
#
# This example client script, instantiates a single PCJ object, connects to a 
# remote server, sends presence and answers any incomming messages automatically
#                          
###############################################################################
$|=1;
use Filter::Template; 						#this is only a shortcut
const XNode POE::Filter::XML::Node

use warnings;
use strict;
use XML::Simple;
use POE::Filter::XML::Utils;

use POE; 									#include POE constants
use POE::Component::Jabber; 				#include PCJ
use	POE::Component::Jabber::Error; 			#include error constants
use	POE::Component::Jabber::Status; 		#include status constants
use	POE::Component::Jabber::ProtocolFactory;#include connection type constants
use POE::Filter::XML::Node; 				#include to build nodes
use POE::Filter::XML::NS qw/ :JABBER :IQ /; #include namespace constants
use POE::Filter::XML::Utils; 				#include some general utilites
use Carp;

# First we create our own session within POE to interact with PCJ
POE::Session->create(
	options => { debug => 0, trace => 0},
	inline_states => {
		_start =>
			sub
			{
				my ($kernel, $heap) = @_[KERNEL, HEAP];
				$kernel->alias_set('Tester');
				
				# our PCJ instance is a fullblown object we should store
				# so we can access various bits of data during use
				
				$heap->{'component'} = 
					POE::Component::Jabber->new(
						IP => 'talk.google.com',
						Port => '5222',
						Hostname => 'gmail.com',
						Username => 'username@gmail.com',
						Password => 'password',
						Alias => 'COMPONENT',

				# Shown below are the various connection types included
				# from ProtocolFactory:
				#
				# 	LEGACY is for pre-XMPP/Jabber connections
				# 	XMPP is for XMPP1.0 compliant connections
				# 	JABBERD14_COMPONENT is for connecting as a service on the
				# 		backbone of a jabberd1.4.x server
				# 	JABBERD20_COMPONENT is for connecting as a service on the
				# 		backbone of a jabberd2.0.x server

						#ConnectionType => +LEGACY,
						ConnectionType => +XMPP,
						#ConnectionType => +JABBERD14_COMPONENT,
						#ConnectionType => +JABBERD20_COMPONENT,
						Debug => '1',

				# Here is where we define our states for PCJ to use when
				# sending us information from the server. It automatically
				# infers the instantiating session much like a Wheel does.
				# StateParent is optional unless you want another session
				# to receive events from PCJ

						#StateParent => 'Tester',
						States => {
							StatusEvent => 'status_event',
							InputEvent => 'input_event',
							ErrorEvent => 'error_event',
						}
					);
				
				# At this point, PCJ is instatiated and hooked up to POE. In
				# 1.x, upon instantiation connect was immedately called. This
				# is not the case anymore with 2.x. This allows for a pool of 
				# connections to be setup and executed when needed.

				$kernel->post('COMPONENT', 'connect');
				
			},

		_stop =>
			sub
			{
				my $kernel = $_[KERNEL];
				$kernel->alias_remove();
			},

		input_event => \&input_event,
		error_event => \&error_event,
		status_event => \&status_event,
		test_message => \&test_message,
		output_event => \&output_event,
		reply => \&reply,
				
	}
);

# The status event receives all of the various bits of status from PCJ. PCJ
# sends out numerous statuses to inform the consumer of events of what it is 
# currently doing (ie. connecting, negotiating TLS or SASL, etc). A list of 
# these events can be found in PCJ::Status.

sub status_event()
{
	my ($kernel, $sender, $heap, $state) = @_[KERNEL, SENDER, HEAP, ARG0];
	
	# In the example we only watch to see when PCJ is finished building the
	# connection. When PCJ_INIT_FINISHED occurs, the connection ready for use.
	# Until this status event is fired, any nodes sent out will be queued. It's
	# the responsibility of the end developer to purge the queue via the 
	# purge_queue event.

	if($state == +PCJ_INIT_FINISHED)
	{	
		# Notice how we are using the stored PCJ instance by calling the jid()
		# method? PCJ stores the jid that was negotiated during connecting and 
		# is retrievable through the jid() method

		my $jid = $heap->{'component'}->jid();
		print "INIT FINISHED! \n";
		print "JID: $jid \n";
		print "SID: $sender->ID() \n\n";
		$heap->{'jid'} = $jid;
		$heap->{'sid'} = $sender->ID();
	
		$kernel->post('COMPONENT', 'output_handler', XNode->new('presence'));
		
		# And here is the purge_queue. This is to make sure we haven't sent
		# nodes while something catastrophic has happened (like reconnecting).
		
		$kernel->post('COMPONENT', 'purge_queue');

		for(1..10)
		{
#			$kernel->delay_add('test_message', int(rand(10)));
		}
	}

	print "Status received: $state \n";

}

# This is the input event. We receive all data from the server through this
# event. ARG0 will a POE::Filter::XML::Node object.

sub input_event()
{
	my ($kernel, $heap, $node) = @_[KERNEL, HEAP, ARG0];
	
	print "\n===PACKET RECEIVED===\n";
	print $node->to_str() . "\n";
	print "=====================\n\n";
	$kernel->yield('reply',$node);
		
}
sub reply(){
 my ($kernel, $heap,$node_in) = @_[KERNEL, HEAP,ARG0];

my $new_node = get_reply($node_in);

my $n = $new_node->get_tag('body');

my $data = lc $n->data() if $n;
$n->detach() if ($n);
my $rep = $mes{$data}||'Default message';


$new_node->insert_tag('body')->data($rep) if $n;

        $new_node->attr('from',$heap->{'jid'});

        $kernel->yield('output_event', $new_node, $heap->{'sid'});# if $new_node->get_attrs()->{type} eq 'chat';



}

# This is our own output_event that is a simple passthrough on the way to
# post()ing to PCJ's output_handler so it can then send the Node on to the
# server

sub output_event()
{
	my ($kernel, $heap, $node, $sid) = @_[KERNEL, HEAP, ARG0, ARG1];
	
	print "\n===PACKET SENT===\n";
	print $node->to_str() . "\n";
	print "=================\n\n";
	
	$kernel->post($sid, 'output_handler', $node);
}

# This is the error event. Any error conditions that arise from any point 
# during connection or negotiation to any time during normal operation will be
# send to this event from PCJ. For a list of possible error events and exported
# constants, please see PCJ::Error

sub error_event()
{
	my ($kernel, $sender, $heap, $error) = @_[KERNEL, SENDER, HEAP, ARG0];

	if($error == +PCJ_SOCKETFAIL)
	{
		my ($call, $code, $err) = @_[ARG1..ARG3];
		print "Socket error: $call, $code, $err\n";
		print "Reconnecting!\n";
		$kernel->post($sender, 'reconnect');
	
	} elsif($error == +PCJ_SOCKETDISCONNECT) {
		
		print "We got disconneted\n";
		print "Reconnecting!\n";
		$kernel->post($sender, 'reconnect');
	
	} elsif($error == +PCJ_CONNECTFAIL) {

		print "Connect failed\n";
		print "Retrying connection!\n";
		$kernel->post($sender, 'reconnect');
	
	} elsif ($error == +PCJ_SSLFAIL) {

		print "TLS/SSL negotiation failed\n";

	} elsif ($error == +PCJ_AUTHFAIL) {

		print "Failed to authenticate\n";

	} elsif ($error == +PCJ_BINDFAIL) {

		print "Failed to bind a resource\n";
	
	} elsif ($error == +PCJ_SESSIONFAIL) {

		print "Failed to establish a session\n";
	}
}
	
POE::Kernel->run();


__END__

=head1 NAME

Google Bot - autoresponder on google talk

=head1 SYNOPSIS
perl google_bot.pl

=head1 DESCRIPTION
Replace the various variables namely username and password and execute the script.

Uses POE, in case you are rookie to POE contact Abhishek jain , he generally have time to help guys on Perl and POE.

Abhishek wont mind been contacted.

Virus free , Spam Free , Spyware Free Software and hopefully Money free software .



=head1 AUTHOR

<Abhishek jain>
goyali at cpan.org

=head1 SEE ALSO
In case you need to implement this script on production and need expert help contact abhishek jain .
=cut