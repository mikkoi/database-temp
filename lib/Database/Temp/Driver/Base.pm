package Database::Temp::Driver::Base;
## no critic (Documentation::RequirePodAtEnd)
## no critic (Documentation::RequirePodSections)

use strict;
use warnings;

use Moo;
use Types::Standard qw( Str Int HashRef CodeRef Maybe );

has name => (
    is => 'ro',
    isa => Str,
);
has args => (
    is => 'ro',
);

has cleanup => (
    is => 'rw',
    isa => Int->where( '$_ == 1 || $_ == 0' ),
);
has init => (
    is      => 'ro',
    isa     => Maybe[CodeRef],
    # isa     => sub { croak if( ref $_[0] !~ m/(SCALAR|CODE)/ ) },
    default => sub {
        return sub { };
    },
);

has deinit => (
    is      => 'ro',
    isa     => Maybe[CodeRef],
    # isa     => sub { croak if( ref $_[0] !~ m/(SCALAR|CODE)/ ) },
    default => sub {
        return sub { };
    },
);

# Connection info
has dsn => (
    is      => 'rw',
    isa => Str,
);
has username => (
    is      => 'rw',
);
has password => (
    is      => 'rw',
);
has attr => (
    is      => 'rw',
    isa => HashRef,
);

1;
