package Env::Bash;

use 5.008;
use strict;
use warnings;

use Data::Dumper;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT    = qw( get_env_var get_env_keys );

our $VERSION = '0.00_01';
$VERSION = eval $VERSION;

=pod

=head1 NAME

Env::Bash - Perl extension for accessing B<ALL> environment variables
in the Borne Again Shell ( bash ).

=head1 SYNOPSIS

  use Env::Bash;

Standard interface:

  my @var = get_env_var( "SORCERER_MIRRORS",
                         Source => "/etc/sorcery/config", );
  print "SORCERER_MIRRORS via get_env_var:\n",
  join( "\n", @var ), "\ncount = ", scalar @var, "\n";

  @var = Env::Bash::SORCERER_MIRRORS
      ( Source => "/etc/sorcery/config", );
  print "SORCERER_MIRRORS via name:\n",
  join( "\n", @var ), "\ncount = ", scalar @var, "\n";

  my @keys = get_env_keys( Source => "/etc/sorcery/config", );
  print "first 10 keys:\n", map { " $_\n" } @keys[0..9];

=cut

# -------------------------
# Implementation - AUTOLOAD
# -------------------------

sub AUTOLOAD {
    my $name = our $AUTOLOAD;
    return if $name =~ /DESTROY$/;
    $name =~ s/^.*:://;
    return unless $name =~ /^[_A-Z][_A-Z0-9]*$/;
    my $s = shift;
    $s && ref $s && $s->isa( 'Env::Bash' ) ?
        $s->get( $name, @_ ) :
        _get_env_var( $name, $s, @_ );
}

# -------------------------
# Implementation - exported
# -------------------------

sub get_env_var
{
    _get_env_var( @_ );
}

sub get_env_keys
{
    my %options = _options( @_ );
    $options{GrepRegex} = '^[_A-Z][_A-Z0-9]\+\>' unless $options{GrepRegex};
    my @sources = _sources( %options );
    my $script = @sources ? join( ';', @sources ).';' : '';
    $script .= "set | grep \"$options{GrepRegex}\"";
    my $result = _execute_script( $script, %options );
    my @keys = ();
    for my $item( split /\n/, $result ) {
        next unless $item;
        my( $name, $value ) = split /=/, $item;
        next unless $name && defined $value;
        next if $name eq 'BASH_EXECUTION_STRING';
        push @keys, $name;
    }
    @keys = sort @keys;
    return unless defined wantarray;
    wantarray ? @keys : \@keys;
}

=pod

Object oriented interface:

  my $be = Env::Bash->new( Source => "/etc/sorcery/config",
                           Keys => 1, );
  my @var = $be->get( "SORCERER_MIRRORS" );
  print "SORCERER_MIRRORS via get:\n",
  join( "\n", @var ), "\ncount = ", scalar @var, "\n";
    
  @var = $be->SORCERER_MIRRORS;
  print "SORCERER_MIRRORS via name:\n",
  join( "\n", @var ), "\ncount = ", scalar @var, "\n";

  $be = Env::Bash->new( Keys => 1,);
  @var = $be->HOSTTYPE;
  print "HOSTTYPE via name:\n",
  join( "\n", @var ), "\ncount = ", scalar @var, "\n";

  if( $be->exists( 'BASH_VERSINFO' ) ) {
      print "BASH_VERSINFO =>\n ",
      join( "\n ", $be->BASH_VERSINFO ), "\n";
  }

  my %options = $be->options( [], Keys => 1 );

=cut

# -------------------------
# Implementation - oo i/f
# -------------------------

sub new
{
    my( $invocant, @options ) = @_;
    my $class = ref( $invocant ) || $invocant;
    my $s = { options => { GrepRegex => '^[_A-Z][_A-Z0-9]\+\>', }, };
    bless $s, $class;
    $s->options( @options );
    $s->keys() if $s->{options}{Keys};
    $s;
}

sub get
{
    my( $s, $name, @options ) = @_;
    my %options = $s->options( @options );
    _get_env_var( $name, %options );
}

sub exists
{
    my( $s, $key ) = @_;
    unless( $s->{keys} ) {
        $s->{options}{Keys} = 1;
        $s->keys();
    }
    grep /^$key$/, @{$s->{keys}};
}

