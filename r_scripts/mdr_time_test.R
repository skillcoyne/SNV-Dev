
data = read.table("mdr_time_tests.csv", header=TRUE, sep="\t")
logdata=log(data)

yrange=range(logdata$'k2',logdata$'k3')
xrange=range(data$'SNPs')


plot(xrange, yrange, type='n', xlab="Number of SNPs", ylab="User time in seconds (log)")

colors=rainbow(length(data)-1)
cols=colnames(data)


for(i in 2:length(data))
	{
	lines(data$'SNPs', logdata[[cols[i]]], col=colors[i-1], lwd=2)
	}

legend(xrange[1], yrange[2],  cols[2:length(cols)], cex=0.8, col=colors, lty=1, title="MDR Parameters", bty="n")
