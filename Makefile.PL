use inc::Module::Install;

name     'OpenERP-OOM';
all_from 'lib/OpenERP/OOM.pm';
author   q{Jon Allen (JJ) <jj@opusvl.com>};

build_requires 'Test::More';

requires 'Moose';
requires 'List::MoreUtils';

auto_install;

WriteAll;