sub keys
{
    my( $s, @options ) = @_;
    $s->options( @options );
    if( exists $s->{keys} && @{$s->{keys}} ) {
        return unless defined wantarray;
        return wantarray ? @{$s->{keys}} : $s->{keys};
    }
    my @keys = get_env_keys( %{$s->{options}} );
    $s->{keys} = [ @keys ];
    return unless defined wantarray;
    wantarray ? @keys : \@keys;
}

sub reload_keys
{
    my( $s, @options ) = @_;
    delete $s->{keys};
    $s->keys( @options );
}

sub options
{
    my $s = shift;
    my %options = _options( @_ );
    unless( %options ) {
        return unless defined wantarray;
        return wantarray ? %{$s->{options}} : $s->{options};
    }
    $s->{options} = { %{$s->{options}}, %options };
    return unless defined wantarray;
    return wantarray ? %{$s->{options}} : $s->{options};
}

=pod

Tie HASH interface:

  my %env = ();
  tie %env, "Env::Bash", Source => "/etc/sorcery/config", ForceArray => 1;

  my $var = $env{SORCERER_MIRRORS};
  print "SORCERER_MIRRORS via tied hash:\n",
  join( "\n", @$var ), "\ncount = ", scalar @$var, "\n";

  $var = $env{HOSTTYPE};
  print "HOSTTYPE via tied hash:\n",
  join( "\n", @$var ), "\ncount = ", scalar @$var, "\n";

  while( my( $key, $value ) = each %env ) {
      print "$key =>\n ", join( "\n ", @$value ), "\n";
  } 

=cut

# -------------------------
# Implementation - tie hash
# -------------------------

sub TIEHASH
{
    my( $invocant, @options ) = @_;
    my $class = ref( $invocant ) || $invocant;
    my $s = { options => { GrepRegex => '^[_A-Z][_A-Z0-9]\+\>', }, };
    bless $s, $class;
    $s->options( @options );
    $s->keys();
    $s;
}

sub FETCH
{
    my( $s, $key ) = @_;
    return undef unless $s->EXISTS( $key );
    _get_env_var( $key, %{$s->{options}} );
}

sub STORE
{
    Carp::croak( "Tied hash is read-only\n" );
}

sub DELETE
{
    Carp::croak( "Tied hash is read-only\n" );
}

sub CLEAR
{
    Carp::croak( "Tied hash is read-only\n" );
}

sub EXISTS
{
    my( $s, $key ) = @_;
    grep /^$key$/, @{$s->{keys}};
}

sub FIRSTKEY
{
    my $s = shift;
    $s->{keys}[0];
}

sub NEXTKEY
{
    my( $s, $prevkey ) = @_;
    my $idx = 0;
    return $s->FIRSTKEY() unless $prevkey;
    for( ; $idx < @{$s->{keys}}; $idx++ ) {
        last if $s->{keys}[$idx] eq $prevkey;
    }
    $s->{keys}[++$idx];
}

# -------------------------
# 'Private' subs
# ( denoted by leading '_' )
# -------------------------

sub _get_env_var
{
    return unless defined wantarray;
    my $name = shift;
    my %options  = _options( @_ );
    return undef unless $name;

    my @script =
    (
     _sources( %options ),
     _script_contents( $name ),
     );
    my $script = join ";", @script;
    print STDERR "script:\n$script\n" if $options{Debug};
    
    my $result = _execute_script( $script, %options );

    my $href = _load_contents( $result, %options );
    my @ret = $href->{$name} ? @{$href->{$name}} : () ;
    if( $options{ForceArray} ) {
        return wantarray ? @ret : \@ret;
    }
    wantarray ? @ret : ( defined $ret[0] ? $ret[0] : '' );
}

sub _sources
{
    my %options = _options( @_ );
    my @sources =
        map { /^\. / ? $_ : ". $_"; }
    $options{Source} ?
        ( ref $options{Source} && ref $options{Source} eq 'ARRAY' ?
          @{$options{Source}} : $options{Source} ) : ();
    @sources;
}

sub _script_contents
{
    my( $name ) = @_;
    (
     "for element in \$(seq 0 \$((\${#${name}[@]} - 1)))",
     "do echo \"<<8774$name>>\${${name}[\$element]}<<4587>>\"",
     "done",
     );
}

