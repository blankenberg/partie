#!/usr/bin/env perl
use File::Basename;
use Getopt::Long qw(GetOptions);
use Data::Dumper;
use Cwd;

#---------------------------------------------
my $dir = getcwd;
local $ENV{PATH} = "$ENV{PATH}:$dir/bin";
use strict;

#---------------------------------------------
# 
# Here we define some variables that can be provided on the command line
# These variables have defacult values
#
#---define number of reads used
my $num_reads = 10000;
#---define kmer length
my $kmer_length = 15;
#---define how few kmers are in a rare kmer
my $rare_kmer = 10;

# these variables do not have default values, and if they are not provided on
# the command line, we will try and figure them out for you.
# You can also define them here.

my $bt2;   # the bowtie2 executable and path.
my $jf;    # the jellyfish executable and path
my $fqdmp; # the fastq-dump executable and path
my $seqtk; # the seqtk executable and path



#---------------------------------------------

my $help; my $version; 
my $verbose; my $keep;

GetOptions (
	"nreads=i"    => \$num_reads,
	"klen=i"      => \$kmer_length,
	"nrare=i"     => \$rare_kmer,
	"help"        => \$help,
	"version"     => \$version,
	"bowtie2=s"   => \$bt2,
	"jellyfish=s" => \$jf,
	"fastqdump=s" => \$fqdmp,
	"seqtk=s"     => \$seqtk,
	"verbose"     => \$verbose,
        "keep"        => \$keep,
    );


if ($help) {
	&usage();
}

if ($version) {
	&version();
}

unless($ARGV[0]){
	&usage;
}

unless ($bt2) {
	$bt2 = `which bowtie2`;
	chomp($bt2);
	if($bt2 =~ m/no bowtie2 in/){
		print STDERR "The executable for bowtie2 was not found on the path!\n";
		print STDERR "Please download and install it as described in INSTALLATION.md\n";
		print STDERR "\n";
		exit();
	}
}

unless ($jf) {
	$jf = `which jellyfish`;
	chomp($jf);
	if($jf =~ m/no jellyfish in/){
		print STDERR "The executable for Jellyfish was not found on the path!\n";
		print STDERR "Please download and install it as described in INSTALLATION.md\n";
		print STDERR "\n";
		exit();
	}
}
unless ($fqdmp) {
	$fqdmp = `which fastq-dump`;
	chomp($fqdmp);
	if($fqdmp =~ m/no fastq-dump in/){
		print STDERR "The executable for fastq-dump was not found on the path!\n";
		print STDERR "Please download and install it as described in INSTALLATION.md\n";
		print STDERR "\n";
		exit();
	}
}
unless ($seqtk) {
	$seqtk = `which seqtk`;
	chomp($seqtk);
	if($seqtk =~ m/no seqtk in/){
		print STDERR "The executable for seqtk was not found on the path!\n";
		print STDERR "Please download and install it as described in INSTALLATION.md\n";
		print STDERR "\n";
		exit();
	}
}

if ($verbose) {
	print STDERR <<EOF;
We are using the following executables:
Bowtie2:    $bt2
Jellyfish:  $jf
fastq-dump: $fqdmp
seqtk:      $seqtk

EOF
}

#---------------------------------------------
# Check that we have some databases partie

if (!-e $dir."/db/16SMicrobial.1.bt2") {
	print STDERR "Welcome to PARTIE\n";
	print STDERR "Please build the PARTIE databases by running the command\nmake\n";
	print STDERR "This will download the databases from our server and build them for you\n";
	print STDERR "Once you have run make, you should be able to use partie.pl to process your datasets\n";
	exit();
}

#---------------------------------------------
my $count;
opendir(my $dh, "$dir/db") or die "opendir($dir.'/db'): $!";
while (my $de = readdir($dh)) {
	next unless $de =~ /\.bt2/;
	$count++;
}
closedir($dh);
if($count < 18){
	print STDERR "Sorry, we did not find all of the required databases. We only found $count bowtie2 databases\n";
	print STDERR "Please check the INSTALLATION.md file for a description on how to install the databases\n";
	exit();
}
#---------------------------------------------




my @suffixes = qw(.sra .fastq .fq .fasta .fna .fa);
my ($filename, $path, $suffix) = fileparse($ARGV[0], @suffixes);

