package CIF::Client;

use 5.011;
use strict;
use warnings;

use CIF qw/debug/;
use CIF::Message;
use CIF::Client::BrokerFactory;
use CIF::FormatFactory;
use CIF::EncoderFactory;
use CIF::ObservableFactory;

use Mouse;
use Time::HiRes qw(tv_interval gettimeofday);
use Config::Simple;
use Data::Dumper;
use Carp::Assert;

has 'broker'    => (
    is      => 'ro',
    reader  => 'get_broker',
);

has 'config'    => (
    is      => 'ro',
    isa     => 'Str',
    default => CIF::DEFAULT_CONFIG(),
);

has 'format_handle' => (
    is      => 'rw',
    reader  => 'get_format_handle',
    writer  => 'set_format_handle',
);

has 'format' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'table',
    reader  => 'get_format',
    writer  => 'set_format',
);

has 'results'   => (
    is      => 'rw',
    isa     => 'ArrayRef',
);

has 'Token' => (
    is      => 'ro',
    isa     => 'Str',
);

has 'encoder_handle' => (
    is      => 'ro',
    reader  => 'get_encoder_handle',
);

has 'encoder_pretty'    => (
    is      => 'ro',
    isa     => 'Bool',
    reader  => 'get_encoder_pretty',
);

around BUILDARGS => sub {
    my $orig    = shift;
    my $self    = shift;
    my $args    = shift;
    
    _init_config($args);
    
    $args->{'broker'}           = CIF::Client::BrokerFactory->new_plugin({ config => $args });
    $args->{'format_handle'}    = CIF::FormatFactory->new_plugin($args) if($args->{'format'});
    $args->{'encoder_handle'}   = CIF::EncoderFactory->new_plugin($args);
    
    return $self->$orig($args);
};

sub _init_config {
    my $args = shift;
    
    return unless($args->{'config'});
    return if(ref($args->{'config'}) eq 'HASH');
    die "config file doesn't exist: ".$args->{'config'} unless(-e $args->{'config'});
    $args->{'config'} = Config::Simple->new($args->{'config'})->get_block('client');
    $args = { %{$args->{'config'}},  %$args };
}

sub encode {
    my $self = shift;
    my $args = shift;
    
    return $self->get_encoder_handle()->encode({ 
        data => $args->{'data'}, encoder_pretty => $self->get_encoder_pretty() 
    });
}

sub decode {
    my $self = shift;
    my $data = shift;
    
    return $self->get_encoder_handle()->decode({ data => $data });
}

sub send {
    my $self = shift;
    my $msg  = shift;
    
    debug('encoding...');
    $msg = $self->encode({ data => $msg });
    debug('sending upstream...');

    $msg = $self->get_broker()->send($msg);

    debug('decoding...');
    $msg = $self->decode($msg);
    $msg = ${$msg}[0] if(ref($msg) && ref($msg) eq 'ARRAY');
    
    return $msg;
}  

sub ping {
    my $self = shift;
    my $args = shift;
    
    my $msg = CIF::Message->new({
        rtype   => 'ping',
        mtype   => 'request',
        Token   => $self->Token(),
    });
    my $ret = $self->send($msg);
    my $ts = $msg->{'Data'}->{'Timestamp'};
    return tv_interval([$ts]);
}

sub search {
    my $self = shift;
    my $args = shift;
    
    my $msg = CIF::Message->new({
        rtype       => 'search',
        mtype       => 'request',
        Token       => $args->{'Token'} || $self->Token(),
        Query       => $args->{'Query'},
        confidence  => $args->{'confidence'},
        limit       => $args->{'limit'},
        group       => $args->{'group'},
        Tags        => $args->{'Tags'},
    });
    
    $msg = $self->send($msg);
    my $stype = $msg->{'stype'} || $msg->{'@stype'};
    return $msg->{'Data'} if($stype eq 'failure');
    
    map { $_ = CIF::ObservableFactory->new_plugin($_) } (@{$msg->{'Data'}->{'Results'}});
    return (undef, $msg->{'Data'}->{'Results'});
}

sub submit {
    my $self = shift;
    my $args = shift;
    
    map { $_ = CIF::ObservableFactory->new_plugin($_) } (@{$args->{'Observables'}});
    
    my $msg = CIF::Message->new({
        rtype       => 'submission',
        mtype       => 'request',
        Token       => $args->{'Token'} || $self->Token(),
        Observables => $args->{'Observables'},
    });
    
    my $sent = ($#{$args->{'Observables'}} + 1);
    debug('sending: '.($sent));
    my $t = gettimeofday();
    $msg = $self->send($msg);
    $t = tv_interval([$t]);
    debug('took: ~'.$t);
    debug('rate: ~'.($sent/$t).' o/s');
    return $msg->{'Data'} if($msg->{'@stype'} eq 'failure');
    
    return (undef,$msg->{'Data'}->{'Results'});   
}

sub format {
    my $self = shift;
    my $args = shift;
    
    return '' unless(ref($args->{'data'}) eq 'ARRAY');
    return '' unless($#{$args->{'data'}} > -1);
    
    debug('formatting...');
    unless($self->get_format_handle()){
        assert($args->{'format'},'missing arg: format');
        $self->set_format_handle(CIF::FormatFactory->new_plugin($args));
    }
    return $self->get_format_handle()->process($args->{'data'});
}

sub shutdown {
    my $self = shift;
    if($self->get_broker()){
        $self->get_broker->shutdown();
    }
    return 1;
}    

sub DESTROY {
    my $self = shift;
    $self->shutdown();
}

__PACKAGE__->meta->make_immutable(inline_destructor => 0);    

1;