package OpenERP::OOM::Link::DBIC;

use 5.010;
use Moose;
extends 'OpenERP::OOM::Link';

has 'dbic_schema' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_dbic_schema',
);

sub _build_dbic_schema {
    my $self = shift;
    
    eval "use " . $self->config->{schema_class};
    
    return $self->config->{schema_class}->connect(@{$self->config->{connect_info}});
}


#-------------------------------------------------------------------------------

sub create {
    my ($self, $args, $data) = @_;
    
    say "create called";
    
    if (my $object = $self->dbic_schema->resultset($args->{class})->create($data)) {
        return $object->id;
    }
}


#-------------------------------------------------------------------------------

sub retrieve {
    my ($self, $args, $id) = @_;
    
    say "retrieve called with class $class";
    
    if (my $object = $self->dbic_schema->resultset($args->{class})->find($id)) {
        return $object;
    }
}


#-------------------------------------------------------------------------------

1;