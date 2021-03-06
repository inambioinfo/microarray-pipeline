
##Function for making an SQL-lite object out of pipeline output

makeSQLObj <- function(Robj, name="mydata", covarTable = NULL, annotation="Humanv3", users = c("mark.dunning@cancer.org.uk"), deTable = NULL, fData=NULL, GSE=NULL,StudyTitle=NULL){

library(RSQLite)
library(reshape)

if(!is.matrix(Robj)) eMat <- exprs(Robj)

else eMat <- Robj

if(file.exists(paste(name, ".sqlite",sep=""))) stop(paste("An sqlite object called", paste(name, ".sqlite",sep=""), " already exists in the working directory. Chose a different name or delete existing object"))

drv = dbDriver("SQLite")
dbcon = dbConnect(drv, dbname=paste(name, ".sqlite",sep=""))

##make sql metadata; annotation for the expression data and user list

message("Adding user information to sqlite")


dbGetQuery(dbcon, "CREATE Table users (id INTEGER, email_address TEXT)")

sql <- "INSERT INTO users VALUES ($id, $email_address)"

user_data <- data.frame(id = 1:length(users), email_address = users)

gval <- dbGetPreparedQuery(dbcon, sql, bind.data = user_data)

cval <- dbCommit(dbcon)



dbGetQuery(dbcon, "CREATE Table Meta (id TEXT, value TEXT)")

sql <- "INSERT INTO Meta Values ($id, $value)"

meta_data <- data.frame(id="BiocAnnotation", value=annotation)

gval <- dbGetPreparedQuery(dbcon, sql, bind.data = meta_data)

cval <- dbCommit(dbcon)

meta_data <- data.frame(id="GSE", value=GSE)

gval <- dbGetPreparedQuery(dbcon, sql, bind.data = meta_data)

cval <- dbCommit(dbcon)

meta_data <- data.frame(id="StudyTitle", value=StudyTitle)

gval <- dbGetPreparedQuery(dbcon, sql, bind.data = meta_data)

cval <- dbCommit(dbcon)



###Add a GSE accession number if it is known


gval <- dbGetPreparedQuery(dbcon, sql, bind.data = meta_data)

cval <- dbCommit(dbcon)



message("Attaching covariate information")

if(is.null(covarTable)){

message("Attempting to create table of covariates from R object")

covarTable <- data.frame(ArrayID = sampleNames(Robj), pData(Robj))

}

createCovarCmd <- paste("CREATE Table Covars (", paste(colnames(covarTable), collapse=" TEXT, "), "TEXT)")

dbGetQuery(dbcon, createCovarCmd)

sql <- paste("INSERT INTO Covars Values ($", paste(colnames(covarTable), collapse=", $",sep=""),")",sep="")

gval <- dbGetPreparedQuery(dbcon, sql, bind.data = covarTable)

cval <- dbCommit(dbcon)

if(!(is.null(deTable))){

createDECmd <- paste("CREATE Table DeTable (", paste(colnames(deTable), collapse=" TEXT, "), "TEXT)")

dbGetQuery(dbcon, createDECmd)

sql <- paste("INSERT INTO DeTable Values ($", paste(colnames(deTable), collapse=", $",sep=""),")",sep="")

gval <- dbGetPreparedQuery(dbcon, sql, bind.data = deTable)

cval <- dbCommit(dbcon)

}

###Can specify own annotation matrix if none is available through bioconductor

if(!(is.null(fData))){

createDECmd <- paste("CREATE Table fData (", paste(colnames(fData), collapse=" TEXT, "), "TEXT)")

dbGetQuery(dbcon, createDECmd)

sql <- paste("INSERT INTO fData Values ($", paste(colnames(fData), collapse=", $",sep=""),")",sep="")

gval <- dbGetPreparedQuery(dbcon, sql, bind.data = fData)

cval <- dbCommit(dbcon)

}




message("Converting expression matrix into long format")

system.time(meltMat <- melt(eMat))

colnames(meltMat) <- c("ProbeID", "ArrayID", "Expression")






dbGetQuery(dbcon, "CREATE Table assayData (ProbeID TEXT, ArrayID TEXT, Expression DOUBLE)")

sql <- "INSERT INTO assayData VALUES ($ProbeID, $ArrayID, $Expression)"

message("Inserting expression data into table")

system.time(gval <- dbGetPreparedQuery(dbcon, sql, bind.data = meltMat))

message("DONE...sqlite object ready to query")

}



validUser <- function(dbcon=NULL, email, table="users",...){


	if(is.null(dbcon)){


		dbcon <- connectToAnalysisDb(,...)

	}


	userList <- dbGetQuery(dbcon, paste("select * from", table))

	return(tolower(email) %in% tolower(userList[,2]))

}



connectToAnalysisDb <-
function(host = "uk-cri-lbio05", user = NULL, dbname ="metabric", password = NULL,...){


if(is.null(user)) stop("Must speciify a Username\n")

else if(is.null(password)) stop("Must speciify a Password\n")


else{
conn <- try(dbConnect(MySQL(),host=host, user=user, dbname=dbname, password=password))

conn

}


}

