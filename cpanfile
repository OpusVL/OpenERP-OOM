
requires 'Moose';
requires 'Moose::Exporter';
requires 'Moose::Role';
requires 'Moose::Util::MetaRole';
requires 'Moose::Util::TypeConstraints';
requires 'MooseX::Role::XMLRPC::Client';
requires 'List::MoreUtils';
requires 'RPC::XML';
requires 'DateTime';
requires 'Try::Tiny::Retry';
requires 'DateTime::Format::Strptime';
requires 'Switch::Plain';
requires 'Class::Inspector';
requires 'namespace::autoclean';

requires 'OpenERP::XMLRPC::Client' => 0.22;
requires 'MooseX::NotRequired';

on 'test' => sub {
    requires 'Test::More';
};

