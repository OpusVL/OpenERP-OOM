package OpenERP::OOM::Meta::Class::Trait::HasRelationship;
use Moose::Role;

has relationship => (
    isa     => 'HashRef',
    is      => 'rw',
    default => sub {{}},
);

1;