connectToLocalDb <- function(db){

drv = dbDriver("SQLite")
dbcon = dbConnect(drv, dbname=db)
dbcon

}


getExpressionForIDs <- function(DB, table="assayData", expression="expression", sampleCol = "ArrayID",idCol = "ProbeID", queryIDs = NULL){

if(is.null(queryIDs)){

message("Retrieving data for all IDs..")

dbGetQuery(DB,"SELECT * FROM assayData")

}

else{

	queryIDs = paste("('",paste(queryIDs, collapse = "', '"), "')",sep="")


	cmd = paste("SELECT ", sampleCol, ",", idCol, ",", expression  ," FROM ", table, " WHERE ", idCol, " in ",queryIDs, sep="")
dbGetQuery(DB, cmd)
}



}


attachCovarsToExpression <- function(DB, assayDataTable = "assayData", covarTable ="Covars", sampleCol = "ArrayID", idCol="ProbeID", queryIDs=NULL,covars=NULL){

  expressionMatrix <- getExpressionForIDs(DB, table=assayDataTable, sampleCol=sampleCol, idCol=idCol,queryIDs=queryIDs)

  allcovars <- dbGetQuery(DB, paste("SELECT * FROM", covarTable))


  combMatrix <- data.frame(expressionMatrix, allcovars[match(expressionMatrix$ArrayID, allcovars$ArrayID),])

}


mapToProbes <- function(id, from="SYMBOL", annoName = "illuminaHumanv3"){

  ###If the annotation is Illumina, use the reannotated mappings
  if(length(grep("illumina", annoName)) & from == "SYMBOL") from <- "SYMBOLREANNOTATED"
  
	
	annoPkg <- paste(annoName, ".db",sep="")	
   	annoLoaded <- require(annoPkg, character.only=TRUE)

  	if(annoLoaded){	

		mapEnv <-  as.name(paste(annoName, toupper(from),sep=""))

    		t <- try(eval(mapEnv),silent=TRUE)

    		if(class(t) == "try-error"){
      			message(paste("Could not find a ", from , "mapping in annotation package ", annoPkg,". Perhaps it needs updating?", sep=""))

    		}
    
    		else{
			outIDs <- unlist(mget(id, revmap(eval(mapEnv)), ifnotfound=NA))
			
  		}

	

	} 
	else message("Could not load package ", annoPkg)
		
	outIDs
}



getProbesInRegion <- function(chr, start, end, annoName="illuminaHumanv3"){

	annoPkg <- paste(annoName, ".db",sep="")	
   	annoLoaded <- require(annoPkg, character.only=TRUE)

  	if(annoLoaded){	


	mapEnv <-  as.name(paste(annoName, "GENOMICLOCATION",sep=""))

    		t <- try(eval(mapEnv),silent=TRUE)

    		if(class(t) == "try-error"){
      			message(paste("Could not find a GENOMICLOCATION mapping in annotation package ", annoPkg,". Perhaps it needs updating?", sep=""))

    		}
    
    		else{
	allLocs <- as.list(eval(mapEnv))
	
  
 
	cat("Get probes in Region", chr, ":",start,":", end, "\n")

	chrs <- unlist(lapply(allLocs,function(x) strsplit(as.character(x), ":")[[1]][1]))
	spos <- unlist(lapply(allLocs,function(x) strsplit(as.character(x), ":")[[1]][2]))
	epos <- unlist(lapply(allLocs,function(x) strsplit(as.character(x), ":")[[1]][3]))
		

	chrRangs <- RangedData(seqnames = chr, ranges=IRanges(start = as.numeric(spos[which(chrs == chr)]), end = as.numeric(epos[which(chrs == chr)])),names=names(chrs)[which(chrs==chr)])

	query <- RangedData(IRanges(start = as.numeric(start), end=as.numeric(end)))

	matches <-  as.matrix(findOverlaps(query, chrRangs))[,2]

	pIDs <- chrRangs$names[matches]


	}


	}

pIDs

}



