package OpenERP::OOM::Class::Base;

use 5.010;
use Moose;

extends 'Moose::Object';

has 'schema' => (
    is => 'ro',
);

has 'object_class' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_object_class',
);

sub _build_object_class {
    my $self = shift;
    
    eval "use " . $self->object;
    
    $self->object->meta->add_method('class' => sub{return $self});
    
    return $self->object->new;
}

#-------------------------------------------------------------------------------

sub search {
    my $self = shift;
    
    my $objects = $self->schema->client->search_detail($self->object_class->model,[@_]);
    
    return map {$self->object_class->new($_)} @$objects;
}


#-------------------------------------------------------------------------------

sub retrieve {
    my ($self, $id) = @_;
    
    if (my $object = $self->schema->client->read_single($self->object_class->model, $id)) {
        return $self->object_class->new($object);
    }
}


#-------------------------------------------------------------------------------

sub retrieve_list {
    my ($self, $ids) = @_;
    
    if (my $objects = $self->schema->client->read($self->object_class->model, $ids)) {
        return map {$self->object_class->new($_)} @$objects;
    }
}


#-------------------------------------------------------------------------------

sub create {
    my ($self, $object_data) = @_;
    
    if (my $id = $self->schema->client->create($self->object_class->model, $object_data)) {
        return $self->retrieve($id);
    }
}


#-------------------------------------------------------------------------------

1;