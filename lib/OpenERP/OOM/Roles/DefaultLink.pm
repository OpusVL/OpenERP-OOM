package OpenERP::OOM::Roles::DefaultLink;

# ABSTRACT: Provides properties required by the default link provider
our $VERSION = '0';

=head1 DESCRIPTION

This role should be used by anything in the C<OpenERP::OOM::Link> namespace,
except C<OpenERP::OOM::Link::Provider>, which is a special snowflake.

This is the namespace used to discover link types for the default provider.

=head1 PROPERTIES

=head2 config

The default link provider will hold config for each link type. This will be
passed in as appropriate when the link is constructed.

Its contents are entirely down to the specific link class being constructed, and
will be ultimately sourced from user-provided configuration. An example of this
is to hold to connection info for a DBIC schema - this obviously must come from
the end user somehow.

That ends up here, and the link class should document it and make use of it.

=cut

use Moose::Role;

has 'config' => (
    isa => 'HashRef',
    is  => 'ro',
);

1;
