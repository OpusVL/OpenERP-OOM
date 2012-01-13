#! /Users/jj/bin/perl

use 5.010;
use strict;
use warnings;
use Try::Tiny;
use XML::Twig;

#--Configuration----------------------------------------------------------------

# Example usage:
# filter_xspec.pl Aquarius::OpenERP::Schema Aquarius::OpenERP::Object Aquarius OpenERP.xml >OpenERP_linked.xml

unless (@ARGV == 4) {
    die "Usage: $0 dbic_schema oom_object table_prefix input.xml >output.xml";
}

my $dbic_schema  = shift @ARGV;
my $oom_object   = shift @ARGV;
my $table_prefix = shift @ARGV;  # Target DB name from generated Xspec file
my $input_xml    = shift @ARGV;


#--Load modules-----------------------------------------------------------------

eval "use Module::Pluggable search_path => ['$oom_object']";
die $@ if $@;
eval "use $dbic_schema";
die $@ if $@;

#--Extract links from OpenERP to Perl from the OpenERP::OOM object classes------

my %links;
OBJECT: foreach my $object (plugins()) {
    warn "Working on $object\n";
    next OBJECT unless (scalar split /::/,$object) == 4;
    eval "use $object";
    die $@ if $@;
    my $openerp_table = $object->model =~ s/\./_/gr;
    my $meta = $object->meta;
    my $links = $meta->link;
    LINK: while (my ($name, $link) = each %$links) {
        if ($link->{class} eq 'DBIC') {
            my $dbic_result = $dbic_schema . "::Result::" . $link->{args}->{class};
            my $table_name  = try {$dbic_result->table} catch {next LINK};
            
            warn "  Found link to $table_name with key $link->{key}\n";
            push @{$links{$openerp_table}}, {
                link_name  => "fk_$link->{key}_$table_name",
                field_name => $link->{key},
                table_name => $table_name,
            };
        }
    }
}

my $twig = XML::Twig->new(
    twig_roots => {'TABLE' => \&process_table},
    twig_print_outside_roots => 1,
    pretty_print => 'indented',
);

$twig->parsefile($input_xml);

sub process_table {
    my ($twig, $table) = @_;
    
    my $table_name = $table->first_child_text('tableName');
    
    foreach my $fkey ($table->children('FOREIGNKEY')) {
        # If there is more than one field specified in the foreign
        # key, UnityJDBC screws up the links (and I don't think it
        # makes sense to have more that one key field anyway).
        
        my $fields = $fkey->first_child('FIELDS');
        if (scalar $fields->children('fieldName') > 1) {
            $fkey->delete;
        }
    }
    
    foreach my $link (@{$links{$table_name}}) {
        my $fkey = XML::Twig::Elt->parse("<FOREIGNKEY><keyScope>0</keyScope><keyScopeName></keyScopeName><keyName>$link->{link_name}</keyName><keyType>2</keyType><FIELDS><fieldName>$link->{field_name}</fieldName></FIELDS><toTableName>$table_prefix.$link->{table_name}</toTableName></FOREIGNKEY>");
        $fkey->paste('last_child', $table);
    }
    
    $table->print;
}