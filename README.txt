

Current steps in SNP epistasis identification/annotation:

1. Create a cogie.config file with fields as described in resources/cogie.config.example

2. Run mdr_filter.rb with the config file from above.

3. TODO - rewrite run_analysis.rb script for Java MDR.
    a. This step will output the require OAR scripts and run them on the cluster.
    b. MDR parameters are set by the cogie.config script.  Changing the max.max requires rerunning the mdr_filter script which
       creates the matrices. Currently the max settings are recommended as:  mdr.max = 2000, mdr.K = 3.  With a lower mdr.max
       the K value can be increased.  If max is increased about 2000 K should not more than 2.
    b. Parameters for the OAR scripts are also set up in the cogie.config file.

4. Read through MDR summary and extract SNP sets.


NOTE:  The following are assumptions made by the parsers.
 1. Control variation data is provided in VCF format (4.0 is preferred).
 2. Patient variation data is provided in the format shown in resources/cogie-patient-sample.txt.  This is particularly true of the column headers.
    If these headers vary the parser will fail intentionally.  Should this format change the COGIEPatient class must be altered.


## EXAMPLE OUTPUT FROM R SCRIPT, JAVA IS SIMILAR BUT SHOULD BE UPDATED ##

example output:
  Level    Best Models                 Classification Accuracy
* "1"   "chr1_SNP4"                 "55.73"                   
  "2"   "chr1_SNP19"   "chr1_SNP31" "61.8"                    
     Prediction Accuracy    Cross-Validation Consistency
* "49.91"                "2"                            
  "38.51"                "1"                            
 
'*' indicates overall best model


