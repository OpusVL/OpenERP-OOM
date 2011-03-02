package OpenERP::OOM::Schema;

use 5.010;
use Moose;
use OpenERP::XMLRPC::Client;

has 'openerp_connect' => (
    isa => 'HashRef',
    is  => 'ro',
);

has 'link_config' => (
    isa => 'HashRef',
    is  => 'ro',
);

has 'client' => (
    isa     => 'OpenERP::XMLRPC::Client',
    is      => 'ro',
    lazy    => 1,
    builder => '_build_client',
);


#-------------------------------------------------------------------------------

sub _build_client {
    my $self = shift;
    
    return OpenERP::XMLRPC::Client->new(%{$self->openerp_connect});
}


#-------------------------------------------------------------------------------

sub class {
    my ($self, $class) = @_;
    
    my $package = $self->meta->name . "::Class::$class";
    
    eval "use $package";
    
    return $package->new(
        schema => $self,
    );
}


#-------------------------------------------------------------------------------

sub link {
    my ($self, $class) = @_;
    
    my $package = ($class =~ /^\+/) ? $class : "OpenERP::OOM::Link::$class";

    eval "use $package";
    
    return $package->new(
        schema => $self,
        config => $self->link_config->{$class},
    );
}

1;