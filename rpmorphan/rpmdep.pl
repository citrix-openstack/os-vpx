#!/usr/bin/perl 
###############################################################################
#   rpmdep.pl
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id: rpmdep.pl 117 2008-10-19 16:25:37Z gerbier $
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
###############################################################################
# this program search the full dependency of an installed rpm package
###############################################################################
use strict;
use warnings;

use English '-no_match_vars';

use Getopt::Long;    # arg analysis
use Pod::Usage;      # man page

use File::stat;

use Data::Dumper;    # debug

# library
use File::Basename;
my $dirname = dirname($PROGRAM_NAME);
require $dirname . '/rpmorphan-lib.pl';

# the code should use no "print" calls
# but instead debug, warning, info calls
#########################################################
# is to be defined because rpmorphan-lib need it
sub display_status($) {
	debug( shift @_ );
	return;
}
##########################################################
# resolv problems with characters in names for graphwiz
sub norm($) {
	my $name = shift @_;

	my $norm_name = $name;
	$norm_name =~ s/-/_/g;
	$norm_name =~ s/\./_/g;
	$norm_name =~ s/\+//g;

	return $norm_name;
}
#########################################################
# search the dependency of $name
# no prototype because recursive
sub solve {
	my $name        = shift @_;    # package name
	my $rh_provides = shift @_;    # general provide hash
	my $rh_depends  = shift @_;    # general dependencies hash
	my $rh_files    = shift @_;    # general dependencies hash
	my $rh_res      = shift @_;    # result cache
	my $fh_dot      = shift @_;    # flag for dot
	my $level       = shift @_;    # recurse level

	$level++;

	my $state = 0;                 # state ( 0 for ok)

	foreach my $dep ( keys %{ $rh_depends->{$name} } ) {
		my $debug = "(solve $level) $name -> $dep ";

		# dep may be a package or a file or a virtual
		my $pac;                   # searched package

		# analyse and resolv dependency
		if ( exists $rh_files->{$dep} ) {
			debug("$dep is a package");
			$pac = $dep;
		}
		elsif ( $dep =~ m/^rpmlib/ ) {

			# strange case, but real, for example :
			# rpmlib(PayloadFilesHavePrefix)
			# rpmlib(CompressedFileNames)
			debug( $debug . ' (skip rpmlib)' );
			next;
		}
		elsif ( exists $rh_provides->{$dep} ) {
			debug("$dep is a file");
			$pac = $rh_provides->{$dep};
			$debug .= " -> $pac ";

			#debug($debug);
		}
		else {
			warning("can not find who provide $dep");
			$state++;
			next;
		}

		# filter dependency
		if ( exists $rh_res->{$pac} ) {

			# already found
			debug( $debug . ' (already found)' );
		}
		elsif ( $pac eq $name ) {

			# no dependency on self
			debug( $debug . ' (not on self)' );
		}
		else {
			if ($fh_dot) {
				print {$fh_dot} norm($name) . ' -> ' . norm($pac) . ";\n";
			}
			$rh_res->{$pac} = 1;
			debug($debug);
			my $sub_state =
			  solve( $pac, $rh_provides, $rh_depends, $rh_files, $rh_res,
				$fh_dot, $level );
			$state += $sub_state;
		}

	}    # foreach
	return $state;
}
#########################################################
#
#	main
#
#########################################################
my $version = '0.4';

my $opt_help;
my $opt_man;
my $opt_version;
my $opt_use_cache;
my $opt_clear_cache;
my $opt_verbose;

my $opt_dot;

my %opt = (
	'help'        => \$opt_help,
	'man'         => \$opt_man,
	'verbose'     => \$opt_verbose,
	'version'     => \$opt_version,
	'dot'         => \$opt_dot,
	'use-cache'   => \$opt_use_cache,
	'clear-cache' => \$opt_clear_cache,
);

Getopt::Long::Configure('no_ignore_case');
GetOptions( \%opt, 'help|?', 'man', 'verbose', 'version|V', 'dot=s',
	'use-cache!', 'clear-cache' )
  or pod2usage(2);

init_debug($opt_verbose);

if ($opt_help) {
	pod2usage(1);
}
elsif ($opt_man) {
	pod2usage( -verbose => 2 );
}
elsif ($opt_version) {
	print_version($version);
	exit;
}

# test if a target is set
if ( $#ARGV != 0 ) {
	pod2usage('need a target : package name');
}
my $package = $ARGV[0];

