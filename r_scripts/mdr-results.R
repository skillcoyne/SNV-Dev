
datadir = "~/Data/COGIE/analysis/JME/0-50000"
outdir = paste(datadir, "high-rank", sep="/")

setwd(datadir)

files = list.files(path=".", pattern="models.txt")

if (length(files) <= 0)
	{
	print( "No files found in data directory")
	exit
	}

for (file in files)
{
 outfile = paste(outdir, paste(unlist(strsplit(file, "-"))[1], ".txt", sep=""), sep="/")

d = read.table(file, header=T, sep="\t", row.names=NULL)
colnames(d) = colnames(d[2:ncol(d)])

write.table(t(colnames(d[3:5])), row.names=F, col.names=F, quote=F, sep="\t", file=outfile)

for (k in 1:2)
	{
	k2 = d[ which(d$numAttributes == k), ]
	k2 = k2[order(-k2[,4]),]

	topTrain = max(k2[,4]) - sd(k2[,4])
	topTest = max(k2[,5]) - sd(k2[,5])

	topmodels = k2[(which(k2[,4] > topTrain & k2[,5] > topTest)),]

	write.table(topmodels[,3:5], quote=F, row.name=F, sep="\t", col.names=F, app=T, file=outfile)

	print(paste(file, k, r, sep=" : "))
	}
}
