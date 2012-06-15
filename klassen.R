#!/usr/bin/env

genotype<-function(list, mut_prob)
	{
	for (n in 1:length(list))
		{
		list[n]=sample( c(0,1,2), 1, replace=TRUE, prob=mut_prob )
		}
	return(list)
	}

args=commandArgs()
args=args[6:length(args)]

dir=args[1]
sample_num=args[2]

kdata=read.table( paste(dir, "mmc2.txt", sep=""), header=TRUE, sep="\t")
kdata=kdata[c("HUGO_Gene", "Chrm", "SNPID", "dbSNPID", "RefSeqID", "Type", "Codon", "SNPinPatients", "SNPinControls")]

# clean the data
kdata=kdata[ which(kdata$'Chrm'!="chrX"), ]  # ignoring X as Y isn't represented
kdata=kdata[ which(kdata$'HUGO_Gene'!="unknown"), ]

# Select the set of mutations, currently just missense
pts=kdata[ which(kdata$'Type'!="intron" & kdata$'SNPinPatients'=="yes" & kdata$dbSNPID!="novel"), ]
ctrls=kdata[ which(kdata$'Type'!="intron" & kdata$'SNPinControls'=="yes" & kdata$dbSNPID!="novel"), ]
all=kdata[ which(kdata$'Type'!="intron" & kdata$dbSNPID!="novel"), ]

nrow(pts)
nrow(ctrls)
nrow(all)

## -- 
# Create a sample set of SNPs that is half patient half controls.
# There will be some intersection between them
## --
snps=sample(as.vector(all$SNPID), 200, replace=FALSE)
#snps=c(sample(as.vector(ptsMissense$'SNPID'), 100, replace=FALSE), sample(as.vector(ctrlsMissense$'SNPID'), 100, replace=FALSE))
cols=c("Class", snps) # add class variable column for patient/control

# 400 patients
mdrMatrix=matrix(0,400,length(snps)+1)
colnames(mdrMatrix)=cols

mdr=as.data.frame(mdrMatrix)

## -- 
# At the moment these to loops are going to run over the set intersection between patients and controls
# It will treat all intersecting SNPs as patient snps for the probability of mutation 
# Currently the probably is based on nothing other than that cases should have a high liklihood of having a 
# mutations than controls.
## --
mdr$Class[1:200]=1  # Cases
ctrlsnps=intersect(ctrls$SNPID, snps)
ptsnps=intersect(pts$SNPID, snps)

# controls
for(snp in ctrlsnps)
	{
	if ( !is.null(mdr[[snp]]) )
		{
		print(snp)
		mdr[[snp]][201:400]=genotype(mdr[[snp]][201:400], c(.60, .15, .05))
		}
	}
# cases
for(snp in ptsnps)
	{
	if ( !is.null(mdr[[snp]]) )
		{
		print(snp)
		mdr[[snp]][1:200]=genotype(mdr[[snp]][1:200], c(.40, .40, .20))
		}
	}


filename=paste("klassen_sample_", sample, ".mdr", sep="")
write.table(mdr, file=paste(dir, filename, sep="/"), sep="\t", row.names=FALSE, quote=FALSE)