# hash structures to be filled with rpm query
my %files;
my %install_time;
my %provides;
my %depends;
my %virtual;
my %requires;

read_rpm_data( \%opt, \%provides, \%install_time, \%files, \%depends, \%virtual,
	\%requires );

if ( !exists $install_time{$package} ) {
	warning("package $package is not installed");
	exit 1;
}

# first we have to change order used %depends
my %depends_from;
foreach my $key1 ( keys %depends ) {
	foreach my $key2 ( keys %{ $depends{$key1} } ) {

		# ex key2 = afick-gui key1 = afick
		$depends_from{$key2}{$key1} = 1;
	}
}

# same for provides
my %is_provided_by;
foreach my $key1 ( keys %provides ) {
	foreach my $key2 ( @{ $provides{$key1} } ) {

		# key2 is provided by $key1 package
		$is_provided_by{$key2} = $key1;
	}
}

# dot graph ?
my $fh_dot;
if ($opt_dot) {

	# open output file
	## no critic (RequireBriefOpen)
	if ( open $fh_dot, '>', $opt_dot ) {
		print {$fh_dot} "digraph \"G\" {\n";
	}
	else {
		warning("can not write to $opt_dot file : $!\n");
		$opt_dot = 0;
	}
}

debug('2 : solve');
my %res;
my $state =
  solve( $package, \%is_provided_by, \%depends_from, \%files, \%res, $fh_dot,
	0 );

my $res = join q{,}, sort keys %res;
if ($res) {
	info("$package depends upon $res");
}
else {
	info("$package has no dependencies");
}

if ($opt_dot) {
	print {$fh_dot} "}\n";
	close $fh_dot or die "problem to close dot file :$OS_ERROR\n";
}

exit $state;
## no critic (ProhibitUnreachableCode)
__END__

=head1 NAME

rpmdep - display the full dependency of an installed rpm package

=head1 DESCRIPTION

rpmdep search recursively for package dependencies. 
It resolvs all dependencies to package names.
It can also prepare a file to build a graph of dependencies, with graphviz.

=head1 SYNOPSIS

rpmdep.pl  [options] package

options:

   -help                brief help message
   -man                 full documentation
   -V, --version        print version
   -use-cache		use cache file instead rpm query
   -clear-cache		clear cache file

   -verbose             verbose
   -dot dotfile		build a dot file for graphviz

=head1 REQUIRED ARGUMENTS

the package to resolv

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Print the manual page and exits.

=item B<-version>

Print the program release and exit.

=item B<-verbose>

The program works and print debugging messages.

=item B<-dot>

create a dot file to be used by graphviz

=item B<-use-cache>

the rpm query may be long (10 to 30 s). If you will run an rpmorphan tool
several time, this option will allow to gain a lot of time :
it save the rpm query on a file cache (first call), then
use this cache instead quering rpm (others calls).

=item B<-clear-cache>

to remove cache file. Can be used with -use-cache to write
a new cache.

=back

=head1 USAGE

rpmdep.pl --use-cache -dot bash.dot bash

dot -Tps bash.dot -o bash.ps

=head1 FILES

the program can use the /tmp/rpmorphan.cache file

=head1 DIAGNOSTICS

the verbose mode allow to see all the recursive work

others messages are

=over 8

=item B<package ... is not installed>

this is not a name of an installed package

=item B<... has no dependencies>

this can comes for some admin tools (ash for example)

=item B<... depends upon (list)>

return a list of sorted and comma separated packages

=back

=head1 EXIT STATUS

O if all is ok

>=1 if a problem

=head1 CONFIGURATION

nothing

=head1 DEPENDENCIES

you should use graphviz to build graph from 

=head1 INCOMPATIBILITIES

not known

=head1 BUGS AND LIMITATIONS

the program does not work well on program installed
with several versions

=head1 NOTES

this program can be used as "normal" user

=head1 SEE ALSO

=for man
\fIrpm\fR\|(1) for rpm call
.PP
\fIrpmorphan\fR\|(1)
.PP
\fIrpmusage\fR\|(1)
.PP
\fIrpmduplicates\fR\|(1)

=for html
<a href="rpmorphan.1.html">rpmorphan(1)</a><br />
<a href="rpmusage.1.html">rpmusage(1)</a><br />
<a href="rpmduplicates.1.html">rpmduplicates(1)</a><br />

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 by Eric Gerbier
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=head1 AUTHOR

Eric Gerbier

you can report any bug or suggest to gerbier@users.sourceforge.net

=cut