sub _execute_script
{
    my $script = shift;
    my %options = _options( @_ );
    my $result = eval { `$script 2>&1` };
    Carp::croak
        ( "Oops: internal bash script error or your shell is not bash:\n".
          $result ) if $? || $@;
    print STDERR "script output:\n$result\n" if $options{Debug};
    $result;
}

sub _load_contents
{
    my $data = shift;
    my %options = _options( @_ );
    my $content = {};
    pos( $data ) = 0;
    while( $data =~ /<<8774(.+?)>>(.+?)<<4587>>/g ) {
        push @{$content->{$1}}, $2;
    }
    print STDERR "content: ", Dumper( $content ) if $options{Debug};
    $content;
}

sub _options
{
    my %options;
    if( $_[0] && ref $_[0] && ref $_[0] eq 'ARRAY' ) {
        shift; %options = ( @_, ForceArray => 1, );
    } else {
        %options = @_;
    }
    unless( %options ) {
        return unless defined wantarray;
        return wantarray ? () : [];
    }
    return unless defined wantarray;
    return wantarray ? %options : \%options;
}

1;

__END__

=pod

=head1 DESCRIPTION

B<Env::Bash> enables perl access to B<ALL> bash environment variables
( including those that may be bash arrays ).
But you say:
"That doesn't make sense; perl already has the %ENV hash. Why not
use that?". Well, please run:

  $ perl -e 'print "$_ = $ENV{$_}\n" for sort keys %ENV;'

and:

  $ set | grep "^[A-Z]"

Now compare the outputs. See, perl's list is much shorter than the bash
list. This is because the environment passed to perl contains only variables
that have been exported( I think ). There is no pure-perl way to get all
the variables in the rnning shell; also, forget about getting all the elements
of variables that are bash arrays!

In the following discussion and examples, I show how I use this module with
B<Linux Sorcerer>. For my fellow Sorcererites, this is fine, for others,
please see L<A SHAMELESS PLUG FOR LINUX SORCERER> below.

=head2 Options

The folling options, specified as B<func( ..., key1 =E<gt> value1, ..., )> are
provided.

=over 4

=item Debug

Prints debugging information to STDERR.

Values B<0 or 1>, default B<0>.

=item ForceArray or []

Defines how enrvironment variable data are returned. Especially useful if
you expect to handle bash array variables. For example, an array variable,
'BASH_VERSINFO', returns data as follows:

                       scalar context      list context
                       --------------      ------------
  ForceArray => 0            3             ( 3,
                                             00,
                                             0,
                                             1.
                                             'release',
                                             'i686-pc-linux-gnu' )
  ForceArray => 1         reference        ( 3,
                          to array           00,
                          returned in        0,
                          list context.      1.
                                             'release',
                                             'i686-pc-linux-gnu' )

As a shortcut, ForceArray may be specified by placing the empty
array reference token '[]' as the B<first>, and only first, argument
of the option arguments.

Values B<0 or 1>, default B<0>.

=item GrepRegex

The regular expression to use in the bash script( created and run internally )
to extract variables from the bash environment. The script uses this
contrruct to get a list of environment variable names:

  set | grep "GrepRegex" '

Default: B<'^[_A-Z][_A-Z0-9]\+\>'>( uppercase variables starting with
a non-numeric .)

=item Keys

Whether or not to load an array of environment variable names.

Values B<0 or 1>, default B<0>.

=item Source

The path name of one or more executable bash scripts, separated
with semicolins, whith which to 'source' ( execute with a leading dot )
before extracting environment. Any variables set in these scripts
is then available for this module. The leading dot is prepended if not
supplied.

Values: B<any list of executable bash scripts>, Default B<none>.

=back

=head2 Standard interface

The non-object oriented interface.

=head3 get_env_var

=over 4

=item prototype

get_env_var( options...);

=item options used

B<Debug>, B<ForceArray>, B<GrepRegex>, B<Source>.

=item operation

Returns the contents of the specified environment variable in scalar or
list context as described above. If the requested variable is not present,
a false value ( not 'undef' ) is returned.

=back

=head3 Env::Bash::VARIABLE_NAME

=over 4

=item prototype

Env::Bash::VARIABLE_NAME( options...);

=item note

This is the AUTOLOAD version if 'get_env_var'.

=back

=head3 get_env_keys

=over 4

=item prototype

get_env_keys( options...);

=item options used

B<Debug>, B<ForceArray>, B<GrepRegex>, B<Source>.

