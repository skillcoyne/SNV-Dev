library(MDR)

file="/home/skillcoyne/tools/GWAsimulator/test2/chr1.mdr"

mdr_data<-read.table(file, header=TRUE)

cols<-colnames(mdr_data)
print(cols[1:15])
fit<-mdr.cv(mdr_data[1:15], K=2, cv=5, genotype=c(0,1,2))

print(paste("Top models",fit$'top models', sep="\n"))

for(k in 1:length(fit$'top models'))
  {
  s<-paste("k=",k)
  print(s)
  for(i in 1:length(fit$'top models'[[k]]))
    {
    snpI<-fit$'top models'[[k]][i]
    snp<-cols[snpI]
print(paste("snpI=",snpI))
print(paste("col=",snp))
    fit$'top models'[[k]][i]<-cols[snpI]
    }
  }

print(fit)

out<-capture.output(summary(fit))
cat(out,file="/home/skillcoyne/tools/GWAsimulator/test2/R/chr1.summary.txt", sep="\n", append=F)


plot(fit,data=mdr_data)
