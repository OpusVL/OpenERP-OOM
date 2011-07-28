package OpenERP::OOM::Object::Base;

use 5.010;
use Carp;
use Data::Dumper;
use List::MoreUtils qw/uniq/;
use Moose;

extends 'Moose::Object';
with 'OpenERP::OOM::DynamicUtils';

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

sub BUILD {
    my $self = shift;
    
    # Add methods to follow links
    my $links = $self->meta->link;
    while (my ($name, $link) = each %$links) {
        given ($link->{type}) {
            when ('single') {
                $self->meta->add_method(
                    $name,
                    sub {
                        my $obj = shift;
                        $obj->{"_$name"} //= $obj->class->schema->link($link->{class})->retrieve($link->{args}, $obj->{$link->{key}});
                        
                        unless ($obj->{"_$name"}) {
                            # FIXME: If $obj->{"_$name"} is undefined, we have a data integrity problem.
                            # Either the linked data is missing, or the key in the OpenERP object is missing.
                            die "Error linking to OpenERP object" . $obj->id;
                        }
                        
                        $obj->{"_$name"}->meta->make_mutable;
                        $obj->{"_$name"}->meta->add_method(
                            '_source',
                            sub { return $obj }
                        );
                        
                        return $obj->{"_$name"};
                    }
                )
            }
            when ('multiple') {
                $self->meta->add_method(
                    $name,
                    sub {
                        return $self->class->schema->link($link->{class})->retrieve_list($link->{args}, $self->{$link->{key}});
                    }
                )
            }
        }
    }
}


#-------------------------------------------------------------------------------

=head1 METHODS

=head2 update

Updates an object in OpenERP after its properties have been changed.

 $obj->name('New name');
 $obj->update;

Also allows a hashref to be passed to update multiple properties:

 $obj->update({
    name  => 'new name',
    ref   => 'new reference',
    price => 'new price',
 });

=cut

sub update {
    my $self = shift;
    
    if (my $update = shift) {
        while (my ($param, $value) = each %$update) {
            $self->$param($value);
        }
    }
    
    my $object;
    foreach my $attribute ($self->meta->get_all_attributes) {
        # FIXME - This should only update properties that have been changed,
        # not all properties of the object
        next if ($attribute->name eq 'id');
        next if ($attribute->name =~ '^_');

        $object->{$attribute->name} = $self->{$attribute->name};
    }

    my $relationships = $self->meta->relationship;
    while (my ($name, $rel) = each %$relationships) {
        if ($object->{$rel->{key}}) {
            given ($rel->{type}) {
                when ('one2many') {
                    delete $object->{$rel->{key}};  # Don't update one2many relationships
                }
                when ('many2many') {
                    $object->{$rel->{key}} = [[6,0,$object->{$rel->{key}}]];
                }
                when ('many2one') {
                    # FIXME: Allow these relationships to be updated using the update()
                    # method as well as using the set_related() method
                }
            }
        }
    }

    # Force Str parameters to be object type RPC::XML::string
    foreach my $attribute ($self->meta->get_all_attributes) {
        if ($attribute->type_constraint eq 'Str') {
            if (exists $object->{$attribute->name}) {
                $object->{$attribute->name} = RPC::XML::string->new($object->{$attribute->name});
            }
        }
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
 
 $obj->update_single('name');  # Only the 'name' property is updated

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

    # Force Str parameters to be object type RPC::XML::string
    foreach my $attribute ($self->meta->get_all_attributes) {
        if ($attribute->type_constraint eq 'Str') {
            if ($attribute->name eq $property) {
                $value = RPC::XML::string->new($value);
            }
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
    
    warn "Creating related object $relation_name";
    warn "with initial data:";
    warn Dumper $object;
    
    if (my $relation = $self->meta->relationship->{$relation_name}) {
        given ($relation->{type}) {
            when ('one2many') {
                my $class = $self->meta->name;
                if ($class =~ m/(.*?)::(\w+)$/) {
                    my ($base, $name) = ($1, $2);
                    my $related_class = $base . "::" . $relation->{class};
                    
                    $self->ensure_class_loaded($related_class);
                    my $related_meta = $related_class->meta->relationship;
                    
                    my $far_end_relation;
                    REL: for my $key (keys %$related_meta) {
                        my $value = $related_meta->{$key};
                        if ($value->{class} eq $name) {
                            $far_end_relation = $key;
                            last REL;
                        }
                    }
                    
                    if ($far_end_relation) {
                        my $foreign_key = $related_meta->{$far_end_relation}->{key};
                        
                        warn "Far end relation exists";
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
        given ($relation->{type}) {
            when ('many2one') {
                $self->{$relation->{key}} = $object->id;
                $self->update_single($relation->{key});
            }
            when ('many2many') {
                $self->{$relation->{key}} = [$object->id];
                $self->update_single($relation->{key});
            }
            default {
                carp "Cannot use set_related() on a $_ relationship";
            }
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
