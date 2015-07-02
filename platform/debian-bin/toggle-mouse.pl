#!/usr/bin/perl
use strict;
use warnings;

my @settings = `synclient`;
my $state;

for (@settings)
{
    if (/TouchpadOff\s*=\s*(\d)/)
    {
	$state = $1;
	last;
    }
}

my $command = 'synclient TouchpadOff=' . ($state ? '0' : '1');

system ($command);
