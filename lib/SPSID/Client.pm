# Simple JSON-RPC 2.0 client for SPSID communicatoin.

package SPSID::Client;

use JSON;
use LWP::UserAgent;
use HTTP::Request;
use URI;
use Getopt::Long;

use Moose;


has 'url' =>
    (
     is  => 'rw',
     isa => 'Str',
     required => 1,
    );
    
has 'ua' =>
    (
     is  => 'rw',
     isa => 'Object',
    );

has _next_id => (
    is      => 'ro',
    isa     => 'CodeRef',
    lazy    => 1,
    default => sub {
        my $id = 0;
        sub { ++$id };
    },
);



sub BUILD
{
    my $self = shift;

    if( not defined($self->ua) ) {
        my $ua = LWP::UserAgent->new;
        $ua->timeout(10);
        $ua->env_proxy;
        $self->ua($ua);
    }
    
    return;
}


sub new_from_getopt
{
    my $url;
    my $realm;
    my $username;
    my $password;

    my $p = new Getopt::Long::Parser;
    $p->configure(pass_through => 1);
    if( not $p->getoptions('url=s'   => \$url,
                           'realm=s' => \$realm,
                           'user=s'  => \$username,
                           'pw=s'    => \$password) ) {
        die('Cannot parse command-line options');
    }

    die('--url option is required') unless defined($url);
    
    my $uri = URI->new($url);
    die('Cannot parse URL: ' . $url) unless defined $uri;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;

    if( defined($realm) or defined($username) or defined($password) ) {
        if( defined($realm) and defined($username) and defined($password) ) {
            $ua->credentials($uri->host_port, $realm, $username, $password);
        }
        else {
            die('Realm, user, and password are required at the same time');
        }
    }

    return SPSID::Client->new('url' => $url, 'ua' => $ua);
}


sub getopt_help_string
{
    return join("\n",
                "--url=URL      SPSID RPC location",
                "--realm=X      HTTP authentication realm",
                "--user=X       HTTP authentication user",
                "--pw=X         HTTP authentication password");
}
            
    
    


sub _call
{
    my $self = shift;
    my $method = shift;
    my $params = shift;

    my $req = HTTP::Request->new( 'POST', $self->url );    
    $req->header( 'Content-Type' => 'application/json' );
    $req->content( encode_json
                   ({'jsonrpc' => '2.0',
                     'id'      => $self->_next_id->(),
                     'method'  => $method,
                     'params'  => $params}));

    my $reponse = $self->ua->request($req);

    die($response->status_line) unless $response->is_success;

    my $result = decode_json($response->decoded_content);
    die('Cannot parse responce') unless defined($result);
    
    die('Missing version 2.0 in RPC response') unless
        (defined($result->{'jsonrpc'}) and $result->{'jsonrpc'} eq '2.0');

    if( defined($result->{'error'}) ) {
        die('JSON-RPC error ' . $result->{'error'}{'code'} . ': ' .
            $result->{'error'}{'message'});
    }

    return $result->{'result'};
}





sub create_object
{
    my $self = shift;
    my $objclass = shift;
    my $attr = shift;

    return $self->_call('create_object', {'objclass' => $objclass,
                                          'attr' => $attr});
}



# modify or add or delete attributes of an object

sub modify_object
{
    my $self = shift;
    my $id = shift;
    my $mod_attr = shift;
    
    $self->_call('modify_object', {'id' => $id,
                                   'mod_attr' => $mod_attr});
    return;
}



sub delete_object
{
    my $self = shift;
    my $id = shift;

    $self->_call('delete_object', {'id' => $id});
    return;
}


sub get_object
{
    my $self = shift;
    my $id = shift;

    return $self->_call('delete_object', {'id' => $id});
}


# input: attribute names and values for AND condition
# output: arrayref of objects found

sub search_objects
{
    my $self = shift;
    my $container = shift;
    my $objclass = shift;

    my $arg = {'container' => $container,
               'objclass' => $objclass};
    if( scalar(@_) > 0 ) {
        $arg->{'search_attrs'} = [ @_ ];
    }
        
    return $self->_call('search_objects', $arg);
}


sub contained_classes
{
    my $self = shift;
    my $container = shift;

    return $self->_call('contained_classes', {'container' => $container});
}




sub ping
{
    my $self = shift;

    my $r = $self->_call('ping', {'echo' => 'blahblah'});
    die('Ping RPC call returned wrong response')
        unless $r->{'echo'} ne 'blahblah';
    return;
}


1;



# Local Variables:
# mode: cperl
# indent-tabs-mode: nil
# cperl-indent-level: 4
# cperl-continued-statement-offset: 4
# cperl-continued-brace-offset: -4
# cperl-brace-offset: 0
# cperl-label-offset: -2
# End: