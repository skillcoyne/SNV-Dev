read.table("c:/sarah/chr5.MDR",header=TRUE, sep=" ")-> snpData

read.table("chr5.mdr", header=TRUE, sep=" ")->snpData

noSnps=201
vector("numeric",noSnps) -> allGeneResults
vector("numeric",noSnps) -> allGeneResults2
names(allGeneResults)<-colnames(snpData)[2:(noSnps+1)]
names(allGeneResults2)<-colnames(snpData)[2:(noSnps+1)]
nData<-matrix(0,nrow(snpData),2)
colnames(nData)<-vector("character",2)
colnames(nData)[1]<-"Class"
colnames(nData)[2]<-"x1"
rownames(nData)<-rownames(snpData)
nData[,1]<-snpData[,1]
wData<-snpData

for(i in 1:length(allGeneResults))
	{
	colToUse<-colnames(snpData)[i+1]

	nData[,2]<-snpData[,colToUse]
	mylogit<- glm(Class~as.factor(x1), family=binomial(link="logit"), na.action=na.pass,data=as.data.frame(nData))

	#allGeneResults[i]<-logLik(mylogit)[1]
	#allGeneResults[i]<-mylogit$null.deviance - mylogit$deviance
	allGeneResults2[i]<-1-pchisq(mylogit$null.deviance-mylogit$deviance, mylogit$df.null-mylogit$df.residual)
allGeneResults[i]<-mylogit$null.deviance - mylogit$deviance

	}	

plot(allGeneResults, allGeneResults2,main="Logisitic Regression: 200 SNPs for 400 Patients (Synthetic)",ylab="P value", xlab="Likelihood Ratio Test Score")

points(allGeneResults["chr5_SNP113"],allGeneResults2["chr5_SNP113"],col="red", pch=19)

nData<-matrix(0,nrow(snpData),3)
colnames(nData)<-vector("character",3)
colnames(nData)[1]<-"Class"
colnames(nData)[2]<-"x1"
colnames(nData)[3]<-"x2"
rownames(nData)<-rownames(snpData)
nData[,1]<-snpData[,1]
nData[,2]<-snpData[,"chr5_SNP170"]
for(i in 1:length(allGeneResults))
	{
	colToUse<-colnames(snpData)[i+1]

	nData[,3]<-snpData[,colToUse]
	mylogit<- glm(Class~as.factor(x1)*as.factor(x2), family=binomial(link="logit"), na.action=na.pass,data=as.data.frame(nData))
	#allGeneResults[i]<-mylogit$aic
	allGeneResults[i]<-mylogit$null.deviance - mylogit$deviance
	allGeneResults2[i]<-1-pchisq(mylogit$null.deviance-mylogit$deviance, mylogit$df.null-mylogit$df.residual)
	#allGeneResults[i]<-logLik(mylogit)[1]
	}
plot(allGeneResults, allGeneResults2,main="Logisitic Regression on pairwise 201 SNPs for 400 Patients (Synthetic)",sub="Only showing pairs with SNP 170",ylab="P value", xlab="Likelihood Ratio Test Score")

points(allGeneResults["chr5_SNP197"],allGeneResults2["chr5_SNP197"],col="red", pch=19)
