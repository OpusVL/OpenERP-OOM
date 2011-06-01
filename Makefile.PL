use inc::Module::Install;

name     'OpenERP-OOM';
all_from 'lib/OpenERP/OOM.pm';
author   q{Jon Allen (JJ) <jj@opusvl.com>};

build_requires 'Test::More';

requires 'Moose';
requires 'Moose::Exporter';
requires 'Moose::Role';
requires 'Moose::Util::MetaRole';
requires 'Moose::Util::TypeConstraints';
requires 'List::MoreUtils';
requires 'RPC::XML';

auto_install;

WriteAll;

