package OpenERP::OOM::Object::Base;

use 5.010;
use Moose;

extends 'Moose::Object';

has 'id' => (
    isa => 'Int',
    is  => 'ro',
);


#-------------------------------------------------------------------------------

sub update {
    my $self = shift;
    
    my $object;
    foreach my $attribute ($self->meta->get_all_attributes) {
        next if ($attribute->name eq 'id');
        next if ($attribute->name =~ '^_');
        next if ($attribute->name =~ 'address');  # FIXME

        $object->{$attribute->name} = $self->{$attribute->name};
    }

    use Data::Dumper;
    say Dumper $object;

    $self->class->schema->client->update($self->model, $self->id, $object);
}


#-------------------------------------------------------------------------------

sub refresh {
    my $self = shift;
    
    my $new = $self->class->retrieve($self->id);
    
    foreach my $attribute ($self->meta->get_all_attributes) {
        my $name = $attribute->name;
        $self->{$name} = ($new->$name);
    }
}


#-------------------------------------------------------------------------------

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

sub create_related {
    my ($self, $relation_name, $object) = @_;
    
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
                        if ($value->{class} = $name) {
                            $far_end_relation = $key;
                            last REL;
                        }
                    }
                    
                    if ($far_end_relation) {
                        my $foreign_key = $related_meta->{$far_end_relation}->{key};
                        
                        $self->class->schema->class($relation->{class})->create({
                            %$object,
                            $foreign_key => $self->id,
                        });
                        
                        $self->refresh;
                    } else {
                        my $new_object = $self->class->schema->class($relation->{class})->create($object);
                        
                        push @{$self->{$relation->{key}}}, $new_object->id;
                        $self->update;
                    }
                }
            }
            when ('many2many') {
                say "many2many";
            }
            when ('many2one') {
                say "many2one";
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
                
            }
        }
    }
}


#-------------------------------------------------------------------------------

1;