plotIlluminaLocation <- function(Symbol, ensembl = NULL, annoName=NULL){


	require("GenomeGraphs")

	if(is.null(ensembl)){

		ensembl = useMart(biomart = "ensembl", dataset="hsapiens_gene_ensembl")

	}

	
	
	annoPkg <- paste(annoName, ".db",sep="")	
   	annoLoaded <- require(annoPkg, character.only=TRUE)

  	if(annoLoaded){	

		mapEnv <-  as.name(paste(annoName, "SYMBOL",sep=""))

    		t <- try(eval(mapEnv),silent=TRUE)

    		if(class(t) == "try-error"){
      			message(paste("Could not find a ", from , "mapping in annotation package ", annoPkg,". Perhaps it needs updating?", sep=""))

    		}
    
    		else{
			pIDs <- unlist(mget(Symbol, revmap(eval(mapEnv)), ifnotfound=NA))
			
  		}

	

	} 
	else message("Could not load package ", annoPkg)
	
	

	gn <- try(makeGene(Symbol, type= "hgnc_symbol",biomart=ensembl))
	


	chrName <- paste("chr", getBM(attributes="chromosome_name", filters="hgnc_symbol", value=Symbol, ensembl)[[1]], sep="")
		
	
	uExon <- unique(gn@ens[,3])

	exStart <- unlist(lapply(split(gn@ens[,5], gn@ens[,3]), unique))
	exEnd <- unlist(lapply(split(gn@ens[,4], gn@ens[,3]), unique))

			##get location info for the probe
	mapEnv <-  as.name(paste(annoName, "GENOMICLOCATION",sep=""))
		
	probeLocs <- mget(pIDs, eval(mapEnv))
			##ensure the order is the same	



	pStarts <- as.numeric(unlist(lapply(probeLocs,function(x) strsplit(x, ":")[[1]][2])))

	pEnds <- as.numeric(unlist(lapply(probeLocs,function(x) strsplit(x, ":")[[1]][3])))

	pStrands <- unlist(lapply(probeLocs,function(x) strsplit(x, ":")[[1]][4]))



	pOverlays= list()			
	
	for(i in 1:length(pIDs)){

		if(pStrands[i] == "+"){			

			pOverlays = append(pOverlays, makeRectangleOverlay(start = as.numeric(pStarts[i]), end =as.numeric(pEnds[i]),region=c(1,2)))
			pOverlays = append(pOverlays, makeTextOverlay(pIDs[i], xpos = as.numeric(pStarts[i]), ypos = 0.95))
			
		}

		else{

			pOverlays = append(pOverlays, makeRectangleOverlay(start = as.numeric(pStarts[i]), end =as.numeric(pEnds[i]),region=c(1,2)))
			pOverlays = append(pOverlays, makeTextOverlay(pIDs[i], xpos = as.numeric(pStarts[i]), ypos = 0.95))		

			}

	}


		
	minX = min(min(exStart), min(pStarts))-1000
	maxX = max(max(exEnd), max(pEnds)) + 1000

	gdPlot(list(makeGenomeAxis(add35 = TRUE, add53=TRUE), gn), overlays = pOverlays, minBase=minX, maxBase=maxX) 

}



boxplotFromPublicData <- function(dbcon, gene, factor="Sample_Group",annoName=NULL){


    ##No Bioconductor annotation is associated with the db, so use the fData table
    if("fData" %in% dbListTables(dbcon)){
    
      queryIDs <- dbGetQuery(dbcon, paste("Select probe FROM fData where Symbol = '", gene,"'",sep=""))
      
      
      
   
     }

     else {
   
      if(is.null(annoName)){

	      meta <- dbGetQuery(dbcon, "SELECT * FROM Meta")
	      annoName <- meta$value[which(meta$id == "BiocAnnotation")]		

      }
      
      queryIDs <- mapToProbes(gene, annoName=annoName)	
      
    }
  
  
  if(!is.na(queryIDs)){
  
    combMat <- attachCovarsToExpression(dbcon, queryIDs = queryIDs)

    factorcol <- which(colnames(combMat) == factor)

    combMat <- attachCovarsToExpression(dbcon, queryIDs = queryIDs)

    if(nrow(combMat) >0){
    
    
    
    if(any(is.na(combMat[,factorcol]))){
    combMat2 <- combMat[-which(is.na(combMat[,factorcol])),]	
    }
    else combMat2 <- combMat
    

    colnames(combMat2)[factorcol] <- "FactorToPlot"

  
      
    myplot <- ggplot(combMat2, aes(x = FactorToPlot, y = Expression, fill = FactorToPlot)) + geom_boxplot() + xlab(factor)+ scale_fill_discrete(name = factor) + facet_wrap(~ProbeID,ncol=4)

    myplot
    
    }
    
    }

}


