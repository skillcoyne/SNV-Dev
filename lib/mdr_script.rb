require 'yaml'

## TODO rewrite for Java MDR
class MDRScript

  def initialize(input_path, output_path)
    @in_path = input_path
    @out_path = output_path
  end

  def self.write_script(input_path, output_path, type = "Java", max = 50, k = 2)
    self.new(input_path, output_path)

    Dir.foreach(@in_path) do |entry|
      file = "#{@in_path}/#{entry}"
      next unless File.extname(file).eql? ".mdr"

      if type.eql? 'R'
        R(file, max, k)
      elsif type.eql? 'Java'
        Java_script(file, max, k)
      else
        puts "No MDR tool for type '#{type}'"
      end
    end
  end

  def Java_script(mdrfile, max, k)
    java =<<-Java

    Java
  end


  def R(mdrfile, max, k)
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
    return r_script
  end

  :private

  def write_script(script) ## todo this is just copied from run_analysis.rb, it's not workable
    filename = File.basename(opts[:input_file], ".mdr")

    File.open("#{@out_path}/#{filename}_#{$script}", 'w') { |f| f.write(r_script) }
    FileUtils.chmod(0776, "#{@out_path}/#{filename}_#{$script}")

    opts[:r_script] = "#{opts[:output_path]}/#{filename}_#{$script}"

  end


end