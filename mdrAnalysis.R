library(MDR)
getMRDFile<-function(filename)
  {
	print(filename)
	rr<-read.table(filename, header=TRUE)
	(rr)  
  }

file="/home/skillcoyne/tools/GWAsimulator/test2/chr11.mdr"

mdr_data<-read.table(file, header=TRUE)

fit<-mdr.cv(mdr_data[1:15], K=4, cv=5, genotype=c(0,1,2))
print(fit)
summary(fit)
plot(fit,data=mdr_data)