geneHeatmap <- function(dbcon, genes,annoName=NULL,outfile="Results.html", outfile_path="."){
  
 
  dir.create(outfile_path)
  
  library(hwriter)
  
  outPage = openPage(filename = outfile)
  
  
  if(is.null(annoName)){
    
    meta <- dbGetQuery(dbcon, "SELECT * FROM Meta")
    annoName <- meta$value[which(meta$id == "BioCAnnotation")]		
    
  }
  
 
  ####Get all probes for all genes
  

  allIDs <- list()
  mappedSymbols <- list()
  
  for(i in 1:length(genes)){
    
    
    queryIDs <- mapToProbes(genes[i], annoName=annoName)	
    
    
    if(!is.na(queryIDs)){
      
      allIDs [[i]] <- as.character(queryIDs)
      mappedSymbols[[i]] <- rep(as.character(genes[i]), length(queryIDs))
      
      
    }
    
  }
  
  names(mappedSymbols) <- genes
  
  
  allIDs <- unlist(allIDs)
  mappedSymbols <- unlist(mappedSymbols)
  
  combMat <- attachCovarsToExpression(dbcon, queryIDs = allIDs)
  combMat <- data.frame(combMat, Symbol=mappedSymbols[match(allIDs, combMat$ProbeID)])
  
  plotMat <- data.frame(ProbeID = combMat$ProbeID, ArrayID=combMat$ArrayID, Expression=combMat$Expression)
  plotMat <- cast(plotMat, ProbeID~ArrayID)
  
  rownames(plotMat) <- plotMat[,1]
  plotMat <- plotMat[,-1]  
  
  
  newRows <- as.character(combMat$Symbol[match(rownames(plotMat),combMat$ProbeID)])
  
  plotMat <- plotMat[,-1]
  
  colmat <- matrix(nrow = ncol(plotMat),ncol=2)
  colmat[,2] <- "white"
  
  grouping <- as.factor(combMat$Sample_Group)
  groupcols <- grouping
  levels(groupcols) <- brewer.pal(length(levels(groupcols)),"Paired")
  
 # hwrite("The heatmap will be coloured according to the following sample groups", outPage,heading=2,br=TRUE)
  
 
  sampsize <- table(combMat$Sample_Group[match(colnames(plotMat), combMat$ArrayID)])
  
  hwrite(data.frame(Group=levels(grouping), n=sampsize)[,-2], bgcolor=levels(groupcols),page=outPage,border=0)
  
  
  
  
  colmat[,1] <- as.character(groupcols[match(colnames(plotMat), combMat$ArrayID)])
  
  hmCol = rev(colorRampPalette(brewer.pal(10, "RdBu"))(64))
  
  
  pngfile <-"heatmap.png"
  png(paste(outfile_path, pngfile,sep="/"),width=1200,height=800)
  
  heatmap.plus(as.matrix(plotMat),ColSideColors=colmat,labRow=newRows,col=hmCol)

  
  dev.off()  
  
  
  hwriteImage(pngfile, outPage,br=TRUE)
  
  
  
}



