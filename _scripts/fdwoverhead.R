library(ggplot2)
library(dplyr)
library(reshape2)

setwd("~/Dropbox/git/3manuek.github.io/_data/fdwoverhead")

rm(allfiles)

allfiles = NULL

for (filename in dir(pattern = "^bench*")) {
#for (filename in dir(pattern = "^benchRO.*ext.*")) {
   #typecols <- strsplit(filename,"[.]")[[1]]
   typecols <- rbind(strsplit(gsub("bench","",filename),"[.]")[[1]])
   typecols <- cbind(gsub("bench","",filename),typecols)
   allfiles <- rbind(allfiles,cbind(typecols,read.csv(filename, header = FALSE,sep = "," ,
                 colClasses = c("numeric","numeric","numeric")) ))
}

colnames(allfiles) <- c("Bench","Type","Target","Latency", "TPSi", "TPSe")

allfiles$Bench <- as.factor(allfiles$Bench)
allfiles$Target <- as.factor(allfiles$Target)

byBenchTarget <- group_by(allfiles, Bench, Type, Target)

byBenchTPS <- summarize(byBenchTarget,max(TPSi),min(TPSi), mean(TPSi))
colnames(byBenchTPS) <- c("Bench","Type","Target","Max","Min", "Mean")

byBenchLAT <- summarize(byBenchTarget,max(Latency),min(Latency), mean(Latency))
colnames(byBenchLAT) <- c("Bench","Type","Target","Max","Min", "Mean")

# Graph
dodge <- position_dodge(width = 0.9)

limitsTPS <- aes(ymax = byBenchTPS$Max, ymin = byBenchTPS$Min )
limitsLAT <- aes(ymax = byBenchLAT$Max,ymin = byBenchLAT$Min)

png("../../assets/posts/tpsfdw.png")

#png("../../assets/posts/tpsfdwro.png")
TPSplot <- ggplot(data = byBenchTPS, aes(x = Target, y = Mean,fill = Bench )) #
TPSplot + geom_bar(stat = "identity", position = dodge) + #, aes(fill=Bench)
      geom_errorbar(limitsTPS, position = dodge, width = 0.25) +
      labs(x = "Target", y = "TPS") +
      ggtitle("TPS including connections") +
      facet_grid(Type~., scales = "free") +
      theme(legend.background = element_rect(fill="gray90", size=.5, linetype="dotted"))
dev.off()

png("../../assets/posts/latfdw.png")

LATplot <- ggplot(data = byBenchLAT, aes(x = Target, y = Mean, fill = Bench ))
LATplot +  geom_bar(stat = "identity", position = dodge) +
      geom_errorbar(limitsLAT, position = dodge, width = 0.25) +
      labs(x = "Target", y = "Latency") +
      ggtitle("FDW Latency in ms") +
      facet_grid(Type~., scales="free") +
      theme(legend.background = element_rect(fill="gray90", size=.5, linetype="dotted"))
dev.off()