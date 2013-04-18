REQUIRED TOOLS:
  - Ruby v 1.9.3
  - samtools  http://samtools.sourceforge.net/
  - tabix  http://samtools.sourceforge.net/tabix.shtml

RUBY LIBRARIES:
  - vcf:  gem install vcf


Current steps in SNP epistasis identification/annotation:

1. Create a cogie.config file with fields as described in resources/cogie.config.example

2. Extract all locations that have identified alterations from the patient files.  This step can take some time depending
 on the number of patients.  The resulting locations file is used in subsequent scripts.
> ruby index_cogie_patient.rb <cogie.config file location>

3. Run mdr_filter.rb with the config file from above.  This script will apply the filter to the control and patient files
and output mdr matrix files.
> ruby mdr_filter.rb  <cogie.config file location>

4. Run the run_mdr.rb file with the config file and date of the filter run to be analyzed in the following format: YearMonthDay
This script will then set up and run the MDR scripts on the cluster. MDR parameters are set by the cogie.config file.
Max settings depends on the cluster.  Higher K values increase the computational time with large mdr.max values.

Parameters for the OAR scripts are also set up in the cogie.config file.
> ruby run_mdr.rb <cogie.confg file location> 20130101

5. Run the read_mdr_results.rb script to translate the mdr output from chromosome locations to ensembl genes. Currently it only queries
for protein coding genes so some locations will not have results.
> ruby read_mdr_results.rb <mdr.txt file>


NOTE:  The following are assumptions made by the parsers.
 1. Control variation data is provided in VCF format (4.0 is preferred).
 2. Patient variation data is provided in the format shown in resources/cogie-patient-sample.txt.  This is particularly true of the column headers.
    If these headers vary the parser will fail intentionally.  Should this format change the COGIEPatient class must be altered.
    If instead a master variation file is provided in VCF format the read_cogie_patient.rb script can be substantially simplified
    by using the samtools and Vcf file parsing library.




