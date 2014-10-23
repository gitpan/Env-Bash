#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use Env::Bash;
use Test::More;

my $nbr = scalar keys %ENV;
$nbr-- if $ENV{SHLVL};
$nbr-- if $ENV{_};
plan tests  => $nbr + 4 + 5 + 4 + 1 + 1;

# test to check %ENV matched get_env_var

for my $var( sort keys %ENV ) {
    next if $var eq 'SHLVL' || $var eq '_';
    my $pv = $ENV{$var};
    my $mv = get_env_var( $var );
    is( $pv, $mv, "compare $var" );
}

# test for array variables

my( $sb, $name, $var, $i );
my @sb;
my @vars;
my $source = "$Bin/test-source.sh";

$name = 'STOOGES';
@sb = qw( Curly Larry Moe );
$var = get_env_var( $name, Source => $source );
is( $var, $sb[0], "compare sorces $name" );
@vars = get_env_var( $name, ForceArray => 1, Source => $source );
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
$var = get_env_var( $name, Source => $source );
is( $var, $sb[0], "compare sorces $name" );
@vars = get_env_var( $name, ForceArray => 1, Source => $source );
$i = 0;
for my $sb( @sb ) {
    is( $vars[$i++], $sb, "compare sorces $name $sb" );
}

# tests get_env_keys

my @keys = get_env_keys( Source => $source );
ok( grep( /^HOME$/, @keys ), "check HOME in keys" );
ok( grep( /^STOOGES$/, @keys ), "check STOOGES in keys" );
ok( grep( /^SORCERER_MIRRORS$/, @keys ), "check SORCERER_MIRRORS in keys" );
ok( ! grep( /^HAPPYFUNBALL/, @keys ),
    "check HAPPYFUNBALL is NOT in keys" );

# tests AUTOLOAD

$name = 'STOOGES';
@sb = qw( Curly Larry Moe );
$var = Env::Bash::STOOGES( Source => $source );
is( $var, $sb[0], "compare sorces $name ( AUTOLOAD )" );

# check fot bad source script

diag( "several failure messages should follow - that's ok" );
$var = eval { get_env_var( $name, Source => "$Bin/happyfunball" ); };
ok( ! $@, "check missing source failure" );
