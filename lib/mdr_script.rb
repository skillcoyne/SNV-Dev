require 'yaml'

## TODO rewrite for Java MDR if necessary
class MDRScript

  @@script = "mdrAnalysis.R"

  def self.write_script(input_path, output_path)

    Dir.foreach(input_path) do |entry|
      full_file_path = "#{input_path}/#{entry}"
      next unless File.extname(full_file_path).eql?".mdr"

      MDRScript.script_string(full_file_path, output_path)
    end

  end


  def MDRScript.script_string(input, output_path)
    r_script =<<-R
library(MDR)

file="#{input}"

mdr_data<-read.table(file, header=TRUE)

fit<-mdr.cv(mdr_data[1:15], K=4, cv=5, genotype=c(0,1,2))
print(fit)
summary(fit)
plot(fit,data=mdr_data)
  R

  filename = File.basename(input, ".mdr")

  File.open("#{output_path}/#{filename}_#{@@script}", 'w') {|f|
    f.write(r_script)
  }
  end

end