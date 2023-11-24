#!perl
# no critic (ValuesAndExpressions::ProhibitMagicNumbers)
# no critic (ControlStructures::ProhibitPostfixControls)

use strict;
use warnings;

use English qw( -no_match_vars ) ;  # Avoids regex performance
local $OUTPUT_AUTOFLUSH = 1;

use utf8;

use Test2::V0 -target => 'Database::Temp';
use Test2::Tools::Spec;
set_encoding('utf8');

describe 'method `is_available`' => sub {
    my ($driver, $expected_availability);
    case 'SQLite driver' => sub {
        $driver = 'SQLite';
        $expected_availability = 1;
    };
    case 'Pg driver' => sub {
        $driver = 'Pg';
        $expected_availability = 0;
    };
    case 'CSV driver' => sub {
        $driver = 'CSV';
        $expected_availability = 1;
    };
    case 'Missing driver' => sub {
        $driver = 'Missing';
        $expected_availability = 0;
    };
    case 'Empty name driver' => sub {
        $driver = q{};
        $expected_availability = 0;
    };
    case 'undef driver' => sub {
        $driver = undef;
        $expected_availability = 0;
    };
    tests 'it works' => sub {
        my $got_availability = $CLASS->is_available( driver => $driver );
        is( $got_availability, $expected_availability, 'Expected availability returned' );
    };
};

# describe 'method `foo_bar`' => sub {
#
#     my ( $foo, $bar, $expected_foo_bar );
#
#     case 'both are undefined' => sub {
#       $foo = undef;
#       $bar = undef;
#       $expected_foo_bar = '';
#     };
#
#     tests 'it works' => sub {
#       my ( $object, $got_foo_bar, $got_exception, $got_warnings );
#
#       $got_exception = dies {
#         $got_warnings = warns {
#           $object = $CLASS->new( foo => $foo, bar => $bar );
#           $got_foo_bar = $object->foo_bar;
#         };
#       };
#       is( $got_exception, undef, 'no exception thrown' );
#       is( $got_warnings, 0, 'no warnings generated' );
#       is( $got_foo_bar, $expected_foo_bar, 'expected string returned' );
#       is(
#         $object,
#         object {
#           call foo => $foo;
#           call bar => $bar;
#         },
#         "method call didn't alter the values of the attributes",
#       ) or diag Dumper( $object );
#     };
# };

describe "class `$CLASS`" => sub {

    # tests 'it inherits from Moo::Object' => sub {
    #     isa_ok( $CLASS, 'Moo::Object' );
    # };

    tests 'it can be instantiated' => sub {
        can_ok( $CLASS, 'new' );
    };
};

done_testing;
