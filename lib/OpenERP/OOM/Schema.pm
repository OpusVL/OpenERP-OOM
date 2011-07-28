package OpenERP::OOM::Schema;

use 5.010;
use Moose;
use OpenERP::XMLRPC::Client;

with 'OpenERP::OOM::DynamicUtils';
with 'OpenERP::OOM::Link::Provider';

has 'openerp_connect' => (
    isa => 'HashRef',
    is  => 'ro',
);

has 'link_config' => (
    isa => 'HashRef',
    is  => 'ro',
);

has link_provider => (
    isa => 'OpenERP::OOM::Link::Provider',
    is => 'ro',
    lazy_build => 1,
);

has 'client' => (
    isa     => 'OpenERP::XMLRPC::Client',
    is      => 'ro',
    lazy    => 1,
    builder => '_build_client',
);

sub _build_link_provider
{
    # we are also a link provider
    # so use that if one isn't provided.
    my $self = shift;
    return $self;
}

#-------------------------------------------------------------------------------

sub _build_client {
    my $self = shift;
    
    return OpenERP::XMLRPC::Client->new(%{$self->openerp_connect});
}


#-------------------------------------------------------------------------------

sub class {
    my ($self, $class) = @_;
    
    my $package = $self->meta->name . "::Class::$class";
    
    $self->ensure_class_loaded($package);
    
    return $package->new(
        schema => $self,
    );
}


#-------------------------------------------------------------------------------

sub link 
{
    my ($self, $class) = @_;

    return $self->link_provider->provide_link($class);
}

sub provide_link {
    my ($self, $class) = @_;
    
    my $package = ($class =~ /^\+/) ? $class : "OpenERP::OOM::Link::$class";

    $self->ensure_class_loaded($package);
    
    return $package->new(
        schema => $self,
        config => $self->link_config->{$class},
    );
}

1;
