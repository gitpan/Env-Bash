#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use Env::Bash;
use Test::More;

my $nbr = scalar keys %ENV;
$nbr-- if $ENV{SHLVL};
$nbr-- if $ENV{_};
plan tests  => $nbr + 4 + 5 + 4 + 3 + 1;

my %env = ();

# test to check %ENV matched get_env_var

tie %env, "Env::Bash";
for my $var( sort keys %ENV ) {
    next if $var eq 'SHLVL' || $var eq '_';
    my $pv = $ENV{$var};
    my $mv = $env{$var};
    is( $pv, $mv, "compare $var" );
}

# test for array variables

my( $sb, $name, $var, $i );
my @sb;
my @vars;
my $source = "$Bin/test-source.sh";

$name = 'STOOGES';
@sb = qw( Curly Larry Moe );
tie %env, "Env::Bash", Source => $source;
is( $env{$name}, $sb[0], "compare sorces $name" );
tie %env, "Env::Bash", [], Source => $source;
$var = $env{$name};
$i = 0;
for my $sb( @sb ) {
    is( $var->[$i++], $sb, "compare sorces $name $sb" );
}

$name = 'SORCERER_MIRRORS';
@sb = qw(
            http://distro.ibiblio.org/pub/linux/distributions/sorcerer
            ftp://ftp.phy.bnl.gov/pub/sorcerer
            ftp://sorcerer.mirrors.pair.com
            http://sorcerer.mirrors.pair.com
            );
tie %env, "Env::Bash", Source => $source;
is( $env{$name}, $sb[0], "compare sorces $name" );
tie %env, "Env::Bash", [], Source => $source;
$var = $env{$name};
$i = 0;
for my $sb( @sb ) {
    is( $var->[$i++], $sb, "compare sorces $name $sb" );
}

# tests exists

tie %env, "Env::Bash", Source => $source;
ok( exists $env{HOME},             "check HOME exists" );
ok( exists $env{STOOGES},          "check STOOGES exists" );
ok( exists $env{SORCERER_MIRRORS}, "check SORCERER_MIRRORS exists" );
ok( ! exists $env{HAPPYFUNBALL},   "check HAPPYFUNBALL ! exists" );

# check SourceOnly

@sb = qw( SORCERER_MIRRORS STOOGES );
$i = 0;
tie %env, "Env::Bash", Source => $source, SourceOnly => 1;
while( my( $key, $value ) = each %env ) {
    ok( $key eq $sb[$i++], "check SourceOnly key $key" ) if $i < @sb;
} 
ok( $i == @sb, "check SourceOnly key count" );

# check for bad source script

diag( "several failure messages should follow - that's ok" );
eval { tie %env, "Env::Bash", Source => "$Bin/happyfunball"; };
ok( ! $@, "check missing source failure" );
