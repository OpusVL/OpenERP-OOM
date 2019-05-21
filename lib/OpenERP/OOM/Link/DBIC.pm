package OpenERP::OOM::Link::DBIC;

# ABSTRACT: Provides a basic link into a DBIC schema

=head1 DESCRIPTION

If you do not provide your own C<link_provider> when you create your
L<OpenERP::OOM::Schema>, this class will be used by default whenever you create
a link whose C<class> is C<DBIC>.

It provides a very simple interface into a DBIC schema by assuming every class
in your schema has a single-column primary key. This PK value is stored against
the configured column in the OpenERP object, typically C<x_dbic_link_id>.

This is where the C<key> property ends up, from
L<OpenERP::OOM::Object/has_link>.

=head1 PROPERTIES

See also L<OpenERP::OOM::Roles::DefaultLink> for inherited properties.

=head2 dbic_schema

This is the DBIC Schema object.  If you need a generic DBIC schema object
this is normally the simplest way to access it.

=head1 METHODS

See L<OpenERP::OOM::Roles::Link> for methods.

All return values are DBIC row objects (or arrayrefs thereof).

=cut

use 5.010;
use Moose;
use Try::Tiny;
with 'OpenERP::OOM::Roles::Link',
     'OpenERP::OOM::Roles::DefaultLink',
     'OpenERP::OOM::DynamicUtils';

has 'dbic_schema' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_dbic_schema',
);

sub _build_dbic_schema {
    my $self = shift;

    $self->ensure_class_loaded($self->config->{schema_class});

    return $self->config->{schema_class}->connect(@{$self->config->{connect_info}});
}

sub create {
    my ($self, $args, $data) = @_;

    try {
        my $object = $self->dbic_schema->resultset($args->{class})->create($data);
        ### Created linked object with ID $object->id
        return $object->id;
    } catch {
        die "Could not create linked object: $_";
    };
}

sub retrieve {
    my ($self, $args, $id) = @_;

    if (my $object = $self->dbic_schema->resultset($args->{class})->find($id)) {
        return $object;
    }
    return;
}

sub retrieve_list {
    my ($self, $args, $ids) = @_;

    # Note we do not support a compound PK. That behaviour would require a
    # custom class that serialises the PK into OpenERP and deserialises it for
    # search.
    my $RS = $self->dbic_schema->resultset($args->{class});
    my ($pk) = $rs->result_source->primary_columns;

    my $rs = $RS->search({ $pk => { -in => $ids } });
    return [$rs->all];
}

1;
