package OpenERP::OOM::Class::Base;

use 5.010;
use Carp;
use Data::Dumper;
use Moose;

extends 'Moose::Object';

=head1 NAME

OpenERP::OOM::Class::Base

=head1 SYNOPSYS

 my $obj = $schema->class('Name')->create(\%args);
 
 foreach my $obj ($schema->class('Name')->search(@query)) {
    ...
 }

=head1 DESCRIPTION

Provides a base set of methods for OpenERP::OOM classes (search, create, etc).

=cut

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

=head2 search

Searches OpenERP and returns a list of objects matching a given query.

 my @list = $schema->class('Name')->search(
     ['name', 'ilike', 'OpusVL'],
     ['active', '=', 1],
 );

The query is formatted as a list of array references, each specifying a
column name, operator, and value. The objects returned will be those where
all of these sub-queries match.

=cut

sub search {
    my $self = shift;
    
    my $objects = $self->schema->client->search_detail($self->object_class->model,[@_]);
    
    return map {$self->object_class->new($_)} @$objects;
}


#-------------------------------------------------------------------------------

=head2 find

Returns the first object matching a given query.

 my $obj = $schema->class('Name')->find(['id', '=', 32]);

Will return C<undef> if no objects matching the query are found.

=cut

sub find {
    my $self = shift;
    
    my $ids = $self->schema->client->search($self->object_class->model,[@_]);
    
    if ($ids->[0]) {
        return $self->retrieve($ids->[0]);
    }
}


#-------------------------------------------------------------------------------

=head2 retrieve

Returns an object by ID.

 my $obj = $schema->class('Name')->retrieve(32);

=cut

sub retrieve {
    my ($self, $id) = @_;
    
    # FIXME - This should probably be in a try/catch block
    if (my $object = $self->schema->client->read_single($self->object_class->model, $id)) {
        return $self->object_class->new($object);
    }
}


#-------------------------------------------------------------------------------

=head2 retrieve_list

Takes a reference to a list of object IDs and returns a list of objects.

 my @list = $schema->class('Name')->retrieve_list([32, 15, 60]);

=cut

sub retrieve_list {
    my ($self, $ids) = @_;
    
    if (my $objects = $self->schema->client->read($self->object_class->model, $ids)) {
        return map {$self->object_class->new($_)} @$objects;
    }
}


#-------------------------------------------------------------------------------

=head2 create

Creates a new instance of an object in OpenERP.

 my $obj = $schema->class('Name')->create({
     name   => 'OpusVL',
     active => 1,
 });

Takes a hashref of object parameters.

Returns the new object or C<undef> if it could not be created.

=cut

sub create {
    my ($self, $object_data) = @_;

    #carp "Create called with initial object data: ";
    #say Dumper $object_data;
    
    # Check for relationships in the object data
    #say "Looking for relationships in ".$self->object_class;
    my $relationships = $self->object_class->meta->relationship;
    while (my ($name, $rel) = each %$relationships) {
        #say "Testing for relationship $name";
        if ($rel->{type} eq 'one2many') {
            #say "one2many";
            if ($object_data->{$name}) {
                #say "Found object data";
                #say "Setting key " . $rel->{key} . " to " . $object_data->{$name}->id;
                $object_data->{$rel->{key}} = $object_data->{$name}->id;
                delete $object_data->{$name};
            }
        }
        
        if ($rel->{type} eq 'many2one') {
            #say "many2one";
            if ($object_data->{$name}) {
                #say "Found object data";
                #say "Setting key " . $rel->{key} . " to " . $object_data->{$name}->id;
                $object_data->{$rel->{key}} = $object_data->{$name}->id;
                delete $object_data->{$name};
            }            
        }
    }
    
    #say "Creating object in class: " . $self->object_class;
    #say Dumper $object_data;
    
    if (my $id = $self->schema->client->create($self->object_class->model, $object_data)) {
        return $self->retrieve($id);
    }
}


#-------------------------------------------------------------------------------

=head1 AUTHOR

Jon Allen (JJ) - L<jj@opusvl.com>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2010 Opus Vision Limited

This software is licensed according to the "IP Assignment Schedule"
provided with the development project.

=cut

1;