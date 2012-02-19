Current steps in SNP epistasis identification:

1. Create simulated genotype SNP chip data for case-control data.  Currently using provided phase data from Illumina.
Run GWASimulator with epilepsy control file and random number.  Example control file found in /resources directory
example: "GWASimulator epilepsy_control.dat 48927848"

2. Set up files for MDR run using gwasim script. Currently using the R MDR package, the gwa.config.example file
in /resources provides necessary information. This script just adds column data missing from the simulated phase data
and reorganizes based on the MDR used (java vs R).
example: "ruby gwasim_read.rb gwa.config"

3. Run MDR over the simulated files.  Using the R version currently this step is to set up the OAR cluster scripts required
to run MDR over each chromosome.  Without this step the MDR step is limited to K=2 and a max of about 50 SNPs per
case. The parameters for this script are also set up in the gwa.config file.  Example in the /resources directory.
*** This step is not running correctly ***
When this works the R and OAR scripts will written then kicked off on the cluster. The result will be one (or several
depending on the configuration) summary files
example: "ruby run_analysis.rb gwa.config"

example output:
  Level    Best Models                 Classification Accuracy
* "1"   "chr1_SNP4"                 "55.73"                   
  "2"   "chr1_SNP19"   "chr1_SNP31" "61.8"                    
     Prediction Accuracy    Cross-Validation Consistency
* "49.91"                "2"                            
  "38.51"                "1"                            
 
'*' indicates overall best model

4.