#---------------------------------------------
#--- INFILE HANDLING
#---------------------------------------------
if($suffix =~ m/\.sra/){
	my $out = `$fqdmp --fasta --read-filter pass --dumpbase --split-spot --clip --skip-technical --readids --maxSpotId $num_reads  --stdout $ARGV[0] 1> $filename.$num_reads.fna 2>&1 `;
	if($out =~ m/An error occurred/){
		my $out = `$fqdmp --fasta ---read-filter pass --dumpbase -split-spot --readids --maxSpotId $num_reads --stdout $ARGV[0] 1> $filename.$num_reads.fna 2>&1 `;
	}
}elsif($suffix =~ m/\.fq|\.fastq|\.fasta|\.fa|\.fna/){
	system("$seqtk seq -A $ARGV[0] > $filename.$num_reads.fna");
}else{
	print "Error: unrecognized infile type\n";
}
#---------------------------------------------
#---------------------------------------------
#--CHECK DATABASES
my $out = `$bt2-inspect -s db/16SMicrobial 2>&1 1> /dev/null`;
if($out){
	print "Error: 16S database corrupted\n";
	exit();
}
my $out = `$bt2-inspect -s db/phages 2>&1 1> /dev/null`;
if($out){
	print "Error: phages database corrupted\n";
	exit();
}
my $out = `$bt2-inspect -s db/prokaryotes 2>&1 1> /dev/null`;
if($out){
	print "Error: prokaryotes database corrupted\n";
	exit();
}

#--COUNT HITS TO 16S
my $percent_16S = 0;
my $out = `$bt2 -f -k 1 -x db/16SMicrobial $filename.$num_reads.fna 2>&1 1> /dev/null | grep 'aligned 0 time'`;
if($out =~ m/\((\S+)%\)/){
	$percent_16S = 100-$1;
}
#---COUNT HITS TO PHAGES
my $percent_phage = 0;
my $out = `$bt2 -f -k 1 -x db/phages $filename.$num_reads.fna 2>&1 1> /dev/null | grep 'aligned 0 time'`;
if($out =~ m/\((\S+)%\)/){
	$percent_phage = 100-$1;
}
#---COUNT HITS TO PROKARYOTES
my $percent_prokaryote = 0;
my $out = `$bt2 -f -k 1 -x db/prokaryotes $filename.$num_reads.fna 2>&1 1> /dev/null | grep 'aligned 0 time'`;
if($out =~ m/\((\S+)%\)/){
	$percent_prokaryote = 100-$1;
}
#---COUNT UNIQUE KMERS
system("$jf count -m $kmer_length -s 100M -o $filename.$num_reads.jf $filename.$num_reads.fna");
system("$jf dump -c $filename.$num_reads.jf > $filename.$num_reads.txt");
my $total = 0;
my $count = 0;
open(INFILE, "$filename.$num_reads.txt");
while (<INFILE>) {
	chomp;
	my @line = split(/\s+/);
	$total += $line[1];
	if($line[1] < $rare_kmer){
		$count++;
	}
}
close(INFILE); 

if (!$keep) {
	unlink("$filename.$num_reads.fna");
	unlink("$filename.$num_reads.jf");
	unlink("$filename.$num_reads.txt");
}

#---OUPUT
print "percent unique kmer\t";
print "\tpercent 16S\t";
print "\tpercent PHAGE\t";
print "\tpercent PROKARYOTE\t";
print "\n";
if($total){
	print (($count/$total)*100);
}else{
      	print "0";
}
print "\t";
print $percent_16S;
print "\t";
print $percent_phage;
print "\t";
print $percent_prokaryote;
print "\n";


sub usage {
	
	print "\nWelcome to PARTIE.\n==================\n";
	if (! -e $dir."/db/16SMicrobial.1.bt2") {
		print "\nBefore you run PARTIE you need to run download and build the databases\n";
		print "You can easily do that by running the command\nmake\nin the terminal window. It will download what you need to make partie run\n";
		print "Once you have installed the databases, these are the commands you can use to run PARTIE:\n";
	}

print <<EOF;

usage: ./partie.pl [options] READFILE

Options:
	 -nreads INT    the number of reads to pull sample from READFILE [10000]
	 -klen   INT    the length of the kmers [15]
	 -nrare  INT    maximum number a kmer can occur and still be considered rare [10]\

	 -help          print this help menu
	 -version       print the current version
	 -verbose	print additional diagnostic output

	 You can specify the locations of the following executables on the command line, but if you leave 
	 these out we will look in the PATH for them.
	 -bowtie2       path to bowtie2
	 -fastqdump     path to fastq-dump
	 -jellyfish     path to jellyfish
	 -seqtk         path to seqtk

	 You can use these options to diagnose issues with partie
	 -keep          keep the sequences that were processed from the input file and/or downloaded from SRA


READFILE can either be a fastq or fasta file, or it can be an SRA ID but it must end .sra. 
If it is an SRA ID (ending .sra) we will use fastq-dump to download some of the sequences
from the NCBI SRA.

EOF

	exit();

}

sub version {
	open(IN, "VERSION") || die "Error. The VERSION file which should be a part of PARTIE is not present";
	my $ver = "Unknown";
	while (<IN>) {
		chomp;
		$ver = $_;
	}
	close IN;
	print "Version: $ver\n";
	print "\n";
	exit();
}
