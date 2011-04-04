package OpenERP::OOM::Object::Base;

use 5.010;
use Carp;
use Data::Dumper;
use List::MoreUtils qw/uniq/;
use Moose;

extends 'Moose::Object';

=head1 NAME

OpenERP::OOM::Class::Base

=head1 SYNOPSYS

 my $obj = $schema->class('Name')->create(\%args);
 
 say $obj->id;
 
 $obj->name('New name');
 $obj->update;
 
 $obj->delete;

=head1 DESCRIPTION

Provides a base set of properties and methods for OpenERP::OOM objects (update, delete, etc).

=head1 PROPERTIES

=head2 id

Returns the OpenERP ID of an object.

 say $obj->id;

=cut

has 'id' => (
    isa => 'Int',
    is  => 'ro',
);


#-------------------------------------------------------------------------------

=head1 METHODS

=head2 update

Updates an object in OpenERP after its properties have been changed.

 $obj->name('New name');
 $obj->update;

=cut

sub update {
    my $self = shift;
    
    # FIXME - if an object is a key in a many2many relationship, change the
    # value to update to [[6,0,[@val]]]
    
    my $object;
    foreach my $attribute ($self->meta->get_all_attributes) {
        # FIXME - This should only update properties that have been changed,
        # not all properties of the object
        next if ($attribute->name eq 'id');
                
        # FIXME - Only direct (scalar) properties should be updated, not relationships
        next if ($attribute->name =~ '^_');
        next if ($attribute->name =~ 'address');  # FIXME - need way of updating relationships

        $object->{$attribute->name} = $self->{$attribute->name};
    }

    $self->class->schema->client->update($self->model, $self->id, $object);
    $self->refresh;
    
    return $self;
}


#-------------------------------------------------------------------------------

=head2 update_single

Updates OpenERP with a single property of an object.

 $obj->name('New name');
 $obj->status('Active');
 
 $obj->update('name');  # Only the 'name' property is updated

=cut

sub update_single {
    my ($self, $property) = @_;
    
    my $value = $self->{$property};
    
    # Check to see if the property is the key to a many2many relationship
    my $relationships = $self->meta->relationship;
    while (my ($name, $rel) = each %$relationships) {
        if ($rel->{type} eq 'many2many') {
            $value = [[6,0,$value]];
        }
    }
    
    $self->class->schema->client->update($self->model, $self->id, {$property => $value});
    return $self;
}

#-------------------------------------------------------------------------------

=head2 refresh

Reloads an object's properties from OpenERP.

 $obj->refresh;

=cut

sub refresh {
    my $self = shift;
    
    my $new = $self->class->retrieve($self->id);
    
    foreach my $attribute ($self->meta->get_all_attributes) {
        my $name = $attribute->name;
        $self->{$name} = ($new->$name);
    }
    
    return $self;
}


#-------------------------------------------------------------------------------

=head2 delete

Deletes an object from OpenERP.

 my $obj = $schema->class('Partner')->retrieve(60);
 $obj->delete;

=cut

sub delete {
    my $self = shift;
    
    $self->class->schema->client->delete($self->model, $self->id);
}


#-------------------------------------------------------------------------------

sub print {
    my $self = shift;
    
    say "Print called";
}


#-------------------------------------------------------------------------------

=head2 create_related

Creates a related or linked object.

 $obj->create_related('address',{
     street   => 'Drury Lane',
     postcode => 'CV21 3DE',
 });

=cut

sub create_related {
    my ($self, $relation_name, $object) = @_;
    
    #say "Creating related object $relation_name";
    #say "with initial data:";
    #say Dumper $object;
    
    if (my $relation = $self->meta->relationship->{$relation_name}) {
        given ($relation->{type}) {
            when ('one2many') {
                my $class = $self->meta->name;
                if ($class =~ m/(.*?)::(\w+)$/) {
                    my ($base, $name) = ($1, $2);
                    my $related_class = $base . "::" . $relation->{class};
                    
                    eval "use $related_class";
                    my $related_meta = $related_class->meta->relationship;
                    
                    my $far_end_relation;
                    REL: while (my ($key, $value) = each %$related_meta) {
                        #say "Searching for far-end relation $key";
                        if ($value->{class} eq $name) {
                            say "Found it";
                            $far_end_relation = $key;
                            last REL;
                        }
                    }
                    
                    if ($far_end_relation) {
                        my $foreign_key = $related_meta->{$far_end_relation}->{key};
                        
                        #say "Far end relation exists";
                        $self->class->schema->class($relation->{class})->create({
                            %$object,
                            $foreign_key => $self->id,
                        });
                        
                        $self->refresh;
                    } else {
                        my $new_object = $self->class->schema->class($relation->{class})->create($object);
                        
                        $self->refresh;
                        
                        unless (grep {$new_object->id} @{$self->{$relation->{key}}}) {
                            push @{$self->{$relation->{key}}}, $new_object->id;
                            $self->update;
                        }
                    }
                }
            }
            when ('many2many') {
                say "create_related many2many";
            }
            when ('many2one') {
                say "create_related many2one";
            }
        }
    } elsif ($relation = $self->meta->link->{$relation_name}) {
        given ($relation->{type}) {
            when ('single') {
                if (my $id = $self->class->schema->link($relation->{class})->create($relation->{args}, $object)) {
                    $self->{$relation->{key}} = $id;
                    $self->update;
                }
            }
            when ('multiple') {
                say "create_linked multiple";
            }
        }
    }
}


#-------------------------------------------------------------------------------

=head2 add_related

Adds a related or linked object to a one2many, many2many, or multiple relationship.

 my $partner  = $schema->class('Partner')->find(...);
 my $category = $schema->class('PartnerCategory')->find(...);
 
 $partner->add_related('category', $category);

=cut

sub add_related {
    my ($self, $relation_name, $object) = @_;

    if (my $relation = $self->meta->relationship->{$relation_name}) {
        given ($relation->{type}) {
            when ('one2many') {
                # FIXME - is this the same process as adding a many2many relationship?
            }
            when ('many2many') {
                push @{$self->{$relation->{key}}}, $object->id;
                $self->{$relation->{key}} = [uniq @{$self->{$relation->{key}}}];
                $self->update_single($relation->{key});
            }
        }
    } elsif ($relation = $self->meta->link->{$relation_name}) {
        given ($relation->{type}) {
            when ('multiple') {
                # FIXME - handle linked as well as related objects
            }
        }
    }
}


#-------------------------------------------------------------------------------

=head2 set_related

=cut

sub set_related {
    my ($self, $relation_name, $object) = @_;
    
    if (my $relation = $self->meta->relationship->{$relation_name}) {
        if ($relation->{type} eq 'many2one') {
            $self->{$relation->{key}} = $object->id;
            $self->update_single($relation->{key});
        } else {
            carp "Can only use set_related() on many2one relationships";
        }
    } else {
        carp "Relation '$relation_name' does not exist!";
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