geneSummary <- function(dbcon, genes, factor = "Sample_Group", selectBestProbe = FALSE, annoName=NULL, outfile="Results.html", outfile_path=".", externalData=NULL){


	library(hwriter)
  library(reshape)
	dir.create(outfile_path)
	
	
	outPage = openPage(filename = outfile)


	if(is.null(annoName)){

		meta <- dbGetQuery(dbcon, "SELECT * FROM Meta")
		annoName <- meta$value[which(meta$id == "BiocAnnotation")]		

	}


	####Get all probes for all genes
	
	
	
	
	
	allIDs <- list()
	mappedSymbols <- list()

	for(i in 1:length(genes)){
	  
	  
	  queryIDs <- mapToProbes(genes[i], annoName=annoName)	
	  
	  
	  if(!is.na(queryIDs)){
	    
      allIDs [[i]] <- as.character(queryIDs)
	    mappedSymbols[[i]] <- rep(as.character(genes[i]), length(queryIDs))
	    
	    
	  }
    
	}
  
    names(mappedSymbols) <- genes
  
    linksToPlots <-paste("#",genes, "Boxplot",sep="")
    linksToAnnotation <-paste("#",genes, "Annotation",sep="")
    linksToDE <- paste("#",genes, "DE",sep="")
    
  
	  NumberOfProbes = unlist(lapply(mappedSymbols, length))
    linksToPlots[which(NumberOfProbes == 0)] <- ""
	  linksToAnnotation[which(NumberOfProbes == 0)] <- ""
	  linksToDE[which(NumberOfProbes == 0)] <- ""
  
    summary<- data.frame(Symbol = genes, NumberOfProbes = unlist(lapply(mappedSymbols, length)), Annotation = "Annotation", Boxplots = "Boxplots", DifferentialExpression = "DifferentialExpression")
  
  
  
	  hwrite("Report Summary", outPage,heading=1,br=TRUE,name="Summary")
    hwrite(summary, outPage, br=TRUE, col.link=list(Annotation=linksToAnnotation, Boxplots=linksToPlots, DifferentialExpression=linksToDE))
  	hwrite("Diferential expression summary", heading=2, br=TRUE,outPage, link="#DESummary")
	  
	  
	
	 
  allIDs <- unlist(allIDs)
	mappedSymbols <- unlist(mappedSymbols)
  
  
  ##Grab the DE results that we will use later on
  
  
	fullDE <- dbGetQuery(dbcon,"SELECT * FROM DeTable")
	nprobes <- length(unique(fullDE$ProbeID))
  
  ###A bit of a fiddle to get the ranks for each contrast
  
  
  Rank = rep(NA, nrow(fullDE))
  rnk <- lapply(split(as.numeric(fullDE$LogOdds), as.character(fullDE$Contrasts)),rank)
  
  for(i in 1:length(rnk)){
    
    Rank[grep(names(rnk)[i], fullDE$Contrasts)] <- rnk[[i]]
        
  }
  
  
  fullDE <- data.frame(fullDE, Significant = as.numeric(fullDE$Adjusted) < 0.05, Rank = nprobes-Rank+1)
	
  genes <- genes[which(NumberOfProbes > 0)]
	
  for(i in 1:length(genes)){
		
		###Do plot of probe position?
		
    hwrite("<----------------------------------------------------------------------------------------------->",outPage,br=TRUE)
		hwrite("",outPage, br=TRUE)
    hwrite("",outPage, br=TRUE)
    hwrite("",outPage, br=TRUE)
    hwrite("",outPage, br=TRUE)
    
		locsPic <- paste(outfile_path, "/",genes[i], "-locations.png",sep="")
		
		png(locsPic,width=800,height=400)
		
		plotIlluminaLocation(genes[i], annoName=annoName)
		
		dev.off()
		
		hwrite(genes[i], outPage,heading=2,br=TRUE,name=genes[i])
    hwrite("Navigation",outPage,br=TRUE)
		hwrite(genes, link=paste("#",genes,sep=""), page=outPage,br=TRUE,border=0)
    hwrite("Diferential expression summary", br=TRUE,outPage, link="#DESummary")
    hwrite("Report Summary", outPage, br=TRUE,link="#Summary")
    
    heading=paste("Positions of probes for ", genes[i], " on the Illumina ", annoName, " chip",sep="")
		
		hwrite(heading, outPage,heading=2,br=TRUE,name=paste(genes[i],"Annotation",sep=""))
		hwriteImage(locsPic, outPage,br=TRUE)
		
		fields <- c("PROBEQUALITY", "CODINGZONE", "GENOMICLOCATION", "REPEATMASK", "SECONDMATCHES", "ENTREZREANNOTATED", "PROBESEQUENCE")
    queryIDs <- mapToProbes(genes[i], annoName=annoName)	
    
    qualCols <- matrix(nrow=4, ncol=2)
    qualCols[,1] <- c("Perfect", "Good", "Bad", "No match")
    qualCols[,2] <- c("#aaffaa", "#66ffff", "#ffbbaa", "#ff5500")
  
    

		probeSummary <- matrix(nrow = length(queryIDs),ncol=length(fields))
		colnames(probeSummary) <- fields
		rownames(probeSummary) <- queryIDs
		
		for(j in 1:length(queryIDs)){
		    probeSummary[j,] <- unlist(sapply(fields, function(x) mget(queryIDs[j], eval(as.name(paste(annoName, x,sep=""))))))
		}
		
    Entrez = paste("<a href=http://www.ncbi.nlm.nih.gov/gene?term=",probeSummary[,6], ">",probeSummary[,6],"</a>",sep="")
    
    probeSummary[,6] <- Entrez
    
		###Select best probe by IQR if requested?
		
		heading=paste("Summary of annotation of probes for ", genes[i], " on the ", annoName, " chip",sep="")
		
		hwrite(heading, outPage,heading=2,br=TRUE)
		hwrite(probeSummary, outPage,br=TRUE, row.bgcolor = c(NA,qualCols[match(probeSummary[,1], qualCols[,1]),2]))

		
		
		
		
		combMat <- attachCovarsToExpression(dbcon, queryIDs = queryIDs)

		factorcol <- which(colnames(combMat) == factor)
		
		heading <- paste("showing the expression of ", genes[i], " against ", factor, sep="")  
		  
		hwrite("Boxplots ", link="http://en.wikipedia.org/wiki/Box_plot", outPage, heading=2)
    hwrite(heading, outPage, heading=2,br=TRUE,name=paste(genes[i], "Boxplot",sep=""))
    
		message("Plotting gene ", genes[i])
		
		if(any(is.na(combMat[,factorcol]))){
		combMat2 <- combMat[-which(is.na(combMat[,factorcol])),]	
		}
		else combMat2 <- combMat
		
		pngfile <- paste(genes[i], ".png",sep="")
	
		colnames(combMat2)[factorcol] <- "FactorToPlot"
	
	    
		
		myplot <- ggplot(combMat2, aes(x = FactorToPlot, y = Expression, fill = FactorToPlot)) + geom_boxplot() + xlab(factor)+ scale_fill_discrete(name = factor) + facet_wrap(~ProbeID,ncol=4)
	
		
		ggsave(myplot, filename=paste(outfile_path, pngfile,sep="/"),width=6,height=4*ceiling(length(queryIDs)/4),dpi=100)
		hwriteImage(pngfile, outPage,br=TRUE)
		
				##Now addd the plots for external dataset
		
		if(!is.null(externalData)){
		
		
		for(l in 1:length(externalData)){
		
		
		  myplot <- try(boxplotFromPublicData(externalData[[l]], genes[i]), silent=TRUE)
		  
		  
		 if(any(class(myplot) == "ggplot")){
		 
		 heading <- paste("Boxplot using the ", names(externalData)[l], "Dataset")
		 
		  GEO <- as.character(dbGetQuery(cai, "SELECT value FROM Meta WHERE id = 'GSE'"))

		 
		  GEOurl <- paste("http://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=", GEO, sep="")
		 
		 
		  hwrite(heading, outPage, heading=2,br=TRUE)
		  hwrite(GEO, outPage, link = GEOurl, br=TRUE)
		  
		  ext_file <- paste(genes[i], "-",names(externalData)[l],".png",sep="")

		  ggsave(myplot, filename=paste(outfile_path, ext_file,sep="/"),width=6,height=4,dpi=100)

		  hwriteImage(ext_file, outPage,br=TRUE)

		  
		  
		  }
		
		
		
		}
		
		}
		
		
		
    heading <- paste("Differential expression results for ", genes[i], sep="")  
		

		hwrite(heading, outPage, heading=2,br=TRUE,name=paste(genes[i], "DE",sep=""))
		
		
		plotFrame <- fullDE
		
    
    
		probeStats <- plotFrame[which(fullDE$ProbeID %in% queryIDs),]
    rownames(probeStats) <- 1:nrow(probeStats)
    
    hwrite(probeStats, outPage, br=TRUE,col.link=list(Contrasts = paste("#Contrasts:",probeStats$Contrast,sep="")))
    hwrite("Volcano plots", outPage, heading=2,br=TRUE,link="http://en.wikipedia.org/wiki/Volcano_plot_(statistics)")
    
		pngfile <- paste(genes[i], "-DE.png",sep="")
		
		myplot <- ggplot(fullDE, aes(x = as.numeric(LogFC), y = as.numeric(LogOdds))) + geom_point(colour="blue", alpha=1/10)+ geom_text(data = probeStats, aes(x = as.numeric(LogFC), y = as.numeric(LogOdds),label=ProbeID,colour=ProbeID)) + ylab("Log Odds") + xlab("Log FC") + facet_wrap(~Contrasts)
		
		ggsave(myplot, filename=paste(outfile_path, pngfile,sep="/"),width=8,height=6,dpi=100) 

		hwriteImage(pngfile, outPage,br=TRUE)


		
		
		
	

	}	

	
  deTable <- fullDE[which(fullDE$ProbeID %in% allIDs),]
  
	deTable$LogFC=as.numeric(deTable$LogFC)
  deTable$Pvalue=as.numeric(deTable$Pvalue)
  deTable$Adjusted = as.numeric(deTable$Adjusted)
  deTable$LogOdds=as.numeric(deTable$LogOdds)
  deTable$Rank = as.numeric(deTable$Rank)
	
	myTable <- data.frame(ProbeID = deTable[,1], Symbol = paste("<a href=#", mappedSymbols,"DE>", mappedSymbols,"</a>",sep=""),deTable[,-1])


	hwrite("Summary of differential expression", outPage,heading=2,br=TRUE,name="DESummary")
	
  
  hwrite("Selected Genes", outPage,heading=2, br=TRUE)
  
  
	gTab <- gvisTable(myTable,options=list(width=1200))
	cat(createGoogleGadget(gTab), file=outPage)
	
  ###Could report the top hits for each contrast?
  
  
	hwrite("Details of specific contrasts", outPage,heading=2, br=TRUE)
	
  
  splitContrast <- split(fullDE, fullDE$Contrasts)
  
  for(nc in 1:length(splitContrast)){
    
    
    topHits <- order(as.numeric(splitContrast[[nc]]$LogOdds), decreasing=TRUE)[1:50]
    
    topMat <- splitContrast[[nc]][topHits,]
    
   
    annoToGet <- c("SYMBOLREANNOTATED", "GENOMICLOCATION", "ENTREZREANNOTATED")
    
    annoSummary <- matrix(nrow = nrow(topMat),ncol=length(annoToGet))
    colnames(annoSummary) <- annoToGet
    
    for(j in 1:nrow(topMat)){
      annoSummary[j,] <- unlist(sapply(annoToGet, function(x) mget(topMat[j,1], eval(as.name(paste(annoName, x,sep=""))))))
    }
    
    
    Symbol = paste("<a href=http://www.genecards.org/index.php?path=/Search/keyword/", annoSummary[,1],">", annoSummary[,1],"</a>",sep="")
    Entrez = paste("<a href=http://www.ncbi.nlm.nih.gov/gene?term=",annoSummary[,3], ">",annoSummary[,3],"</a>",sep="")
    
    annoSummary[,1] <- Symbol
    annoSummary[,3] <- Entrez
  
    totalDEGenes <- sum(splitContrast[[nc]]$Adjusted < 0.05)
    
    cName <- unique(splitContrast[[nc]]$Contrasts)
    
    hwrite(cName, outPage,heading=2, br=TRUE, name=paste("Contrasts", cName,sep=":"))
    
    hwrite(paste("Total Number of DE genes", totalDEGenes,sep=":"), outPage,heading=2,br=TRUE)
    
    newMat <- data.frame(ProbeID=topMat$ProbeID, annoSummary, LogFC=as.numeric(topMat$LogFC), Pvalue=as.numeric(topMat$Pvalue),Adjusted=as.numeric(topMat$Adjusted), LogOdds=as.numeric(topMat$LogOdds))
   
    allDE <- splitContrast[[nc]]$ProbeID[which(splitContrast[[nc]]$Adjusted < 0.05)]
    mapEnv <-  as.name(paste(annoName, "GENOMICLOCATION",sep=""))
    
    genLoc <- unlist(mget(as.character(allDE), eval(mapEnv),ifnotfound=NA))
    
    chr <- sapply(genLoc, function(x) strsplit(x, ":", fixed=TRUE)[[1]][1])
    start <- sapply(genLoc, function(x) strsplit(x, ":", fixed=TRUE)[[1]][2])
    end <- sapply(genLoc, function(x) strsplit(x, ":", fixed=TRUE)[[1]][3])
    
    if(any(is.na(chr))) {
      start <- start[-which(is.na(start))]
      end <- end[-which(is.na(chr))]
      chr <- chr[-which(is.na(chr))]
      
    }
    
    deRngs <- GRanges(seqnames = chr, ranges=IRanges(start=as.numeric(start), end=as.numeric(end), names=names(start)))
    
    library(ggbio)
    
    
    data("hg19Ideogram", package="biovizBase")
    
    hg19Ideo <- hg19Ideogram
    chr.sub <- paste("chr", 1:22, sep = "")
    
    hg19Ideo <- keepSeqlevels(hg19Ideogram, chr.sub)

    head(hg19Ideo)
    
    p <- ggplot() + layout_circle(hg19Ideo, geom="ideo", fill="gray70", radius=30, trackwidth=4)  + layout_circle(hg19Ideo, geom="text", aes(label=seqnames),vjust=0, radius=38,trackwidth=7) + layout_circle(deRngs, geom="rect", color = "steelblue", radius = 23, trackwidth=6)

    file <- paste(cName, "DElocations.png",sep="")
    
    hwrite("Location of all DE probes", outPage,heading=2, br=TRUE)
    
    
    ggsave(p,filename=paste(outfile_path, file,sep="/"),width=8,height=8,dpi=100) 
    
    hwriteImage(file, outPage,br=TRUE)
    
    
    hwrite("Top 50 probes", outPage,heading=2, br=TRUE)
    
    gTab <- gvisTable(newMat,options=list(width=1200))
    cat(createGoogleGadget(gTab), file=outPage)
    

  }
  
  
  
	closePage(outPage)	
  
  
  
	


}




