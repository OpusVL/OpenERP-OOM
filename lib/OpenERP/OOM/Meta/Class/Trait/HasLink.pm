package OpenERP::OOM::Meta::Class::Trait::HasLink;
use Moose::Role;

has link => (
    isa     => 'HashRef',
    is      => 'rw',
    default => sub {{}},
);

1;