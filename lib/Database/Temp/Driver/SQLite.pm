package Database::Temp::Driver::SQLite;

use strict;
use warnings;

# ABSTRACT: Create an ad-hoc database, driver for SQLite

# VERSION: generated by DZP::OurPkgVersion

use parent 'Database::Temp::Driver::Base';

use Module::Load::Conditional qw( can_load );
use File::Spec;
use Carp qw( shortmess );

use Log::Any;
use Try::Tiny;

=pod

=encoding utf8

=for stopwords

=over

=cut


sub is_available {
    my %needed = (
        'DBD::SQLite' => 1.41_01,
    );
    if( can_load( modules => \%needed ) ) {
        return 1;
    } else {
        Log::Any->get_logger(category => 'Database::Temp')->infof('Cannot load module %s, %s', %needed);
        return 0;
    }

}

sub new {
    my ($class, %params) = @_;
    my $_log = Log::Any->get_logger(category => 'Database::Temp');

    my $dir = $params{'args'}->{'dir'} // File::Spec->tmpdir();
    my $filename = $params{'name'};
    my $filepath = File::Spec->catfile( $dir, $filename );
    my $dsn = "dbi:SQLite:uri=file:$filepath?mode=rwc";
        $_log->debugf( 'Created temp filepath \'%s\'', $filepath );

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
    );
    my %info = (
        'filepath'          => $filepath,
    );

    # Construct start method
    my $_start = sub {
        my ($dbh, $name, $info, $driver) = @_;
        Log::Any->get_logger(category => 'Database::Temp')->debugf( 'Created temp db \'%s\'', $name );
    };

    # Construct init method
    my $init;
    if( ref $params{'init'} eq 'CODE' ) {
        $init = $params{'init'};
    } else { # SCALAR
        $init = sub {
            my ($dbh, $name, $info, $driver) = @_;
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
            my ($dbh, $name, $info) = @_;
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
        my ($dbh, $name, $info, $driver) = @_;
            $_log->infof('Deleting file %s', $info->{'filepath'});
        unlink $info->{'filepath'};
    };

    # Create database representing object.
    return Database::Temp::DB->new(
        driver    => (__PACKAGE__ =~ m/^Database::Temp::Driver::(.*)$/msx)[0],
        name      => $params{'name'},
        cleanup   => $params{'cleanup'} // 0,
        _cleanup  => $_cleanup,
        _start    => $_start,
        init      => $init,
        deinit    => $deinit,
        dsn       => $dsn,
        username  => undef,
        password  => undef,
        attr      => \%attrs,
        info      => \%info,
    );
}

1;