#!/usr/bin/perl

#
# How to use:
#
# This reads in comma delimited values for importing tools from standard input
# or from a file.  The tools values are passed in in this order:
#   name,location,email,username,[type],[description],[version],[attribution]
#
# Values in [] are optional and can be empty (you have to pass 8 values, just
# leave them empty).
#
# Example input:
#  bash\t/bin\tsomeone@iplantcollaborative.org\tSome One
#
# This will import /bin/bash for user, Some One, with e-mail address,
# someone@iplantcollaborative.org with no other attributes.  Type defaults to
# executable.
#
# To read from a file pass a filename in as the first argument to the tool:
#  ./import-tool.pl -h hostname filename
#

use warnings;
use strict;

use Carp;
use Getopt::Long;

# The field names in positional order.
my @FIELD_NAMES = qw( name location implementor_email implementor type
    description version attribution );

# The names of the component fields.
my @COMPONENT_FIELDS = qw( name location type description version
    attribution );

# The names of the implementation fields.
my @IMPLEMENTATION_FIELDS = qw( implementor_email implementor test input_files
    output_files);

# The fields that are required.
my @REQUIRED_FIELDS = qw( name location implementor_email implementor );

# Default values for optional fields.
my %DEFAULT_VALUES = (
    'type' => 'executable',
    'test' => { 'params' => [], input_files => [], output_files => [] },
);

# Some additional variables to be treated as constants.
my $DELIMITER     = "\t";
my $COMMENT       = '#';
my $NUM_OF_VALUES = scalar @FIELD_NAMES;

# Allow command-line option bundling.
Getopt::Long::Configure("bundling_override");

# Command-line option settings.
my $hostname;
my $port = 14445;
my $debug;

# Load the command-line options.
my $opts_ok = GetOptions(
    'hostname|h=s' => \$hostname,
    'port|p=i'     => \$port,
    'debug|d'      => \$debug,
);

# Print the usage message and exit if there's a problem.
if ( !$opts_ok || ( !$debug && !defined $hostname ) ) {
    print_usage();
    exit(1);
}

# Determine the URL for the service endpoint.
my $endpoint = $debug ? '' : "http://$hostname:$port/update-workflow";

# Initialize the component count.
my $component_count = 0;

# Start building the JSON.
my $json = "{ \"components\": [";

# Keep track of line numbers for error reporting.
my $line_num = 0;

# Add a component to the JSON for every input line.
LINE:
while ( my $line = <> ) {
    chomp $line;
    $line_num += 1;

    # Skip any line that is purely comments
    next LINE if $line =~ /^\s*$COMMENT/;

    # Extract the field values.
    my %field_values = extract_field_values($line);
    validate_required_fields( \%field_values, $line_num );

    # Build the component from the field values.
    my %component = component_from_values( \%field_values );

    # Strip any trailing slashes from the location
    $component{'location'} =~ s/\/$//;

    # Add a list element separator to the JSON if necessary.
    if ( $component_count > 0 ) {
        $json .= ", ";
    }
    $component_count++;

    # Add the JSON object for the current component.
    $json .= json_from_hash( \%component );
}

# Close the JSON.
$json .= "]}";

# Just print out the JSON if we're debugging.
if ($debug) {
    print $json;
    exit;
}

# Send to the endpoint
system( 'curl', '-d', $json, $endpoint ) == 0
    or croak "component import failed";
print "\n";

exit;

# Extracts the field values from the given line.
sub extract_field_values {
    my ($line) = @_;
    my %values;
    @values{@FIELD_NAMES} = split /$DELIMITER/, $line, $NUM_OF_VALUES;
    return %values;
}

# Builds the component from the field values.
sub component_from_values {
    my ($values_ref) = @_;
    my %component = object_from_hash( $values_ref, \@COMPONENT_FIELDS );
    $component{'implementation'}
        = { object_from_hash( $values_ref, \@IMPLEMENTATION_FIELDS ) };
    return %component;
}

# Builds an object from a values hash and a list of fields.
sub object_from_hash {
    my ( $values_ref, $fields_ref ) = @_;
    my %object;
    for my $field ( @{$fields_ref} ) {
        $object{$field}
            = defined $values_ref->{$field}
            ? $values_ref->{$field}
            : $DEFAULT_VALUES{$field};
    }
    return %object;
}

# Print the usage message.
sub print_usage {
    my $prog = $0;
    print {*STDERR} <<"END_OF_USAGE";
Usage:
    $prog --hostname=hostname [--port=port] [filename]
    $prog -h hostname [-p port] [filename]
    $prog --debug [filename]
    $prog -d [filename]
END_OF_USAGE
}

# Adds default values for fields whose values weren't provided.
sub add_default_values {
    my ($component_ref) = @_;
    for my $name ( sort keys %DEFAULT_VALUES ) {
        if ( is_empty( $component_ref->{$name} ) ) {
            $component_ref->{$name} = $DEFAULT_VALUES{$name};
        }
    }
    return;
}

# Verifies that all required fields have been provided.
sub validate_required_fields {
    my ( $values_ref, $line_num ) = @_;
    for my $name (@REQUIRED_FIELDS) {
        validate_field( $name, $values_ref->{$name}, $line_num );
    }
}

# Validate a required field.
sub validate_field {
    my ( $name, $value, $line_num ) = @_;
    if ( is_empty($value) ) {
        print {*STDERR} "Error on line number $line_num: no $name provided\n";
        exit 1;
    }
    return;
}

# Determine whether a string is undefined or empty.
sub is_empty {
    my ($str) = @_;
    return !defined $str || $str eq '';
}

# Convert a hash reference to a JSON object.
sub json_from_hash {
    my ($hash_ref) = @_;
    my @fields;
    for my $field ( sort keys %{$hash_ref} ) {
        if ( defined $hash_ref->{$field} ) {
            push @fields, format_json_field( $field, $hash_ref->{$field} );
        }
    }
    my $fields_json = join ", ", @fields;
    return "{$fields_json}";
}

# Convert an array reference to a JSON array.
sub json_from_array {
    my ($array_ref) = @_;
    my @elements;
    for my $element ( @{$array_ref} ) {
        if ( defined $element ) {
            push @elements, format_json_value($element);
        }
    }
    my $elements_json = join ", ", @elements;
    return "[$elements_json]";
}

# Format a single JSON field.
sub format_json_field {
    my ( $name, $value ) = @_;
    return json_quote($name) . ": " . format_json_value($value);
}

# Formats a JSON field value.
sub format_json_value {
    my ($value) = @_;
    my $formatted_value
        = ref $value eq 'HASH'  ? json_from_hash($value)
        : ref $value eq 'ARRAY' ? json_from_array($value)
        :                         json_quote($value);
    return $formatted_value;
}

# Quote a string for placement in a JSON object.
sub json_quote {
    my ($str) = @_;
    $str =~ s/"/\\"/gxms;
    return qq{"$str"};
}
