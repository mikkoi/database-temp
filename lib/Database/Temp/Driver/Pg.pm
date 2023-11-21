package Database::Temp::Driver::Pg;
# no critic (Documentation::RequirePodAtEnd)
# no critic (Documentation::RequirePodSections)
# no critic (Subroutines::RequireArgUnpacking)

use strict;
use warnings;

# ABSTRACT: Create an ad-hoc database, driver for Postgres

# VERSION: generated by DZP::OurPkgVersion

=pod

=encoding utf8

=cut


use parent 'Database::Temp::Driver::Base';

use Module::Load::Conditional qw( can_load );

use DBI;
use Log::Any;

=head2 is_available

Can this driver provide a database?

Return boolean.

=cut

sub is_available {
    my %needed = (
        'DBD::Pg' => 1.41_01,
    );
    if( can_load( modules => \%needed ) ) {
        return 1;
    } else {
        Log::Any->get_logger(category => 'Database::Temp')->infof('Cannot load module %s, %s', %needed);
        return 0;
    }
}

sub _main_db_connection {
    return {
        'dsn' => _compile_dsn( 'postgres', undef, undef, 'Database--Temp' ),
        'username' => undef,
        'password' => undef,
        'attr' => {
            'AutoCommit'        => 1,
            'RaiseError'        => 1,
            'PrintError'        => 1,
            'pg_server_prepare' => 0,
            'TraceLevel'        => 0,
        },
    };
};

sub _open_dbh {
    my ($db_connection) = @_;
    return DBI->connect(
        $db_connection->{'dsn'},
        $db_connection->{'username'},
        $db_connection->{'password'},
        $db_connection->{'attr'}
    );
}

sub _create {
    my ($name) = @_;
    my $_log = Log::Any->get_logger;

    my $temp_db_name = $name;
    my $temp_user_name = $name;
    my $main_dbh = _open_dbh(_main_db_connection);
    $main_dbh->do("CREATE ROLE \"$temp_user_name\" LOGIN ENCRYPTED PASSWORD '$temp_user_name'");
    $_log->debugf( 'Created test user \'%s\'', $temp_user_name );
    $main_dbh->do("CREATE DATABASE \"$temp_db_name\" OWNER \"$temp_user_name\"");
    $_log->debugf( 'Created temp database \'%s\'', $temp_db_name );
    # $main_dbh->do("GRANT ALL ON DATABASE \"$temp_db_name\" TO \"$temp_db_name\"");
    $main_dbh->disconnect();
    return;
}

sub _compile_dsn {
    my ($name, $host, $port, $app_name) = @_;
    my $dsn;
    my $driver = (__PACKAGE__ =~ m/::( [[:alnum:]]{1,}) $/msx)[0];
    if( $host && $port ) {
        $dsn = sprintf 'dbi:%s:dbname=%s;host=%s;port=%s;application_name=%s'
            , $driver, $name, $host, $port, $app_name
            ;
    } else {
        $dsn = sprintf 'dbi:%s:dbname=%s;application_name=%s'
            , $driver, $name, $app_name
            ;
    }
    return $dsn;
}

=head2 new

Create a temp database.

User should never call this subroutine directly, only via L<Database::Temp>.

=cut