geneCorrelation <- function(dbcon, gene1, gene2, factor = "Sample_Group", selectBestProbe = FALSE, annoName=NULL, outfile="Results.html", outfile_path="."){

	library(hwriter)
  
	dir.create(outfile_path)
	
	
	outPage = openPage(filename = outfile)


	if(is.null(annoName)){

		meta <- dbGetQuery(dbcon, "SELECT * FROM Meta")
		annoName <- meta$value[which(meta$id == "annotation")]		

	}


	gene1IDs <- mapToProbes(gene1, annoName=annoName)	
      

      
	plotCount <- 1
      
	if(!is.na(gene1IDs)){
		
		  ###Do plot of probe position?
				
				
		  locsPic <- paste(outfile_path, "/",gene1, "-locations.png",sep="")
		  
		  png(locsPic,width=800,height=400)
		  
		  plotIlluminaLocation(gene1, annoName=annoName)
		  
		  dev.off()
			
		  heading=paste("Positions of probes for ", gene1, " on the Illumina ", annoName, " chip",sep="")
		  
		  hwrite(heading, outPage,heading=2,br=TRUE)
		  hwriteImage(locsPic, outPage)
		  
		  fields <- c("PROBEQUALITY", "CODINGZONE", "GENOMICLOCATION", "REPEATMASK", "SECONDMATCHES", "ENTREZID")
		  

		  probeSummary <- matrix(nrow = length(gene1IDs),ncol=length(fields))
		  colnames(probeSummary) <- fields
		  rownames(probeSummary) <- gene1IDs
		  
		  for(k in 1:length(gene1IDs)){
		      probeSummary[k,] <- unlist(sapply(fields, function(x) mget(gene1IDs[j], eval(as.name(paste("illumina", annoName, x,sep=""))))))
		  }
		  
		  
		  
		  ###Select best probe by IQR if requested?
		  
		  heading=paste("Summary of annotation of probes for ", gene1, " on the Illumina ", annoName, " chip",sep="")
		  
		  hwrite(heading, outPage)
		  hwrite(probeSummary, outPage)
		  
		  hwrite("Correlation plots", outPage)
		  hwrite(gene1IDs, link=paste("#",gene1IDs,sep=""), page=outPage)
		
		

	  for(j in 1:length(gene2)){


		  queryIDs <- mapToProbes(gene2[j], annoName=annoName)	
	
		  if(!is.na(queryIDs)){
		  
		  heading=paste("Correltion of ", gene1, " with ", gene2[j], sep="")
		  hwrite(heading, outPage,heading=2,br=TRUE)
		  
		  ###Do plot of probe position?
		  
		  
		  locsPic <- paste(outfile_path, "/",gene2[j], "-locations.png",sep="")
		  
		  png(locsPic,width=800,height=400)
		  
		  plotIlluminaLocation(gene2[j], annoName=annoName)
		  
		  dev.off()
		  
		  heading=paste("Positions of probes for ", gene2[j], " on the Illumina ", annoName, " chip",sep="")
		  
		  hwrite(heading, outPage,heading=2,br=TRUE)
		  hwriteImage(locsPic, outPage,br=TRUE)
		  
		  fields <- c("PROBEQUALITY", "CODINGZONE", "GENOMICLOCATION", "REPEATMASK", "SECONDMATCHES", "ENTREZID")
		  

		  probeSummary <- matrix(nrow = length(queryIDs),ncol=length(fields))
		  colnames(probeSummary) <- fields
		  rownames(probeSummary) <- queryIDs
		  
		  for(k in 1:length(queryIDs)){
		      probeSummary[k,] <- unlist(sapply(fields, function(x) mget(queryIDs[j], eval(as.name(paste("illumina", annoName, x,sep=""))))))
		  }
		  
		  ###Select best probe by IQR if requested?
		  
		  heading=paste("Summary of annotation of probes for ", gene2[j], " on the Illumina ", annoName, " chip",sep="")
		  
		  hwrite(heading, outPage,br=TRUE)
		  hwrite(probeSummary, outPage)
		  
		  
		  
		  allIDs <- c(gene1IDs, queryIDs)
		  symbols <- c(rep(gene1,length(gene1IDs)), rep(gene2[j], length(queryIDs)))
		  
		  names(symbols) <- allIDs
	
		  eMat <- getExpressionForIDs(dbcon, queryIDs = allIDs)


		  corMat <- cor(t(cast(eMat, ProbeID~ArrayID)))
		  corMat <- corMat[allIDs,allIDs]
	
		  colMat <- matrix(nrow=length(gene1IDs)+length(queryIDs),ncol=length(gene1IDs)+length(queryIDs), "#ccffdd")
		  colMat[1:length(gene1IDs),1:length(gene1IDs)] <- "#ffffaa"
		  colMat[(length(gene1IDs)+1):nrow(colMat),(length(gene1IDs)+1):nrow(colMat)] <- "#ffffaa"
		  
		  

		  
		  hwrite("Summary of correlation",page=outPage,heading=2)
		  
		  hwrite(corMat, outPage, br=TRUE, bgcolor=colMat)
		  
		  
		  
		  hwrite("Intensity Summary",page=outPage,heading=2)
	  
		  pngfile <- paste(gene2[j], "-comparison.png",sep="")
		  eMat <- data.frame(eMat, Symbol = symbols[eMat$ProbeID])	
		  plot <- ggplot(eMat, aes(x = Symbol, y=Expression,fill=ProbeID)) + geom_boxplot() + coord_flip()
		  
		  ggsave(plot, filename=paste(outfile_path, pngfile,sep="/"),width=6,height=6,dpi=100)
		  hwriteImage(pngfile, outPage,br=TRUE)

		  
	  
		  for(id1 in gene1IDs){
		  
		  heading=paste("Correlations of ", id1, " with  ", gene2[j],sep="")
		  
		  hwrite(heading, outPage,heading=2,br=TRUE,name=id1)

		  
		    for(id2 in queryIDs){
		    
		    combMat <- attachCovarsToExpression(dbcon, queryIDs = id1)
		    exp2 <- getExpressionForIDs(dbcon, queryIDs=id2)
		  
		    
		    factorcol <- which(colnames(combMat) == factor)
		  
		    combMat <- data.frame(combMat, Gene2 = exp2$Expression)
		    
		  
		  
		    if(any(is.na(combMat[,factorcol]))){
		      combMat2 <- combMat[-which(is.na(combMat[,factorcol])),]	
		    }
		    else combMat2 <- combMat
		  
		    pngfile1 <- paste(plotCount, "-all.png",sep="")
	  
		    colnames(combMat2)[factorcol] <- "FactorToPlot"
	 
		    myplot <- ggplot(combMat2, aes(x = Expression, y = Gene2,col=FactorToPlot)) + geom_point()  +xlab(paste(gene1, id1,sep=":")) + ylab(paste(gene2[j], id2,sep=":"))
	  
		  
		    ggsave(myplot, filename=paste(outfile_path, pngfile1,sep="/"),width=6,height=3,dpi=100)
		    hwriteImage(pngfile1, outPage)
		
		    
		    pngfile2 <- paste(plotCount, "-groups.png",sep="")
		    myplot2 <- ggplot(combMat2, aes(x = Expression, y = Gene2)) + geom_point() + geom_smooth() + facet_wrap(~FactorToPlot)+xlab(paste(gene1, id1,sep=":")) + ylab(paste(gene2[j], id2,sep=":"))

		    ggsave(myplot2, filename=paste(outfile_path, pngfile2,sep="/"),width=6,height=3,dpi=100)
		    
		    
		    hwriteImage(pngfile2, outPage,br=TRUE)
		  
		    plotCount <- plotCount + 1

		  }
		  
		  }
		  
		  
	  }	

	}
	


	closePage(outPage)	


}	

}
