package Database::Temp::Driver::CSV;

use strict;
use warnings;

# ABSTRACT: Create an ad-hoc database, driver for CSV

# VERSION: generated by DZP::OurPkgVersion

use Module::Load::Conditional qw( can_load );

use Carp qw( shortmess );
use File::Path qw( make_path remove_tree );
use File::Spec;

use Log::Any;
use Try::Tiny;

=pod

=encoding utf8

=cut


=head2 is_available

Can this driver provide a database?

Return boolean.

=cut

sub is_available {
    my $_log = Log::Any->get_logger(category => 'Database::Temp');
    my %needed = (
        'DBD::CSV' => 0.57,
    );
    if( ! can_load( modules => \%needed ) ) {
        $_log->infof('Cannot load module %s, %s', %needed);
        return 0;
    }
    return 1;
}

=head2 new

Create a temp database.

User should never call this subroutine directly, only via L<Database::Temp>.

=cut

sub new {
    my ($class, %params) = @_;
    my $_log = Log::Any->get_logger(category => 'Database::Temp');

    my $dir = $params{'args'}->{'dir'} // File::Spec->tmpdir();
    my $db_dir = $params{'name'};
    my $dirpath = File::Spec->catfile( $dir, $db_dir );
    make_path( $dirpath, { verbose => 0, mode => 0o711, } );
    my $dsn = 'dbi:CSV:';
    $_log->debugf( 'Created temp dirpath \'%s\'', $dirpath );

    my %attrs = (
        'AutoCommit'        => 1,
        'RaiseError'        => 1,
        'PrintError'        => 1,
        'RaiseWarn'         => 1,
        'PrintWarn'         => 1,
        'TaintIn'           => 1,
        'TaintOut'          => 0,
        'TraceLevel'        => 0,
        'f_dir'             => $dirpath,
        'f_ext'             => '.csv/r',
        'f_encoding'        => 'utf8',
    );
    my %info = (
        'dirpath'           => $dirpath,
    );

    # Construct start method
    my $_start = sub {
        my ($dbh, $name) = @_;
        Log::Any->get_logger(category => 'Database::Temp')->debugf( 'Created temp db \'%s\'', $name );
    };

    # Construct init method
    my $init;
    if( ref $params{'init'} eq 'CODE' ) {
        $init = $params{'init'};
    } else { # SCALAR
        # Attn. CSV does not have transactions (begin_work, commit)
        $init = sub {
            my ($dbh) = @_;
            foreach my $row (split qr/;\s*/msx, $params{'init'}) {
                $dbh->do( $row );
            }
            return;
        }
    }
    # Construct deinit method
    my $deinit;
    if( ref $params{'deinit'} eq 'CODE' ) {
        $deinit = $params{'deinit'};
    } else { # SCALAR
        $deinit = sub {
            my ($dbh) = @_;
            foreach my $row (split qr/;\s*/msx, $params{'deinit'}) {
                $dbh->do( $row );
            }
            return;
        }
    }

    # Construct _cleanup method
    my $_cleanup = sub {
        my ($dbh, $name, $info) = @_;
            $_log->infof('Deleting dir %s for temp db \'%s\'', $info->{'dirpath'}, $name);
        remove_tree($info->{'dirpath'}, { safe => 1, });
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