sub new {
    my ($class, %params) = @_;
    my $_log = Log::Any->get_logger(category => 'Database::Temp');

    my $name = $params{'name'};
    my $args = $params{'args'};
    _create( $name );
    my $dsn = _compile_dsn( $name, 'localhost', '5432', 'DBHandle' );
    $_log->debugf( 'Created temp database \'%s\'', $name );

    my %attrs = (
        # 'ReadOnly'          => 0,
        'AutoCommit'        => 1,
        'RaiseError'        => 1,
        'PrintError'        => 1,
        'RaiseWarn'         => 1,
        'PrintWarn'         => 1,
        'TaintIn'           => 1,
        'TaintOut'          => 0,
        'TraceLevel'        => 0,
        'pg_server_prepare' => 0,
    );
    my %info = (
    );

    # Construct start method
    my $_start = sub {
        ## no critic (Variables::ProhibitReusedNames)
        my ($dbh, $name, $info, $driver, $in_global_destruction) = @_;
        my $_log = Log::Any->get_logger(category => 'Database::Temp');
        $_log->debugf( 'Created temp db \'%s\'', $name );
    };

    # Construct init method
    my $init;
    if( ref $params{'init'} eq 'CODE' ) {
        $init = $params{'init'};
    } else { # SCALAR
        $init = sub {
            my ($dbh, $name) = @_; ## no critic (Variables::ProhibitReusedNames)
            $dbh->begin_work();
            foreach my $row (split qr/;\s*/msx, $params{'init'}) {
                $dbh->do( $row );
            }
            $dbh->commit;
            return;
        }
    }
    # Construct deinit method
    my $deinit;
    if( ref $params{'deinit'} eq 'CODE' ) {
        $deinit = $params{'deinit'};
    } else { # SCALAR
        $deinit = sub {
            my ($dbh, $name) = @_; ## no critic (Variables::ProhibitReusedNames)
            $dbh->begin_work();
            foreach my $row (split qr/;\s*/msx, $params{'deinit'}) {
                $dbh->do( $row );
            }
            $dbh->commit;
            return;
        }
    }

    # Construct _cleanup method
    my $_cleanup = sub {
        my ($dbh, $name, $info, $driver, $in_global_destruction) = @_; ## no critic (Variables::ProhibitReusedNames)

        # Drop database
        my $_log = Log::Any->get_logger(category => 'Database::Temp'); ## no critic (Variables::ProhibitReusedNames)
        my $temp_db_name = $name;
        my $temp_user_name = $name;
        my $main = {
            'dsn' => _compile_dsn( 'postgres', undef, undef, 'Database--Temp--Driver--Pg' ),
            'username' => undef,
            'password' => undef,
            'attr' => {
                'AutoCommit'        => 1,
                'RaiseError'        => 1,
                'PrintError'        => 1,
                'pg_server_prepare' => 0,
                'TraceLevel'        => 0,
            },
        };
        my $main_dbh = DBI->connect(
            $main->{'dsn'},
            $main->{'username'},
            $main->{'password'},
            $main->{'attr'},
        );
        my $rc = $main_dbh->do("ALTER DATABASE  \"$temp_db_name\" WITH ALLOW_CONNECTIONS false");
        $rc = $main_dbh->do("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$temp_db_name'");
        $_log->infof( 'Dropping database \'%s\'', $temp_db_name );
        $rc = $main_dbh->do("DROP DATABASE \"$temp_db_name\"");
        if( $rc ) {
            $_log->debugf( 'Dropped temp database \'%s\'', $temp_db_name );
        } else {
            $_log->warningf( 'Probably not managed to drop temp database \'%s\'', $temp_db_name );
        }
        $rc = $main_dbh->do("DROP ROLE \"$temp_user_name\"");
        if( $rc ) {
            $_log->debugf( 'Dropped temp user \'%s\'', $temp_user_name );
        } else {
            $_log->warningf( 'Probably not managed to drop temp user \'%s\'', $temp_user_name );
        }
        $main_dbh->disconnect();
    };

    # Create database representing object.
    return Database::Temp::DB->new(
        driver    => __PACKAGE__ =~ m/^Database::Temp::Driver::(.*)$/msx,
        name      => $params{'name'},
        cleanup   => $params{'cleanup'} // 0,
        _cleanup  => $_cleanup,
        _start    => $_start,
        init      => $init,
        deinit    => $deinit,
        dsn       => $dsn,
        username  => $name,
        password  => $name,
        attr      => \%attrs,
        info      => \%info,
    );
}

1;
