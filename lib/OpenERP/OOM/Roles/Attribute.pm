=head1 NAME

OpenERP::OOM::Roles::Attribute - Meta attribute for implementing dirty attribute tracking

=head1 DESCRIPTION

This code was largely taken from a version of MooseX::TrackDirty before it 
was updated to work with Moose 2.0.  Then it was cut down to suit our purposes
being uses in the Moose::Exporter.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 OpusVL

This software is licensed according to the "IP Assignment Schedule" provided with the development project.

=cut

package OpenERP::OOM::Roles::Attribute;
use namespace::autoclean;
use Moose::Role;

has track_dirty     => (is => 'rw', isa => 'Bool', default => 1);
has dirty           => (is => 'ro', isa => 'Str',  predicate => 'has_dirty');

has track_attribute_helpers_dirty => 
    (is => 'rw', isa => 'Bool', default => 1);

# There doesn't seem to be an easy way to get around writing this all out
my %sullies = (
    # note we handle "accessor" separately 
    'Hash'  => [ qw{ set clear delete } ],
    'Array' => [ qw{ push pop unshift shift set clear insert splice delete
                     sort_in_place } ],
    # FIXME ...
);

# wrap our internal clearer
after clear_value => sub {
    my ($self, $instance) = @_;

    $instance->_mark_clean($self->name) if $self->track_dirty;
};

after install_accessors => sub {  
    my ($self, $inline) = @_;

    ### in install_accessors, installing if: $self->track_dirty
    return unless $self->track_dirty;

    my $class = $self->associated_class;
    my $name  = $self->name;

    ### is_dirty: $self->dirty || ''
    $class->add_method($self->dirty, sub { shift->_is_dirty($name) }) 
        if $self->has_dirty;

    $class->add_after_method_modifier(
        $self->clearer => sub { shift->_mark_clean($name) }
    ) if $self->has_clearer;

    # if we're set, we're dirty (cach both writer/accessor)
    $class->add_after_method_modifier(
        $self->writer => sub { shift->_mark_dirty($name) }
    ) if $self->has_writer;
    $class->add_after_method_modifier(
        $self->accessor => 
            sub { $_[0]->_mark_dirty($name) if defined $_[1] }
    ) if $self->has_accessor;

    return;
};

after install_delegation => sub {
    my ($self, $inline) = @_;

    # check for native hashes if we can do them...
    return if 
        !$self->has_handles || 
        !$self->track_attribute_helpers_dirty
        ;

    my @does = grep { $self->does($_) } keys %sullies;

    ##### @does
    return unless scalar @does;
    my $does = shift @does;

    # we're not going through _canonicalize_handles here, as, well, it's
    # private and I'm not sure it'll buy us anything here... right?
    my %handles = %{ $self->handles };
    my %writers = map { $_ => 1 } @{$sullies{$does}};
    my $name    = $self->name;
    my $dirty   = sub { shift->_mark_dirty($name) };
    my $class   = $self->associated_class;

    # method name -> operation (provided method type)
    #### %handles
    #### %writers
    
    for my $method_name (keys %handles) {

        #### looking at: $method_name
        my $op = $handles{$method_name};

        #### writer?: $writers{$op} 
        $class->add_after_method_modifier($method_name => $dirty)
            if $writers{$op};

        # accessor _might_ be used as a writer
        $class->add_after_method_modifier($method_name 
            => sub { $_[0]->_mark_dirty($name) if defined $_[2] } 
        ) if $op eq 'accessor';
    }

    return;
};

before _process_options => sub {
    my ($self, $name, $options) = @_;

    ### before _process_options: $name
    $options->{dirty} = $name.'_is_dirty' 
        unless exists $options->{dirty} || !$options->{lazy_build};

    return;
};

1;

