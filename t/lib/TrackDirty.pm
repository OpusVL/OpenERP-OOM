package TrackDirty;

use 5.006;
use strict;
use warnings;
use Moose ();
use Moose::Exporter;

=head1 NAME

OpusVL::MooseX::TrackDirty

=head1 VERSION

Version 0.05

=cut

our $VERSION = '0.05';

Moose::Exporter->setup_import_methods(
    with_meta => [ ],
    as_is     => [ ],
    also      => 'Moose',
);


=head1 SYNOPSIS

A module for allowing objects to track their attributes changes.

This is essentially a rip off of the MooseX::TrackDirty module.

In order to use this module you can use this module like you would include
Moose or if you are doing something fancy you can hook the roles in manually
yourself.

    use OpusVL::MooseX::TrackDirty;

    has property => (is => 'ro', isa => 'Str');

    sub save {
        my $self = shift;
        if($self->is_dirty) {
            foreach my $key ($self->dirty_attributes) {
                ...
            }
            $self->mark_all_clean;
        }
    ...

=head1 METHODS

=head2 mark_all_clean

This will mark all the attributes clean.

=head2 has_dirty_attributes

Returns true if any of the attributes have been set.

=head2 all_attributes_clean

Returns true if no attributes have been touched.

=head2 dirty_attributes

Return an array of the attributes touched.

=head2 _set_dirty

Set a field as dirty.

    $self->_set_dirty('property');

=head2 init_meta

This is a function used to setup the Moose::Exporter and load in all these functions.  
If you are creating your own Moose::Exporter you should simply do thse bits yourself,

    Moose::Util::MetaRole::apply_metaroles(
        for             => $args{for_class},
        class_metaroles => {
            attribute => ['OpusVL::MooseX::TrackDirty::Attributes::Role::Meta::Attribute'],
        },
    );

    Moose::Util::MetaRole::apply_base_class_roles( 
        for_class => $args{for_class}, 
        roles     => ['OpusVL::MooseX::TrackDirty::Attributes::Role::Class'],
    );

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 OpusVL

This software is licensed according to the "IP Assignment Schedule" provided with the development project.

=cut

sub init_meta {
    shift;
    my %args = @_;
    
    Moose->init_meta( %args );
    
    Moose::Util::MetaRole::apply_metaroles(
        for             => $args{for_class},
        class_metaroles => {
            attribute => ['OpenERP::OOM::Roles::Attribute'],
        },
    );

    Moose::Util::MetaRole::apply_base_class_roles( 
        for_class => $args{for_class}, 
        roles     => ['OpenERP::OOM::Roles::Class'],
    );

}

1; # End of OpusVL::MooseX::TrackDirty
