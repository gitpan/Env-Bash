#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use Env::Bash;
use Test::More;

my $nbr = scalar keys %ENV;
$nbr-- if $ENV{SHLVL};
$nbr-- if $ENV{_};
plan tests  => $nbr + 4 + 7 + 8 + 1 + 1;

# test to check %ENV matched get_env_var

my $be = Env::Bash->new;
for my $var( sort keys %ENV ) {
    next if $var eq 'SHLVL' || $var eq '_';
    my $pv = $ENV{$var};
    my $mv = $be->$var;
    is( $pv, $mv, "compare $var" );
}

# test for array variables

my( $sb, $name, $var, $i );
my @sb;
my @vars;
my $source = "$Bin/test-source.sh";

$name = 'STOOGES';
@sb = qw( Curly Larry Moe );
$var = $be->get( $name, ForceArray => 0, Source => $source );
is( $var, $sb[0], "compare sorces $name" );
my %options = $be->options( [] );
is( $options{ForceArray}, 1, "check that ForceArray is set" );
is( $options{Source}, $source, "check that Source is set" );
@vars = $be->get( $name );
$i = 0;
for my $sb( @sb ) {
    is( $vars[$i++], $sb, "compare sorces $name $sb" );
}

$name = 'SORCERER_MIRRORS';
@sb = qw(
            http://distro.ibiblio.org/pub/linux/distributions/sorcerer
            ftp://ftp.phy.bnl.gov/pub/sorcerer
            ftp://sorcerer.mirrors.pair.com
            http://sorcerer.mirrors.pair.com
            );
$var = $be->$name( ForceArray => 0, Source => $source );
is( $var, $sb[0], "compare sorces $name" );
@vars = $be->$name( [], );
$i = 0;
for my $sb( @sb ) {
    is( $vars[$i++], $sb, "compare sorces $name $sb" );
}

# tests keys

my @keys = $be->keys( Source => $source );
ok( grep( /^HOME$/, @keys ), "check HOME in keys" );
ok( grep( /^STOOGES$/, @keys ), "check STOOGES in keys" );
ok( grep( /^SORCERER_MIRRORS$/, @keys ), "check SORCERER_MIRRORS in keys" );
ok( ! grep( /^HAPPYFUNBALL$/, @keys ),
    "check HAPPYFUNBALL is NOT in keys" );
ok( $be->exists( 'SORCERER_MIRRORS' ), "exists SORCERER_MIRRORS" );
ok( ! $be->exists( 'HAPPYFUNBALL', @keys ),
    "! exists HAPPYFUNBALL" );
$be->reload_keys;
ok( $be->exists( 'STOOGES' ), "exists STOOGES after reload_keys" );
ok( ! $be->exists( 'BETTY_WHITE', @keys ),
    "! exists BETTY_WHITE after reload_keys" );

# tests AUTOLOAD

$name = 'STOOGES';
@sb = qw( Curly Larry Moe );
$var = $be->STOOGES( Source => $source, ForceArray => 0 );
is( $var, $sb[0], "compare sorces $name ( AUTOLOAD )" );

# check for bad source script

diag( "several failure messages should follow - that's ok" );
$var = eval { $be->$name( Source => "$Bin/happyfunball" ); };
ok( ! $@, "check missing source failure" );
