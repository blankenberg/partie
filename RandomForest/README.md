# Classification of predictions

How to use PARTIE randomForest classification:

PARTIE output should be in txt format. In this example it is named 'Example_partie_output_SRR3939281.txt'.

First you will build and save a random forest training model. The PARTIE_Training.R script will call the robust training set (SRA_used_for_training.csv) that will be used to build the training model. 
Running this script:

                   Rscript PARTIE_Training.R 

should output 'final_model.rds' in the folder you ran this script in. Once you have this file in your folder you do not have to run this script anymore.

Next, we will want to classify the data. Below is the script you can use to classify SRA data after going through the 
initial PARTIE algorithm:

                    Rscript PARTIE_Classification.R Example_partie_output_SRR3939281.txt
                    



