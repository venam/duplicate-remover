#COPYRIGHT AND PERMISSION NOTICE

#Copyright (c) 2014, Patrick Louis <patrick at iotek dot org>

#All rights reserved.

#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions are met:

#    1.  The author is informed of the use of his/her code. The author does not have to consent to the use; however he/she must be informed.
#    2.  If the author wishes to know when his/her code is being used, it the duty of the author to provide a current email address at the top of his/her code, above or included in the copyright statement.
#    3.  The author can opt out of being contacted, by not providing a form of contact in the copyright statement.
#    4.  If any portion of the author's code is used, credit must be given.
#            a. For example, if the author's code is being modified and/or redistributed in the form of a closed-source binary program, then the end user must still be made somehow aware that the author's work has contributed to that program.
#            b. If the code is being modified and/or redistributed in the form of code to be compiled, then the author's name in the copyright statement is sufficient.
#    5.  The following copyright statement must be included at the beginning of the code, regardless of binary form or source code form.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
#ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
#ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#Except as contained in this notice, the name of a copyright holder shall not
#be used in advertising or otherwise to promote the sale, use or other dealings
#in this Software without prior written authorization of the copyright holder.


use warnings;
use strict;
use Getopt::Long;
use Digest::MD5;
use Cwd;

#
# TODO:
#
# recursivity depth to stop at
# search based  on size first to save time, might be slower depending on how it's done
# recheck the algorithm complexity
# add log file support
#

#Nice Colours
my $HEADER      = "\033[95m";
my $OKBLUE      = "\033[94m";
my $OKGREEN     = "\033[92m";
my $WARNING     = "\033[93m";
my $FAIL        = "\033[91m";
my $ENDC        = "\033[0m";
my $INFO        = $HEADER . "[". $OKBLUE ."*" . $HEADER ."] ". $ENDC;
my $ARROW       = " ". $OKGREEN . ">> ". $ENDC;
my $PLUS        = $HEADER ."[" . $OKGREEN ."+" . $HEADER ."] ". $ENDC;
my $MINUS       = $HEADER ."[". $FAIL ."-". $HEADER ."] ". $ENDC;

my %file_info = (
	absolute_path => "PATH",
	md5_hash      => "HASHHASHHASHHASHHASHHASHHASHHASH"
);
my @files = (
#	[\%file_info,\%file_info],
);
my @dirs;
my @regex;

#Default Values For Options
my $help          = 0;
my $list          = 0;
my $list_dup      = 0;
my $remove        = 0;
my $recursive     = 0;
my $verbose       = 0;
my $dir           = $ENV{"HOME"}; #default
my $blacklist     = "";

sub execute_remove_command($) {
	my ($path) = @_;
	#escape some characters " " "(" ")"
	$path =~ s/ /\\ /gg;
	$path =~ s/\(/\\\(/gg;
	$path =~ s/\)/\\\)/gg;

	system("rm $path");
	if ($? == -1) {
		print "$MINUS Failed to execute: $!\n";
		return -1;
	}
	elsif ($? & 127) {
		printf "$MINUS Child died with signal %d, %s coredump\n",
			($? & 127),  ($? & 128) ? 'with' : 'without';
		return -1;
	}
	return 0;
}

#returns the md5 hash of a file specified
#takes the location as arg
sub get_hash($) {
	my ($f_to_get_hash) = @_;
	#escape some characters " " "(" ")"
	$f_to_get_hash =~ s/ /\\ /gg;
	$f_to_get_hash =~ s/\(/\\\(/gg;
	$f_to_get_hash =~ s/\)/\\\)/gg;

	my $digest = "";
	eval{
		open(FILE, $f_to_get_hash) or die "$MINUS Can't find file $f_to_get_hash\n";
		my $ctx = Digest::MD5->new;
		$ctx->addfile(*FILE);
		$digest = $ctx->hexdigest;
		close(FILE);
	};
	if($@){
		print $@;
		return "";
	}
	return $digest;
}

