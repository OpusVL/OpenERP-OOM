package OpenERP::OOM::Class::Base;

use 5.010;
use Carp;
use Data::Dumper;
use Moose;
use RPC::XML;
use DateTime;
use DateTime::Format::Strptime;

extends 'Moose::Object';
with 'OpenERP::OOM::DynamicUtils';

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
    
    # if you get this blow up it probably means the class doesn't compile for some
    # reason.  Run the t/00-load.t tests.  If they pass check you have a use_ok 
    # statement for all your modules.
    die 'Your code doesn\'t compile llamma' if !$self->can('object');
    $self->ensure_class_loaded($self->object);
    
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

Searches can be performed against OpenERP fields, linked objects (e.g. DBIx::Class
relationships), or a combination of both.

    my @list = $schema->class('Name')->search(
        ['active', '=', 1],
        ['details', {status => 'value'}, {}],
    )

In this example, 'details' is a linked DBIx::Class object with a column called
'status'.

An optional 'search context' can also be provided at the end of the query list, e.g.

    my @list = $schema->class('Location')->search(
        ['usage' => '=' => 'internal'],
        ['active' => '=' => 1],
        {
            active_id => $self->id,
            active_ids => [$self->id],
            active_model => 'product.product',
            full => 1,
            product_id => $self->id,
            search_default_in_location => 1,
            section_id => undef,
            tz => undef,
        }
    );

Supplying a context further restricts the search, for example to narrow down a
'stock by location' query to 'stock of a specific product by location'.

=cut

sub search {
    my ($self, @args) = @_;
    
    my @search;
    while (ref $args[0] eq 'ARRAY') {push @search, shift @args}
    
    # Loop through each search criteria, and if it is a linked object 
    # search, replace it with a translated OpenERP search parameter.
    foreach my $criteria (@search) {
        my $search_field = $criteria->[0];
        
        if (my $link = $self->object_class->meta->link->{$search_field}) {
            if ($self->schema->link($link->{class})->can('search')) {
                my @results = $self->schema->link($link->{class})->search($link->{args}, @$criteria[1 .. @$criteria-1]);
                
                if (@results) {
                    warn "Adding to OpenERP search: " . $link->{key} . " IN " . join(', ', @results);
                    $criteria = [$link->{key}, 'in', \@results];
                } else {
                    return ();  # No results found, so no point searching in OpenERP
                }
            } else {
                carp "Cannot search for link type " . $link->{class};
            }
        }
    }
    
    my $objects = $self->schema->client->search_detail($self->object_class->model,[@search], @args);

    if ($objects) {    
        foreach my $attribute ($self->object_class->meta->get_all_attributes) {
            if($attribute->type_constraint =~ /DateTime/)
            {
                my $parser = DateTime::Format::Strptime->new(pattern     => '%Y-%m-%d');
                map { $_->{$attribute->name} = $parser->parse_datetime($_->{$attribute->name}) } @$objects;
            }
        }
        return map {$self->object_class->new($_)} @$objects;
    } else {
        return wantarray ? () : undef;
    }
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


=head2 get_options

This returns the options for available for a selection field.  It will croak if you
try to give it a field that isn't an option.

=cut

sub get_options 
{
    my $self = shift;
    my $field = shift;

    my $model_info = $self->schema->client->model_fields($self->object_class->model);
    my $field_info = $model_info->{$field};
    croak 'Can only get options for selection objects' unless $field_info->{type} eq 'selection';
    my $options = $field_info->{selection};
    return $options;
}

#-------------------------------------------------------------------------------

=head2 retrieve

Returns an object by ID.

 my $obj = $schema->class('Name')->retrieve(32);

=cut

sub retrieve {
    my ($self, $id) = @_;
    
    # FIXME - This should probably be in a try/catch block
    if (my $object = $self->schema->client->read_single($self->object_class->model, $id)) 
    {
        return $self->_inflate_object($object);
    }
}

sub _inflate_object
{
    my $self = shift;
    my $object = shift;

    foreach my $attribute ($self->object_class->meta->get_all_attributes) {
        if($attribute->type_constraint =~ /DateTime/)
        {
            my $parser = DateTime::Format::Strptime->new(pattern     => '%Y-%m-%d');
            $object->{$attribute->name} = $parser->parse_datetime($object->{$attribute->name});
        }
    }
    return $self->object_class->new($object);
}

=head2 default_values

Returns an instance of the object filled in with the default values suggested by OpenERP.

=cut
sub default_values
{
    my $self = shift;
    # do a default_get

    my @fields = map { $_->name } $self->object_class->meta->get_all_attributes;
    my $object = $self->schema->client->get_defaults($self->object_class->model, \@fields);
    return $self->_inflate_object($object);
}

#-------------------------------------------------------------------------------

=head2 retrieve_list

Takes a reference to a list of object IDs and returns a list of objects.

 my @list = $schema->class('Name')->retrieve_list([32, 15, 60]);

=cut

sub retrieve_list {
    my ($self, $ids) = @_;
    
    if (my $objects = $self->schema->client->read($self->object_class->model, $ids)) {
        foreach my $attribute ($self->object_class->meta->get_all_attributes) {
            if($attribute->type_constraint =~ /DateTime/)
            {
                my $parser = DateTime::Format::Strptime->new(pattern     => '%Y-%m-%d');
                map { $_->{$attribute->name} = $parser->parse_datetime($_->{$attribute->name}) } @$objects;
            }
        }
        return map {$self->object_class->new($_)} @$objects;
    }
}


#-------------------------------------------------------------------------------

sub _collapse_data_to_ids
{
    my ($self, $object_data) = @_;

    my $relationships = $self->object_class->meta->relationship;
    while (my ($name, $rel) = each %$relationships) {
        if ($rel->{type} eq 'one2many') {
            if ($object_data->{$name}) {
                $object_data->{$rel->{key}} = _id($object_data->{$name});
                delete $object_data->{$name} if $name ne $rel->{key};
            }
        }
        
        if ($rel->{type} eq 'many2one') {
            if ($object_data->{$name}) {
                $object_data->{$rel->{key}} = _id($object_data->{$name});
                delete $object_data->{$name} if $name ne $rel->{key};
            }            
        }
        if ($rel->{type} eq 'many2many') {
            if ($object_data->{$name}) {
                my $val = $object_data->{$name};
                my @ids;
                if(ref $val eq 'ARRAY')
                {
                    # they passed in an arrayref.
                    my $objects = $val;
                    @ids = map { _id($_) } @$objects;
                }
                else
                {
                    # assume it's a single object.
                    push @ids, _id($val);
                }
                $object_data->{$rel->{key}} = [[ 6, 0, \@ids ]];
                delete $object_data->{$name} if $name ne $rel->{key};
            }            
        }
    }
    # Force Str parameters to be object type RPC::XML::string
    foreach my $attribute ($self->object_class->meta->get_all_attributes) {
        if (exists $object_data->{$attribute->name}) {
            $object_data->{$attribute->name} = $self->prepare_attribute_for_send($attribute->type_constraint, $object_data->{$attribute->name});
        }
    }
    return $object_data;
}

sub _id
{
    my $val = shift;
    return ref $val ? $val->id : $val;
}

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

    carp "Create called with initial object data: ";
    warn Dumper $object_data;
    
    $object_data = $self->_collapse_data_to_ids($object_data);

    warn 'To';
    warn Dumper $object_data;
    
    if (my $id = $self->schema->client->create($self->object_class->model, $object_data)) 
    {
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
