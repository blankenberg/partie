########################################################################################
##                                                                                    ##
## Finish the partie installation steps. This is the part that runs the random        ##
## forest and determines what data we have.                                           ##
##                                                                                    ##
## Also added a step to do the automatic git commits!                                 ##
##                                                                                    ##
##                                                                                    ##
##                                                                                    ##
## (c) 2018 Rob Edwards                                                               ##
##                                                                                    ##
##                                                                                    ##
########################################################################################

HOST=`hostname`
WD=$PWD

DATE=`date +%b_%Y`
cd $DATE/partie

# clean up the output. This means that we delete a few that we need to add next time
perl -ne 'next unless (/^[DSE]RR\d+.sra\t[\d\.]+\t[\d\.]+\t[\d\.]+\t[\d\.]+$/); @a=split /\t/; next unless ($#a == 4); print' sge_out > output_clean

# cat the header and the files in one go:
head -n 1 ~/partie/SRA_PARTIE_DATA.txt | sed -e 's/\s\+PARTIE_Annotation//'  | cat - output_clean | grep -vP '\t0\t0\t0\t0' > partie_${DATE}.txt
grep -P '\t0\t0\t0\t0' sge_out | perl -pe 'chomp; s/$/\tNO DATA\n/' >> ~/partie/SRA_PARTIE_DATA.txt

# run the classification
Rscript ~/partie/RandomForest/PARTIE_Classification.R partie_${DATE}.txt

# combine the results with the previous results
perl -npe 's/\.sra//; s/"//g; s/\,/\t/g; ' partie_classification.csv | grep -v PARTIE_Annotation >> ~/partie/SRA_PARTIE_DATA.txt

cd ~/partie/
# creat the last file
cut -f 1,6 SRA_PARTIE_DATA.txt > SRA_Metagenome_Types.tsv

git commit -m 'Updating PARTIE data' -a; git push

cd $WD
