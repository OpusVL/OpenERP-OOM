package OpenERP::OOM::Link::Provider;

use Moose::Role;

requires 'provide_link';

=head1 NAME

OpenERP::OOM::Link::Provider

=head1 DESCRIPTION

This is the role for a link provider that provides a way to link another dataset,
normally a DBIC dataset.

=head1 SYNOPSIS

    package MyLinkProvider;

    use Moose;
    with 'OpenERP::OOM::Link::Provider';

    sub provide_link 
    {
        my ($self, $class) = @_;
        
        my $package = ($class =~ /^\+/) ? $class : "OpenERP::OOM::Link::$class";

        eval "use $package";
        
        return $package->new(
            schema => $self,
            config => $self->link_config->{$class},
        );
    }

    1;

=head1 COPYRIGHT and LICENSE

Copyright (C) 2011 OpusVL

This software is licensed according to the "IP Assignment Schedule" provided with the development project.

=cut

1;
