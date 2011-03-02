package OpenERP::OOM::Class;

use 5.010;
use Moose;
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    with_meta => ['object_type'],
    also      => 'Moose',
);

sub init_meta {
    shift;
    return Moose->init_meta( @_, base_class => 'OpenERP::OOM::Class::Base' );
}

sub object_type {
    my ($meta, $name, %options) = @_;
    
    $meta->add_attribute(
        'object',
        isa     => 'Str',
        is      => 'ro',
        default => sub {$name},
    );
}

1;