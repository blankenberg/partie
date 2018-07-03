########################################################################################
##                                                                                    ##
## Automatically download and extract all the SRA data. This self contained           ##
## bash script, should (!!) download a new version of the data and figure out         ##
## which are metagenomes.                                                             ##
##                                                                                    ##
## Note that this is designed to run on my cluster that uses SGE for job submission   ##
## if you run it elsewhere you will need to change the qsub part most likely.         ##
##                                                                                    ##
## (c) 2018 Rob Edwards                                                               ##
##                                                                                    ##
########################################################################################

HOST=`hostname`
DATE=`date +%b_%Y`
WD=$PWD

if [ -e $DATE ]; then
	echo "$DATE already exists. Do we need to do anything?"
	exit;
fi

mkdir $DATE
cd $DATE


# Download one of the SRA SQLite databases:
echo "Downloading and extracting the new SQL Lite data base"
wget 'https://gbnci-abcc.ncifcrf.gov/backup/SRAmetadb.sqlite.gz'
gunzip SRAmetadb.sqlite.gz


# Get all the possible SRA metagenome samples from the SQL lite table. This is described at https://edwards.sdsu.edu/research/sra-metagenomes/
echo "Running the SQLite commands";
sqlite3 SRAmetadb.sqlite 'select run_accession from run where experiment_accession in (select experiment_accession from experiment where (experiment.library_strategy = "AMPLICON" or experiment.library_selection = "PCR"))' > amplicons.ids
sqlite3 SRAmetadb.sqlite 'select run_accession from run where experiment_accession in (select experiment_accession from experiment where experiment.library_source = "METAGENOMIC")' > source_metagenomic.ids
sqlite3 SRAmetadb.sqlite 'select run_accession from run where experiment_accession in (select experiment_accession from experiment where experiment.study_accession in (select study_accession from study where study_type = "Metagenomics"));' > study_metagenomics.ids
sqlite3 SRAmetadb.sqlite 'select run_accession from run where experiment_accession in (select experiment_accession from experiment where experiment.sample_accession in (select sample.sample_accession from sample where (sample.scientific_name like "%microbiom%" OR sample.scientific_name like "%metagenom%")))' > sci_name_metagenome.ids
grep -F -x -v -f amplicons.ids source_metagenomic.ids > source_metagenomic.notamplicons.ids
grep -F -x -v -f amplicons.ids study_metagenomics.ids > study_metagenomics.notamplicons.ids
grep -F -x -v -f amplicons.ids sci_name_metagenome.ids > sci_name_metagenome.notamplicons.ids
sort -u sci_name_metagenome.notamplicons.ids source_metagenomic.notamplicons.ids study_metagenomics.notamplicons.ids > SRA-metagenomes.txt

# look at the previously downloaded metagenomes
echo "Figuring out the new metagenomes to download"
cut -f 1 ~/GitHubs/partie/SRA_Metagenome_Types.txt | grep -Fxvf - SRA-metagenomes.txt > SRA-metagenomes-ToDownload.txt

# now set up a cluster job to parse out some data
mkdir partie
cp SRA-metagenomes-ToDownload.txt partie/
cd partie
echo -e "SRA=\$(head -n \$SGE_TASK_ID SRA-metagenomes-ToDownload.txt | tail -n 1);\nperl \$HOME/partie/partie.pl -noheader \${SRA}.sra;" > partie.sh
# and submit a few jobs to the queue to test
mkdir sge_out sge_err


# this deals with an error in the BASH_FUNC_module
unset module
# how many jobs do we have?
COUNT=$(wc -l SRA-metagenomes-ToDownload.txt | awk '{print $1}')

if [ $HOST == "anthill" ]; then 
	# we can submit directly
	echo "submitting the partie job"
	qsub -V -cwd -t 1-$COUNT:1  -o sge_out/ -e sge_err/ ./partie.sh
else 
	# submit via ssh
	WD=$PWD
	echo "Running the partie command on anthill"
	ssh anthill "cd $PWD; qsub -V -cwd -t 1-$COUNT:1  -o sge_out/ -e sge_err/ ./partie.sh"
fi

echo "We have submitted the PARTIE jobs to the cluster, and you need to let them run."
echo "Once they are run (which doesn't take that long), you should be able to use the script:"
echo "partie_parse_output.sh"
echo "to finalize the data and add everything to GitHub"