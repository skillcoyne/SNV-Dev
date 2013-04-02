require 'yaml'
require 'fileutils'

class MDRScript

  attr_reader :files

  def initialize(input_path, output_path)
    @in_path = input_path
    @out_path = output_path
  end


  def write_script(opts = {})
    @files = []
    raise ArgumentError, "Required options: :type (Java/R), :jar (if :type=Java) :max (if :type=R) and k" unless (opts[:type] and opts[:type].eql? 'Java' or opts[:type].eql 'R')
    Dir.foreach(@in_path) do |entry|
      file = "#{@in_path}/#{entry}"
      next unless File.extname(file).eql? ".mdr"
      if opts[:type].eql? 'R'
        @files << R(file, opts[:max], opts[:k])
      elsif opts[:type].eql? 'Java'
        @jar_path = opts[:jar]
        @files << Java_script(file, opts[:k], opts[:models])
      else
        puts "No MDR tool for type '#{opts[:type]}'"
      end
    end
    @files
  end


  def run_script(filename, cores = 2, walltime = 84)
    base =   File.basename(filename).sub!(/\..*$/, "")
    cmd=<<-CMD
oarsub -l core=#{cores},walltime=#{walltime} -n MDR_#{base} -O #{@out_path}/#{base}.out -E #{@out_path}/#{base}.err  #{filename}
CMD
    puts "Starting #{cmd}"
    system("#{cmd}")
  end


  :private

  def write(file, script)
    File.open("#{@out_path}/#{file}", 'w') { |f| f.write(script) }
    FileUtils.chmod(0776, "#{@out_path}/#{file}")
    return "#{@out_path}/#{file}"
  end

  def Java_script(mdrfile, k, models)
    output = File.basename(mdrfile).sub(/\..*$/, "")
    jar = @jar_path || "MDR.jar"
    java =<<-Java
java -jar #{jar} -parallel -nolandscape -top_models_landscape_size=#{models} -cv=10 -max=#{k} -all_models_outfile=#{@out_path}/#{output}-models.txt #{mdrfile} > #{@out_path}/#{output}.txt
    Java
    return write("#{output}.sh", java)
  end

  ## Not tested for R as this was adapted from the SNV-Dev run_analysis script
  def R(mdrfile, max, k)
    output = File.basename(mdrfile).sub(/\..*$/, "")
    r_script =<<-R
#!/usr/bin/env Rscript
library(MDR)

nameModels<-function(model)
  {
  for(k in 1:length(model))
    {
    i=1
    for(snpI in model[[k]])
      {
      model[[k]][i]<-cols[[as.numeric(snpI)]]
      i<-i+1
      }
    }
  return(model)
  }

mdr_data<-read.table("#{mdrfile}", header=TRUE)

#note if you don't slice the array you need to be aware of
# an off by 1 error in the nameModels function
cols<-colnames(mdr_data[2:#{max}])
fit<-mdr.cv(mdr_data[1:#{max}], K=#{k}, cv=5, genotype=c(0,1,2))

# plotting needs to occur before transforming the model
# names for the summary data
pdf("#{@out_path}/#{base}_plot.pdf")
plot(fit,data=mdr_data)

# transform models for snp names instead of just numbers
# this may only matter when not using synthesized data
topm<-nameModels(fit$'top models')
fit$'top models'<-topm

finalm<-nameModels(fit$'final model')
fit$'final model'<-finalm

print(summary(fit))
    R
    return write("#{output}.R", r_script)
  end


end