=item operation

Returns a sorted B<array> ( list context ) or an B<array reference>
( scalar context ) of the keys in the current bash environment.

=back

=head2 Object oriented interface

=head3 new

=over 4

=item prototype

Env::Bash->new( options... );

=item options used

B<Debug>, B<ForceArray>, B<GrepRegex>, B<Keys>, B<Source>.

=item operation

Returns a Env::Bash object with the specified options saved
in the object so they do not have to be repeated in subsequent method calls.

=back

=head3 get

=over 4

=item prototype

$env_bash_obj->get( options... );

=item options used

B<Debug>, B<ForceArray>, B<GrepRegex>, B<Source>.

=item operation

Returns the contents of the specified environment variable in scalar or
list context as described above. If the requested variable is not present,
a false value ( not 'undef' ) is returned.

=back

=head3 VARIABLE_NAME

=over 4

=item prototype

$env_bash_obj->VARIABLE_NAME( options... );

=item options used

B<Debug>, B<ForceArray>, B<GrepRegex>, B<Source>.

=item operation

This is the AUTOLOAD version of 'get'.

=back

=head3 exists

=over 4

=item prototype

$env_bash_obj->exists( 'VARIABLE_NAME' );

=item options used

B<None>.

=item operation

Returns B<true> or B<false> to indicate whether or not the
environment exists.

=back

=head3 keys

=over 4

=item prototype

$env_bash_obj->keys( options... );

=item options used

B<Debug>, B<ForceArray>, B<GrepRegex>, B<Source>.

=item operation

Returns a sorted B<array> ( list context ) or an B<array reference>
( scalar context ) of the keys in the current bash environment.

=back

=head3 reload_keys

=over 4

=item prototype

$env_bash_obj->reload_keys( options... );

=item options used

B<Debug>, B<ForceArray>, B<GrepRegex>, B<Source>.

=item operation

Reloads the environment key array and
returns a sorted B<array> ( list context ) or an B<array reference>
( scalar context ) of the keys in the current bash environment.

=back

=head3 options

=over 4

=item prototype

$env_bash_obj->options( options... );

=item options used

B<ANY>.

=item operation

Returns a the current options hash after setting any options
specified.

=back

=head2 Tie HASH interface

=head3 tie

=over 4

=item prototype

  my %env = ();
  tie %env, "Env::Bash", options...;

=item options used

B<Debug>, B<ForceArray>, B<GrepRegex>, B<Keys>, B<Source>.

=item operation

Ties a hash variable to Env::Bash. The resulting hash may be used like a normal
hash, execept it is read-only. Note: if B<ForceArray> is specified, the
resulting hash is a hash of array references.

=back

=head3 hash operations

=over 4

=item allowed

access ( $var = $env{SOME_VARIABLE_NAME} ), exists, each, keys, values,

=item not allowed

assign ( $env{SOME_VARIABLE_NAME} = $var ), delete,
clear ( as %env = (); ).

=item note

Unlike normal hashs, the keys are maintained in sorted order, therefore
there is no need tor use the '... sort keys ...' construct unless you
whish to process in some non-standard order.

=back

=head2 Export

B<get_env_var> and B<get_env_keys> are unconditionally exported.

=head1 A SHAMELESS PLUG FOR LINUX SORCERER

B<Linux Sorcerer>, by Kyle Sallee, is a great Linux distribution. It gives
you one of the most up-to-date and fastest Linux systems available. Sorcerer
is based upon package 'source', not pre-compiled rpm's. You ( with the
bash scripts supplied by Sorcerer ) compile and install the packages optimized
to your maching. You configure your own kernel for the best, leanest kernel
matching your environment. B<Current> packages are made available as soon
as they are stable; you do not have to wait six months for the next release
of your distribtion.

With the gain there is always the pain:

=over 4

=item Installing updated packages is slower.

=item The documentation is wanting.

=item No fancy 'x' windows installer; the command line rules!

=item Not for the beginner.

=back

All and all, I love it! Check it out at L<http://sorcerer.wox.org>

=head1 SEE ALSO

The 'Advanced Bash-Scripting Guide' at L<http://www.tldp.org/LDP/abs/html/>.

=head1 AUTHOR

Beau E. Cox, E<lt>beaucox@hawaii.rr.comE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Beau E. Cox.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
