use inc::Module::Install;

name     'OpenERP-OOM';
all_from 'lib/OpenERP/OOM.pm';
author   q{Jon Allen (JJ) <jj@opusvl.com>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

