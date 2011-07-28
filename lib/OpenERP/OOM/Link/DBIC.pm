package OpenERP::OOM::Link::DBIC;

use 5.010;
use Moose;
extends 'OpenERP::OOM::Link';
with 'OpenERP::OOM::DynamicUtils';

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


#-------------------------------------------------------------------------------

sub create {
    my ($self, $args, $data) = @_;
    
    if (my $object = $self->dbic_schema->resultset($args->{class})->create($data)) {
        return $object->id;
    }
}


#-------------------------------------------------------------------------------

sub retrieve {
    my ($self, $args, $id) = @_;
    
    if (my $object = $self->dbic_schema->resultset($args->{class})->find($id)) {
        return $object;
    }
}


#-------------------------------------------------------------------------------

sub search {
    my ($self, $args, $search, $options) = @_;
    
    # FIXME - Foreign primary key column is hard-coded to "id"
    return map {$_->id} $self->dbic_schema->resultset($args->{class})->search($search, $options)->all;
}


#-------------------------------------------------------------------------------

1;
