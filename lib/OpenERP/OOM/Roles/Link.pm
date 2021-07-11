package OpenERP::OOM::Roles::Link;

# ABSTRACT: Defines required interface for link objects
our $VERSION = '0';

use Moose::Role;

=head1 DESCRIPTION

See L<OpenERP::OOM::Link::Provider> for how links work. The link provider that
your schema uses must return objects that consume this role when asked to
provide a link.

Note there is no "search". This is because we search using OpenERP's weird
nested-list syntax and we would only be able to pass this exact same data to the
user's search method to search across links. Since this is likely a lot of work
to implement, we don't require you to do so.

=head1 REQUIRED METHODS

The first parameter to every method will be C<$args>.

C<$args> is arbitrary data that is provided by L<OpenERP::OOM::Object/has_link>,
and can be used to specify information such as which type of link-side object we
are dealing with. For example, when using the C<DBIC> link type, the C<$args>
parameter will be a hashref containing C<class>, and that will contain the
resultset to use for the operation.

=head2 create

B<Arguments>: C<$args>, C<$object_data>

Use C<$object_data> to create an object. See above for C<$args>. Feel free to
die if you can't do it.

=head2 retrieve

=head2 retrieve_list

B<Arguments>: C<$args>, C<$object_data>

Use C<$object_data> to locate an object. See above for C<$args>.

In the case of C<retrieve_list>, C<$object_data> will be an arrayref, but you
can treat the items the same as the single parameter to C<retrieve>.

The method may return arbitrary data, or nothing at all. The method may die if
the item doesn't exist, if that's what you want. In the list case, return an
arrayref in all situations, even if it's empty.

The consumer will define the types that will be returned.

=cut

requires qw/create retrieve retrieve_list/;

1;
