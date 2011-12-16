#!/usr/bin/perl 
###############################################################################
#   rpmorphan-lib.pl
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id: rpmorphan-lib.pl 226 2010-04-27 08:35:39Z gerbier $
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
use strict;
use warnings;

use English '-no_match_vars';

use Data::Dumper;    # debug

# the code should use no "print" calls
# but use instead debug, warning, info calls
###############################################################################
sub nodebug {
	return;
}
###############################################################################
sub backend_debug {
	my $text = $_[0];
	print "debug $text\n";
	return;
}
###############################################################################
# change debug subroutine
# this way seems better than previous one as
# - it does not need any "global" verbose variable
# - it suppress any verbose test (quicker)
sub init_debug($) {
	my $verbose = shift @_;

	# to avoid error messages
	## no critic ( NoWarnings );
	no warnings 'redefine';
	## use critic;

	if ($verbose) {
		*debug = \&backend_debug;
	}
	else {
		*debug = \&nodebug;
	}

	use warnings 'all';
	return;
}
###############################################################################
# used to print warning messages
sub warning($) {
	my $text = shift @_;
	warn "WARNING $text\n";
	return;
}
###############################################################################
# used to print normal messages
sub info($) {
	my $text = shift @_;
	print "$text\n";
	return;
}
###############################################################################
sub print_version($) {
	my $version = shift @_;
	info("$PROGRAM_NAME version $version");
	return;
}
#########################################################
# used to check on option
sub is_set($$) {
	my $rh_opt = shift @_;    # hash of program arguments
	my $key    = shift @_;    # name of desired option

	my $r_value = $rh_opt->{$key};
	return ${$r_value};
}
#########################################################
# apply a filter on package list according program options
sub rpmfilter($$) {
	my $rh_opt      = shift @_;
	my $rh_list_pac = shift @_;

	display_status('apply filters');

	# we just want the list of keys
	my @list = keys %{$rh_list_pac};

	if ( is_set( $rh_opt, 'all' ) ) {
		debug('all');
		return @list;
	}
	else {
		debug('guess');

		my @filtered_list;
		if ( is_set( $rh_opt, 'guess-perl' ) ) {
			debug('guess-perl');
			my @res = grep { /^perl/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-python' ) ) {
			my @res = grep { /^python/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-pike' ) ) {
			my @res = grep { /^pike/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-ruby' ) ) {
			my @res = grep { /^ruby/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-common' ) ) {
			my @res = grep { /-common$/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-data' ) ) {
			my @res = grep { /-data$/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-doc' ) ) {
			my @res = grep { /-doc$/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-dev' ) ) {
			my @res = grep { /-devel$/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-lib' ) ) {
			my @res = grep { /^lib/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-custom' ) ) {
			my $regex = ${ $rh_opt->{'guess-custom'} };
			my @res = grep { /$regex/ } @list;
			push @filtered_list, @res;
		}
		return @filtered_list;
	}
}
#########################################################
# difference between 2 date in unix format
# return in days
sub diff_date($$) {
	my $now  = shift @_;    # current
	my $time = shift @_;    #

	# convert from seconds to days
	## no critic(ProhibitParensWithBuiltins)
	return int( ( $now - $time ) / 86_400 );
}
#########################################################
# return the date (unix format) of last access on a package
# (scan all inodes for atime) and the name of the file
sub get_last_access($) {
	my $ra_files = shift @_;    # array of file names

	my $last_date = 0;          # means a very old date for linux : 1970
	my $last_file = q{};
  FILE: foreach my $file ( @{$ra_files} ) {
		next FILE unless ( -e $file );
		my $stat  = stat $file;
		my $atime = $stat->atime();

		if ( $atime > $last_date ) {
			$last_date = $atime;
			$last_file = $file;
		}
	}
	return ( $last_date, $last_file );
}
#########################################################
# depending the cache option, return a command to execute
# - as an rpm query (piped)
# - as a cache file to open
sub init_cache($) {
	my $rh_opt = shift @_;    # hash of program arguments

	# the main idea is to reduce the number of call to rpm in order to gain time
	# the ';' separator is used to separate fields
	# the ' ' separator is used to separate data in fields arrays

# note : we do not ask for PROVIDEFLAGS PROVIDEVERSION REQUIREFLAGS REQUIREVERSION
	## no critic ( RequireInterpolationOfMetachars );
	my $rpm_cmd =
'rpm -qa --queryformat "%{NAME};[%{REQUIRENAME} ];[%{PROVIDES} ];[%{FILENAMES} ];%{INSTALLTIME}\n" ';
	## use critic;
	my $cache_file = '/tmp/rpmorphan.cache';
	my $fh_cache;
	my $cmd;

	if ( is_set( $rh_opt, 'clear-cache' ) ) {
		unlink $cache_file if ( -f $cache_file );
	}

	if ( is_set( $rh_opt, 'use-cache' ) ) {
		if ( -f $cache_file ) {

			# cache exists : use it
			$cmd = $cache_file;
			display_status("use cache file $cache_file");
		}
		else {

			# use rpm command
			$cmd = "$rpm_cmd |";

			# and create cache file
			## no critic (RequireBriefOpen)
			if ( open $fh_cache, '>', $cache_file ) {
				display_status("create cache file $cache_file");
			}
			else {
				warning("can not create cache file $cache_file : $ERRNO");
			}
		}
	}
	else {

		# output may be long, so we use a pipe to avoid to store a big array
		$cmd = "$rpm_cmd |";
		display_status('read rpm data');

		unlink $cache_file if ( -f $cache_file );
	}

	return ( $cmd, $fh_cache );
}
#########################################################
## no critic (ProhibitManyArgs)
sub analyse_rpm_info($$$$$$$$$$) {
	my $name        = shift @_;
	my $ra_prov     = shift @_;
	my $ra_req      = shift @_;
	my $ra_files    = shift @_;
	my $rh_objects  = shift @_;
	my $rh_provides = shift @_;
	my $rh_files    = shift @_;
	my $rh_depends  = shift @_;
	my $rh_virtual  = shift @_;
	my $rh_requires = shift @_;

	# we do not use version in keys
	# so we only keep the last seen data for a package name
	if ( exists $rh_provides->{$name} ) {
		debug("duplicate package $name");
	}

  VIRTUAL: foreach my $p ( @{$ra_prov}, @{$ra_files} ) {
		## use critic;

		# do not add files
		#next VIRTUAL if ( $p =~ m!^/! );

		#  some bad package may provide more than on time the same object
		if (   ( exists $rh_objects->{$p} )
			&& ( $rh_objects->{$p} ne $name ) )
		{

			# method 1 (old)
			# we do not use who provide this virtual for now
			#$rh_virtual->{$p} = 1;

			# method 2 (current)
			# to improve the code, we can use virtual as a counter
			# ( as a garbage collector )
			# so we can remove all providing except the last one
			if ( !exists $rh_virtual->{$p} ) {

				# add previous data
				$rh_virtual->{$p}{ $rh_objects->{$p} } = 1;
			}

			# add new virtual
			$rh_virtual->{$p}{$name} = 1;
		}
		else {

			# keep memory of seen "provided"
			$rh_objects->{$p} = $name;
		}
	}

	# $name package provide @prov
	# file are also included in "provide"
	push @{ $rh_provides->{$name} }, @{$ra_prov}, @{$ra_files};

	# list are necessary for access-time option
	push @{ $rh_files->{$name} }, @{$ra_files};

	# this will be helpfull when recursive remove package
	push @{ $rh_requires->{$name} }, @{$ra_req};

	# build a hash for dependencies
	foreach my $require ( @{$ra_req} ) {

		# we have to suppress auto-depends (ex : ark package)
		my $flag_auto = 0;
	  PROVIDE: foreach my $p ( @{$ra_prov} ) {
			if ( $require eq $p ) {
				$flag_auto = 1;

				#debug("skip auto-depency on $name");
				last PROVIDE;
			}
		}

	   # $name depends from $require
	   # exemple : depends { 'afick' } { afick-gui } = 1
	   # push @{ $rh_depends->{$require} }, $name unless $flag_auto;
	   # we use a hash to help when we have to delete data (on recursive remove)
		$rh_depends->{$require}{$name} = 1 unless $flag_auto;
	}
	return;
}
#########################################################
# read rpm information about all installed packages
# can be from database, or from rpmorphan cache
sub read_rpm_data_base($$$$$$$) {
	my $rh_opt          = shift @_;    # hash of program arguments
	my $rh_provides     = shift @_;
	my $rh_install_time = shift @_;
	my $rh_files        = shift @_;
	my $rh_depends      = shift @_;
	my $rh_virtual      = shift @_;
	my $rh_requires     = shift @_;

	my ( $cmd, $fh_cache ) = init_cache($rh_opt);

	# because we can open a pipe or a cache, it is not possible to use
	# the 3 arg form of open
	## no critic (ProhibitTwoArgOpen,RequireBriefOpen);
	my $fh;
	if ( !open $fh, $cmd ) {

		# no critic;
		die "can not open $cmd : $ERRNO\n";
		## use critic
	}
	debug('1 : analysis');
	my %objects;
	while (<$fh>) {

		# write cache
		print {$fh_cache} $_ if ($fh_cache);

		my ( $name, $req, $prov, $files, $install_time ) = split /;/, $_;

		# install time are necessary for install-time option
		$rh_install_time->{$name} = $install_time;

		my $space = q{ };
		my @prov  = split /$space/, $prov;
		my @req   = split /$space/, $req;
		my @files = split /$space/, $files;

		analyse_rpm_info(
			$name,       \@prov,       \@req,     \@files,
			\%objects,   $rh_provides, $rh_files, $rh_depends,
			$rh_virtual, $rh_requires
		);

	}
	close $fh or warning("problem to close rpm command : $ERRNO");

	# close cache if necessary
	if ($fh_cache) {
		close $fh_cache or warning("problem to close cache file : $ERRNO");
	}
	return;
}
#########################################################
# read database info by use of RPM2 module
sub read_rpm_data_rpm2($$$$$$$) {
	my $rh_opt          = shift @_;    # hash of program arguments
	my $rh_provides     = shift @_;
	my $rh_install_time = shift @_;
	my $rh_files        = shift @_;
	my $rh_depends      = shift @_;
	my $rh_virtual      = shift @_;
	my $rh_requires     = shift @_;

	# todo : use cache ?
	#my ( $cmd, $fh_cache ) = init_cache($rh_opt);

	my $db = RPM2->open_rpm_db();

	display_status('read rpm data using RPM2');
	debug('1 : analysis');
	my %objects;

	my $i = $db->find_all_iter();
	while ( my $pkg = $i->next ) {

		# write cache
		#print {$fh_cache} $_ if ($fh_cache);

		my $name         = $pkg->name;
		my $install_time = $pkg->installtime;
		$rh_install_time->{$name} = $install_time;

		my @req   = $pkg->requires;
		my @prov  = $pkg->provides;
		my @files = $pkg->files;

		analyse_rpm_info(
			$name,       \@prov,       \@req,     \@files,
			\%objects,   $rh_provides, $rh_files, $rh_depends,
			$rh_virtual, $rh_requires
		);
	}
	return;
}
#########################################################
# URPM return dependencies as perl[ = 5.8]
# we have to suppress the version and only keep the package
sub clean_rel($) {
	my $ra = shift @_;

	foreach my $elem ( @{$ra} ) {
		$elem =~ s/\[.*\]//;
	}
	return;
}
#########################################################
# read database info by use of URPM module
sub read_rpm_data_urpm($$$$$$$) {
	my $rh_opt          = shift @_;    # hash of program arguments
	my $rh_provides     = shift @_;
	my $rh_install_time = shift @_;
	my $rh_files        = shift @_;
	my $rh_depends      = shift @_;
	my $rh_virtual      = shift @_;
	my $rh_requires     = shift @_;

	# todo : use cache ?
	#my ( $cmd, $fh_cache ) = init_cache($rh_opt);

	my $db = URPM::DB::open();
	debug('1 : analysis');
	display_status('read rpm data using URPM');

	my %objects;
	$db->traverse(
		sub {
			my ($package) = @_;          # this is a URPM::Package object
			my $name = $package->name;
			my $installtime = $package->queryformat('%{INSTALLTIME}');
			$rh_install_time->{$name} = $installtime;
			my @req         = $package->requires();
			clean_rel( \@req );
			my @prov = $package->provides();
			clean_rel( \@prov );
			my @files = $package->files();

			analyse_rpm_info(
				$name,       \@prov,       \@req,     \@files,
				\%objects,   $rh_provides, $rh_files, $rh_depends,
				$rh_virtual, $rh_requires
			);
		}
	);

	return;
}
#########################################################
sub read_rpm_data($$$$$$$) {
	my $rh_opt          = shift @_;    # hash of program arguments
	my $rh_provides     = shift @_;
	my $rh_install_time = shift @_;
	my $rh_files        = shift @_;
	my $rh_depends      = shift @_;
	my $rh_virtual      = shift @_;
	my $rh_requires     = shift @_;

	# empty all structures
	%{ $rh_provides } = ();
	%{ $rh_install_time } = ();
	%{ $rh_files } = ();
	%{ $rh_depends } = ();
	%{ $rh_virtual } = ();
	%{ $rh_requires } = ();

	# try to detect the fastest way to get database info
	eval { require URPM; };
	if ($EVAL_ERROR) {
		eval { require RPM2; };
		if ($EVAL_ERROR) {

			# no specialized perm module installed, so use "old" basic method
			debug('use shell access');
			read_rpm_data_base( $rh_opt, $rh_provides, $rh_install_time,
				$rh_files, $rh_depends, $rh_virtual, $rh_requires );
		}
		else {

			# fedora users and others
			import RPM2;
			debug('use RPM2');
			read_rpm_data_rpm2( $rh_opt, $rh_provides, $rh_install_time,
				$rh_files, $rh_depends, $rh_virtual, $rh_requires );
		}
	}
	else {

		# mandriva : use URPM (also used by urpmi)
		import URPM;
		debug('use URPM');
		read_rpm_data_urpm( $rh_opt, $rh_provides, $rh_install_time, $rh_files,
			$rh_depends, $rh_virtual, $rh_requires );
	}
	return;
}
## use critic
#########################################################
sub read_one_rc($$$) {
	my $rh_list = shift @_;    # list of available parameters
	my $fh_rc   = shift @_;
	my $rcfile  = shift @_;

	# perl cookbook, 8.16
	my $line = 1;
  RC: while (<$fh_rc>) {
		chomp;
		s/#.*//;               # comments
		s/^\s+//;              # skip spaces
		s/\s+$//;
		next RC unless length;
		my ( $key, $value ) = split /\s*=\s*/, $_, 2;
		if ( defined $key ) {
			if ( exists $rh_list->{$key} ) {

				# the last line wins
				if ( ref( $rh_list->{$key} ) eq 'ARRAY' ) {
					@{ $rh_list->{$key} } = get_from_command_line($value);
				}
				else {
					${ $rh_list->{$key} } = $value;
				}

				# special case : verbose will modify immediately behavior
				init_debug($value) if ( $key eq 'verbose' );

				debug(
"rcfile ($rcfile) : found $key parameter with value : $value"
				);
			}
			else {
				warning("bad $key parameter in line $line in $rcfile file");
			}
		}
		else {
			warning("bad line $line in $rcfile file");
		}
		$line++;
	}

	return;
}
#########################################################
# read all existing rc file from general to local :
# host, home, local directory
sub readrc($) {

	my $rh_list = shift @_;    # list of available parameters

	# can use local rc file, home rc file, host rc file
	my @list_rc =
	  ( '/etc/rpmorphanrc', $ENV{HOME} . '/.rpmorphanrc', '.rpmorphanrc', );

	foreach my $rcfile (@list_rc) {

		if ( -f $rcfile ) {
			debug("read rc from $rcfile");
			my $fh_rc;
			if ( open $fh_rc, '<', $rcfile ) {
				read_one_rc( $rh_list, $fh_rc, $rcfile );
				close $fh_rc
				  or warning("problem to close rc file $rcfile :$ERRNO");
			}
			else {
				warning("can not open rcfile $rcfile : $ERRNO");
			}
		}
		else {
			debug("no rcfile $rcfile found");
		}
	}
	return;
}
#########################################################
# because arg can be given in one or several options :
# --add toto1 --add toto2
# --add toto1,toto2
sub get_from_command_line(@) {
	my @arg = @_;

	my $comma = q{,};
	## no critic (ProhibitParensWithBuiltins);
	return split /$comma/, join( $comma, @arg );
	## use critic;
}
#########################################################
sub is_remove_allowed($) {
	my $opt_dry_run = shift @_;

	return ( ( $EFFECTIVE_USER_ID == 0 ) && ( !$opt_dry_run ) );
}
#########################################################

1;
