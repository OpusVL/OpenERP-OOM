package OpenERP::OOM::Object;

use 5.010;
use Carp;
use Moose;
use Moose::Exporter;
use Moose::Util::MetaRole;
use Moose::Util::TypeConstraints;

#-------------------------------------------------------------------------------

# Set up a subtype for many2one relationships. On object retrieval, OpenERP
# presents this relationship as an array reference holding the ID and the name
# of the related object, e.g.
#
#   [ 1, 'Related object name' ]
#
# However, when updating the object OpenERP expects this to be presented back
# as a single integer containing the related object ID.

subtype 'OpenERP::OOM::Type::Many2One'
    => as 'Maybe[Int]';

coerce 'OpenERP::OOM::Type::Many2One'
    => from 'ArrayRef'
    => via { $_->[0] };
    

#-------------------------------------------------------------------------------

# Export the 'openerp_model' and 'relationship' methods

Moose::Exporter->setup_import_methods(
    with_meta => ['openerp_model', 'relationship', 'has_link'],
    also      => 'Moose',
);


#-------------------------------------------------------------------------------

sub init_meta {
    shift;
    my %args = @_;
    
    Moose->init_meta( %args, base_class => 'OpenERP::OOM::Object::Base' );
    
    Moose::Util::MetaRole::apply_metaroles(
        for             => $args{for_class},
        class_metaroles => {
            class => [
                'OpenERP::OOM::Meta::Class::Trait::HasRelationship',
                'OpenERP::OOM::Meta::Class::Trait::HasLink',
            ],
            attribute => ['OpusVL::MooseX::TrackDirty::Attributes::Role::Meta::Attribute'],
        },
    );

    Moose::Util::MetaRole::apply_base_class_roles( 
        for_class => $args{for_class}, 
        roles     => ['OpusVL::MooseX::TrackDirty::Attributes::Role::Class'],
    );

}


#-------------------------------------------------------------------------------

sub openerp_model {
    my ($meta, $name, %options) = @_;
    
    $meta->add_method(
        'model',
        sub {return $name},
    );
}


#-------------------------------------------------------------------------------

sub relationship {
    my ($meta, $name, %options) = @_;
    
    #carp "Adding relationship $name";
    
    $meta->relationship({
        %{$meta->relationship},
        $name => \%options
    });
    
    #say "Adding hooks";
    
    given ($options{type}) {
        when ('many2one') {
            goto &_add_rel2one;
        }
        when ('one2many') {
            goto &_add_rel2many;
        }
        when ('many2many') {
            goto &_add_rel2many;
        }
    }
}


#-------------------------------------------------------------------------------

sub _add_rel2many {
    my ($meta, $name, %options) = @_;
    
    $meta->add_attribute(
        $options{key},
        isa => 'ArrayRef',
        is  => 'rw',
    );
    
    $meta->add_method(
        $name,
        sub {
            my ($self, @args) = shift;
            my $field_name = $options{key};
            if(@args)
            {
                my @ids;
                if(ref $args[0] eq 'ARRAY')
                {
                    # they passed in an arrayref.
                    # i.e. $obj->rel([ $obj1, $obj2 ]);
                    my $objects = $args[0];
                    @ids = map { $_->id } @$objects;
                }
                else
                {
                    # assume they passed each object in as an arg
                    # i.e. $obj->rel($obj1, $obj2);
                    @ids = map { $_->id } @args;
                }
                $self->$field_name(\@ids);
                return unless defined wantarray; # avoid needless retrieval
            }
            return $self->class->schema->class($options{class})->retrieve_list($self->{$field_name});
        },
    );
}


#-------------------------------------------------------------------------------

sub _add_rel2one {
    my ($meta, $name, %options) = @_;

    my $field_name = $options{key};
    $meta->add_attribute(
        $field_name,
        isa    => 'OpenERP::OOM::Type::Many2One',
        is     => 'rw',
        coerce => 1,
    );
    
    $meta->add_method(
        $name,
        sub {
            my $self = shift;
            if(@_)
            {
                my $val = shift;
                $self->$field_name($val->id);
                return unless defined wantarray; # avoid needless retrieval
            }
            return $self->class->schema->class($options{class})->retrieve($self->{$options{key}});
        },
    );
}


#-------------------------------------------------------------------------------

sub has_link {
    my ($meta, $name, %options) = @_;
    
    $meta->link({
        %{$meta->link},
        $name => \%options
    });
    
    given ($options{type}) {
        when ('single') {
            goto &_add_link_single;
        }
        when ('multiple') {
            goto &_add_link_multiple;
        }
    }
}


#-------------------------------------------------------------------------------

sub _add_link_single {
    my ($meta, $name, %options) = @_;
    
    $meta->add_attribute(
        $options{key},
        isa => 'Int',
        is  => 'ro',
    );
    
    #$meta->add_method(
    #    $name,
    #    sub {
    #        my $self = shift;
    #
    #        # FIXME - this is a bit broken, remembers between different objects!
    #        # Looks like the method is being added to the whole class, not the individual object
    #        # Maybe this code needs to go in Base.pm instead, in an "around create{...}" block
    #        # to add these methods in when a new object is created.
    #        state $link = $self->class->schema->link($options{class})->retrieve($options{args}, $self->{$options{key}});
    #    
    #        $link->meta->make_mutable;
    #        $link->meta->add_method(
    #            '_source',
    #            sub { return $self }
    #        );
    #        
    #        return $link;
    #    },
    #);
}


#-------------------------------------------------------------------------------

sub _add_link_multiple {
    my ($meta, $name, %options) = @_;
    
    $meta->add_attribute(
        $options{key},
        isa => 'ArrayRef',
        is  => 'ro',
    );
    
    #$meta->add_method(
    #    $name,
    #    sub {
    #        my $self = shift;
    #        return $self->class->schema->link($options{class})->retrieve_list($options{args}, $self->{$options{key}});
    #    },
    #);
}


#-------------------------------------------------------------------------------

1;
