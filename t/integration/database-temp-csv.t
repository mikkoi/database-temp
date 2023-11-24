#!perl
## no critic (ValuesAndExpressions::ProhibitMagicNumbers)

use strict;
use warnings;

use English qw( -no_match_vars ) ;  # Avoids regex performance
local $OUTPUT_AUTOFLUSH = 1;

use utf8;
use Test2::V0;
set_encoding('utf8');
use Test2::Plugin::BailOnFail;

# Activate for testing
# use Log::Any::Adapter ('Stdout', log_level => 'debug' );

use File::Spec;
use File::Temp ();
use Path::Tiny;

use Database::Temp ();
use Const::Fast;

const my $DDL => <<~'EOF';
    CREATE TABLE test_table (
        id INTEGER
        , name VARCHAR(20)
        , age INT
        );
EOF
;

sub init_db {
    my ($dbh, $name) = @_;
    foreach my $row (split qr/;\s*/msx, $DDL) {
        $dbh->do( $row );
    }
    return;
}

subtest 'CSV: Shortest example' => sub {
    my $db = Database::Temp->new(
        driver => 'CSV',
    );
    my $dbh = DBI->connect( $db->connection_info );
    my $rows = $dbh->selectall_arrayref( 'SELECT 1, 1+2' );
    is($rows->[0], [1, 3], 'Return simplest query correctly');
    done_testing;
};

subtest 'CSV: Without arguments, init is sub' => sub {
    my $db = Database::Temp->new(
        driver => 'CSV',
        init => sub {
            my ($dbh, $name) = @_;
            init_db( $dbh, $name);
        },
    );
    diag "Test database (${\($db->driver)}) ${\($db->name)} created in ${\($db->info->{'dirpath'})}.\n";

    isa_ok( $db, [ 'Database::Temp::DB' ], 'Temp database is Database::Temp::DB');
    can_ok( $db, [ qw( connection_info ) ], 'Temp database can connection_info()');

    {
        my $dbh = DBI->connect( $db->connection_info );
        my $r = $dbh->do('INSERT INTO test_table VALUES(1, \'My Name\', 33)');
        $r = $dbh->do('INSERT INTO test_table VALUES(2, \'My Other Name\', 43)');
        my $rows = $dbh->selectall_arrayref(
            'SELECT id, name, age FROM test_table ORDER BY id',
        );
        is($rows->[0]->[1], 'My Name');
    }

    {
        my $dbh = DBI->connect( $db->connection_info );
        my $r = $dbh->do('INSERT INTO test_table VALUES(3, \'My Third Name\', 53)');
        my $rows = $dbh->selectall_arrayref(
            'SELECT id, name, age FROM test_table ORDER BY id',
        );
        is($rows->[2]->[1], 'My Third Name');
    }

    $db->cleanup( 0 );
    my $dir = File::Spec->tmpdir; # This is /tmp in Unix
    my $path = File::Spec->catdir( $dir, $db->name );

    $db = undef;
    ok( path($path)->is_dir, 'Dir exists' );

    # Manually remove dir
    path($path)->remove_tree();
    ok( ! path($path)->is_dir, 'Dir is gone' );

    done_testing;
};

subtest 'CSV: Without arguments, init is string' => sub {
    my $db = Database::Temp->new(
        driver => 'CSV',
        args => {
        },
        init => $DDL,
    );
    diag 'Test database (' . $db->driver . ') ' . $db->name . " created.\n";

    {
        my $dbh = DBI->connect( $db->connection_info );
        my $r = $dbh->do('INSERT INTO test_table VALUES(1, \'My Name\', 33)');
        $r = $dbh->do('INSERT INTO test_table VALUES(2, \'My Other Name\', 43)');
        my $rows = $dbh->selectall_arrayref(
            'SELECT id, name, age FROM test_table ORDER BY id',
        );
        is($rows->[0]->[1], 'My Name');
    }

    {
        my $dbh = DBI->connect( $db->connection_info );
        my $r = $dbh->do('INSERT INTO test_table VALUES(3, \'My Third Name\', 53)');
        my $rows = $dbh->selectall_arrayref(
            'SELECT id, name, age FROM test_table ORDER BY id',
        );
        is($rows->[2]->[1], 'My Third Name');
    }

    $db->cleanup( 0 );
    my $dir = File::Spec->tmpdir; # This is /tmp in Unix
    my $path = File::Spec->catfile( $dir, $db->name );

    $db = undef;
    ok( path($path)->is_dir, 'Dir exists' );

    # Manually remove dir
    path($path)->remove_tree();
    ok( ! path($path)->is_dir, 'Dir is gone' );

    done_testing;
};

subtest 'CSV: Test dir exists and gets deleted' => sub {
    my $dir = File::Spec->tmpdir; # This is /tmp in Unix
    my $path;
    {
        my $db = Database::Temp->new(
            driver => 'CSV',
        );
        diag 'Test database (' . $db->driver . ') ' . $db->name . " created.\n";
        my $name = $db->name;
        $path = File::Spec->catfile( $dir, $name );
        ok( path($path)->is_dir, 'Dir exists' );
    }
    ok( ! path($path)->is_dir, 'Dir is gone' );

    done_testing;
};

subtest 'CSV: Test database dir gets created into a designated dir' => sub {
    # Create a tempdir in /tmp (Unix).
    my $dir = File::Temp->newdir( cleanup => 1 ); # Cleanup when object out of scope.
    my $path;
    {
        my $db = Database::Temp->new(
            driver => 'CSV',
            args => { dir => $dir->dirname, },
        );
        diag 'Test database (' . $db->driver . ') '
            . 'dir ' . $db->name . ' created in dir '
            . $dir->dirname . "\n";
        my $name = $db->name;
        ok( path($dir->dirname)->is_dir, 'Main dir (of course) exists' );
        $path = File::Spec->catfile( $dir->dirname, $name );
        ok( path($path)->is_dir, 'Dir exists' );
    }
    diag "path: $path";
    ok( ! path($path)->is_dir, 'Dir is gone' );

    done_testing;
};

subtest 'CSV: Test database dir has a designated dirpath' => sub {
    # Create a tempdir in /tmp (Unix).
    my $dir = File::Temp->newdir( cleanup => 1 ); # Cleanup when object out of scope.
    my $basename = 'this_';
    my $name = 'temp_test_db';
    my $fullname = $basename . $name;
    my $path;
    {
        my $db = Database::Temp->new(
            driver => 'CSV',
            basename => $basename,
            name => $name,
            args => { dir => $dir->dirname, },
        );
        diag 'Test database (' . $db->driver . ') '
            . $db->name . ' created in dir '
            . $dir->dirname . "\n";
        is( $db->name, $fullname, 'Name matches with given name' );
        ok( path($dir->dirname)->is_dir, 'main dir (of course) exists' );
        $path = File::Spec->catfile( $dir->dirname, $fullname );
        ok( path($path)->is_dir, 'Dir exists' );
    }
    diag "path: $path";
    ok( ! path($path)->is_dir, 'Dir is gone' );

    done_testing;
};

done_testing;
