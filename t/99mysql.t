use Test::More;
use Test::Deep;

#plan skip_all => "Not running RDBM tests without APACHE_SESSION_MAINTAINER=1"
#  unless ($ENV{APACHE_SESSION_MAINTAINER} || $ENV{TRAVIS});
plan skip_all => "Optional modules (Test::Database, DBD::mysql, DBI) not installed"
  unless eval {
               require Test::Database;
               require DBD::mysql;
               require DBI;
              };

if ($ENV{TRAVIS}) {
    my $cfg = << 'EOT';
    driver_dsn  = dbi:mysql:
    username    = root
EOT
    Test::Database->load_config(\$cfg);
}

my @db_handles = Test::Database->handles('mysql');

plan skip_all => "No mysql handle reported by Test::Database"
  unless @db_handles;

plan tests => 13;

my $package = 'Apache::Session::MySQL';
use_ok $package;

my $mysql = $db_handles[0];
my $dsn = $mysql->dsn();
my $uname = $mysql->username();
my $upass = $mysql->password();
diag "Mysql version ".$mysql->driver->version;

my @tables_used = qw/sessions s/;
sub drop_tables {
    my $dbh = shift;
    foreach my $table (@_) {
        $dbh->do("DROP TABLE IF EXISTS $table");
    }
}

{
    my $dbh1 = $mysql->dbh();
    drop_tables($dbh1, @tables_used);
    foreach my $table (@tables_used) {
        $dbh1->do(<<"EOT");
  CREATE TABLE $table (
    id char(32) not null primary key,
    a_session text
  );
EOT
    }
}

my $session = {};

tie %{$session}, $package, undef, {
    DataSource     => $dsn,
    UserName       => $uname,
    Password       => $upass,
    LockDataSource => $dsn,
    LockUserName   => $uname,
    LockPassword   => $upass,
};

ok tied(%{$session}), 'session tied';

ok exists($session->{_session_id}), 'session id exists';

my $id = $session->{_session_id};

my $foo = $session->{foo} = 'bar';
my $baz = $session->{baz} = ['tom', 'dick', 'harry'];

untie %{$session};
undef $session;
$session = {};

tie %{$session}, $package, $id, {
    DataSource     => $dsn,
    UserName       => $uname,
    Password       => $upass,
    LockDataSource => $dsn,
    LockUserName   => $uname,
    LockPassword   => $upass,
};

ok tied(%{$session}), 'session tied';

is $session->{_session_id}, $id, 'id retrieved matches one stored';

cmp_deeply $session->{foo}, $foo, "Foo matches";
cmp_deeply $session->{baz}, $baz, "Baz matches";

untie %{$session};
undef $session;
$session = {};

tie %{$session}, $package, undef, {
    TableName      => 's',
    DataSource     => $dsn,
    UserName       => $uname,
    Password       => $upass,
    LockDataSource => $dsn,
    LockUserName   => $uname,
    LockPassword   => $upass,
};

ok tied(%{$session}), 'session tied';

ok exists($session->{_session_id}), 'session id exists';

untie %{$session};
undef $session;
$session = {};

my $dbh = DBI->connect($dsn, $uname, $upass, {RaiseError => 1});

tie %{$session}, $package, $id, {
    Handle     => $dbh,
    LockHandle => $dbh,
};

ok tied(%{$session}), 'session tied';

is $session->{_session_id}, $id, 'id retrieved matches one stored';

cmp_deeply $session->{foo}, $foo, "Foo matches";
cmp_deeply $session->{baz}, $baz, "Baz matches";

tied(%{$session})->delete;
untie %{$session};
$dbh->disconnect;

unless ($ENV{TRAVIS}) {
    my $dbh1 = $mysql->dbh();
    drop_tables($dbh1, @tables_used);
}

