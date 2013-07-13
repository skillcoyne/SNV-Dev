args = commandArgs(trailingOnly = TRUE)

vcf = args[1]
out = args[2]

d = read.table(vcf, header=F, sep="\t")

qual = d[,6]

setwd(out)

s = summary(qual)
capture.output(s, file="qual_scores.txt")


minq = length(qual[qual <= min(qual)])
mean = length(qual[qual > min(qual) & qual < mean(qual) ])
top = length(qual[qual >= mean(qual) & qual <= max(qual)])


q = quantile(qual)

q1 = length(qual[qual <= q[2]])
q2 = length(qual[qual > q[2] & qual <= q[3]])
q3 = length(qual[qual > q[3] & qual <= q[4]])
q4 = length(qual[qual > q[4] & qual < q[5]])



write(paste("VCF file:",vcf),  file="qual_scores.txt", app=T)
write("------------------------",  file="qual_scores.txt", app=T)
 
write("Below min:", file="qual_scores.txt", app=T)
write(minq, file="qual_scores.txt", app=T)

write("Min to mean:", file="qual_scores.txt", app=T)
write(mean, file="qual_scores.txt", app=T)

write("Above mean:", file="qual_scores.txt", app=T)
write(top, file="qual_scores.txt", app=T)

write("Quantiles:",  file="qual_scores.txt", app=T)
write(q1,  file="qual_scores.txt", app=T)
write(q2,  file="qual_scores.txt", app=T)
write(q3,  file="qual_scores.txt", app=T)
write(q4,  file="qual_scores.txt", app=T)




