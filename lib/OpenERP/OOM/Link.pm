package OpenERP::OOM::Link;
use Moose;

has 'schema' => (
    is => 'ro',
);

has 'config' => (
    isa => 'HashRef',
    is  => 'ro',
);

1;