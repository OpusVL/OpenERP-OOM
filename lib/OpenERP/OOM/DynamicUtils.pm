package OpenERP::OOM::DynamicUtils;

use Class::Inspector;
use Moose::Role;
use Carp ();

my $invalid_class = qr/(?: \b:\b | \:{3,} | \:\:$ )/x;

sub ensure_class_loaded
{
    my $self = shift;
    my $class = shift;
    return if Class::Inspector->loaded($class);

    my $file = Class::Inspector->filename($class);
    # code stolen from Class::C3::Componentised ensure_class_loaded
    eval { local $_; require($file) } or do {

        $@ = "Invalid class name '$class'" if $class =~ $invalid_class;

        if ($self->can('throw_exception')) {
            $self->throw_exception($@);
        } else {
            Carp::croak $@;
        }
    };

    return;
}

1;