#manages the file array
#adding to the place where the file fits
#takes the file hash & path as arguments
sub check_if_hash_in_array($$$) {
	my ($hash, $path, $pre) = @_;
	my %data_to_insert = (
		absolute_path => $OKGREEN.$pre."/" .$path,
		md5_hash      => $hash
	);
	my $ignore = 0;
	for my $re (@regex) {
		chomp $re;
		if ($path =~ /$re/) {
			$ignore = 1;
			last;
		}
	}

	#empty file, md5sum /dev/null
	if ($hash eq "d41d8cd98f00b204e9800998ecf8427e") {
		$data_to_insert{absolute_path} = $OKBLUE."[EMPTY]  ".$ENDC . $data_to_insert{absolute_path};
	}

	if ($ignore) {
		$data_to_insert{absolute_path} = $WARNING."[IGNORED]  ".$ENDC . $data_to_insert{absolute_path};
	}
	for my $iter (@files) {
		if ($$iter[0]{md5_hash} eq $hash) {
			if ($ignore==0 && $remove) {
				$data_to_insert{absolute_path} = $FAIL."[DELETED]  ".$ENDC. $data_to_insert{absolute_path};
				execute_remove_command($path);
				print "$PLUS file $path has been deleted\n" if ($verbose);
			}
			push @$iter, \%data_to_insert;
			return;
		}
	}
	push @files, [\%data_to_insert];
}

#displays the files with hashes
#takes 1/0
#1 to only display the duplicated files
#0 to display everything
sub display($) {
	my ($duplicates_only) = @_;
	for my $iter (@files) {
		my @i               = @$iter;
		my $size            = $#i+1;
		my $counter         = 0;
		my $separator       = "$OKBLUE├───$ENDC";

		if ( ($duplicates_only && $size>=2)|| (not $duplicates_only) ) {
			print $HEADER. $$iter[0]{md5_hash}. "$ENDC$OKBLUE─┐\n";
			for my $iter2 (@$iter) {
				$counter++;
				$separator =  "$OKBLUE└───$ENDC" if ($counter==$size);
				print " "x33 .$separator. $$iter2{absolute_path}."$ENDC\n";
			}
			print "\n";
		}
	}
}

#main procedure of the script
sub procedure() {
	#go to the specified directory
	chdir $dir;
	#list all the files in that dir
	my @to_check = glob(".* *"); 
	#removing the "." and ".." indicators
	shift @to_check;
	shift @to_check;
	my $pre = cwd;
	$pre = substr($pre,0, length($pre)-2) if (substr($pre,length($pre)-1,1) eq "/");

	for (@to_check) {
		#if it's a file and readable
		if (-f -r) {
			my  $arg = $_;
			my $h = get_hash($_);
			check_if_hash_in_array($h, $arg, $pre);
		}
		else {
			if (-d) {
				print "$INFO $_ is a directory\n" if ($verbose);
				push @dirs, $pre."/".$_;
			}
			else {
				print "$MINUS Cannot access $_\n" if ($verbose);
			}
		}
	}
	unless ($recursive) {
		print "\n";
		display($list_dup);
	}
}

#takes a list of dirs and redo the whole procedure in it
sub recursive_search() {
	for my $d (@dirs) {
		$dir = $d;
		procedure;
	}
	display($list_dup);
}

sub usage() {
	return qq#
  $HEADER$0$ENDC $OKBLUE [ $ENDC--list $OKBLUE|$ENDC --listduplicate$OKBLUE|$ENDC --remove$OKBLUE ]$ENDC$OKBLUE [$ENDC Options$OKBLUE ]$ENDC
	$OKGREEN--help$ENDC                  Display this help message
	$OKGREEN--list$ENDC                  List all the files with hashes
	$OKGREEN--listduplicates$ENDC        List only duplicated files
	$OKGREEN--dir "directory"$ENDC       The directory where the execution will take place
	$OKGREEN--remove$ENDC                Remove duplicates (keeps the first file found)
	$OKGREEN--recursive$ENDC             If the search is recursive or not
	$OKGREEN--blacklist "file"$ENDC      A file containing regex of ignored files
	\n#;
}


GetOptions (
	"help"           => \$help,     #flag
	"list"           => \$list,     #flag
	"listduplicates" => \$list_dup, #flag
	"directory=s"    => \$dir,      #string
	"remove"         => \$remove,
	"blacklist=s"    => \$blacklist,
	"recursive"      => \$recursive,
	"verbose"        => \$verbose
)  or die("$MINUS Error in command line arguments\n");

#defensive programming part
if ($help) {
	print usage();
	exit;
}

if (!$list && !$list_dup && !$remove) {
	print "$MINUS You must specify if you want to list or remove duplicates\n";
	print usage();
	exit;
}

if ($blacklist ne "") {
	open IN, $blacklist or die("$MINUS Cannot open blacklist");
	push @regex, $_ for (<IN>);
	close IN;
}

if ($list || $list_dup || $remove) {
	procedure;
	recursive_search() if ($recursive);
}


