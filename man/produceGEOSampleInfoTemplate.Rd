\name{produceGEOSampleInfoTemplate}
\alias{produceGEOSampleInfoTemplate}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Produce a GEO sample template}
\description{
%%  ~~ A concise (1-5 lines) description of what the function does. ~~
}
\usage{
produceGEOSampleInfoTemplate(lumiNormalized, lib.mapping = NULL, fileName = "GEOsampleInfo.txt")
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{lumiNormalized}{
%%     ~~Describe \code{lumiNormalized} here~~
}
  \item{lib.mapping}{
%%     ~~Describe \code{lib.mapping} here~~
}
  \item{fileName}{
%%     ~~Describe \code{fileName} here~~
}
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}
\references{
%% ~put references to the literature/web site here ~
}
\author{
%%  ~~who you are~~
}
\note{
%%  ~~further notes~~
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
}
\examples{
##---- Should be DIRECTLY executable !! ----
##-- ==>  Define data, use random,
##--	or do  help(data=index)  for the standard data sets.

## The function is currently defined as
function (lumiNormalized, lib.mapping = NULL, fileName = "GEOsampleInfo.txt") 
{
    link <- "http://www.ncbi.nlm.nih.gov/projects/geo/info/soft2.html"
    templateTitle <- c("Sample_title", "Sample_channel_count", 
        "Sample_source_name_ch1", "Sample_organism_ch1", "Sample_characteristics_ch1", 
        "Sample_molecule_ch1", "Sample_extract_protocol_ch1", 
        "Sample_label_ch1", "Sample_label_protocol_ch1", "Sample_hyb_protocol", 
        "Sample_scan_protocol", "Sample_description", "Sample_data_processing", 
        "Sample_platform_id", "Sample_supplementary_file")
    if (is(lumiNormalized, "ExpressionSetIllumina")) {
        labels <- as.character(pData(lumiNormalized)[, "Sample_Name"])
        chipVersion <- annotation(lumiNormalized)
        organism <- strsplit(annotation(lumiNormalized), "v")[[1]][1]
        organism <- switch(organism, Rat = "Rattus norvegicus", 
            Human = "Homo sapiens", Mouse = "Mus musculus")
        templateContent <- c("", "1", "", organism, "", "total RNA", 
            "standard as recommended by illumina", "Cy3", "standard as recommended by illumina", 
            "standard as recommended by illumina", "standard as recommended by illumina", 
            "", "", chipVersion, "none")
    }
    else if (is(lumiNormalized, "MethyLumiM")) {
        labels <- as.character(sampleNames(lumiNormalized))
        chipVersion <- "unknown"
        organism <- "unknown"
        templateContent <- c("", "1", "", organism, "", "genomic DNA", 
            "standard as recommended by illumina", "Cy3", "standard as recommended by illumina", 
            "standard as recommended by illumina", "standard as recommended by illumina", 
            "", "", chipVersion, "none")
    }
    else if (is(lumiNormalized, "matrix") || is(lumiNormalized, 
        "ExpressionSet")) {
        if (is(lumiNormalized, "ExpressionSet")) 
            lumiNormalized <- exprs(lumiNormalized)
        labels <- colnames(lumiNormalized)
        chipVersion <- "unknown"
        organism <- "unknown"
        templateContent <- c("", "1", "", organism, "", "", "", 
            "Cy3", "", "standard as recommended by manufacturer", 
            "standard as recommended by manufacturer", "", "", 
            "", "none")
    }
    else {
        cat("The input object should be an object of LumiBatch, MethyLumiM, matrix or other ExpressionSet inherited class!\n")
    }
    preprocessMethod <- "The bead-level data were preprocessed using BASH (Cairns et al. (2008) Bioinformatics 24(24):2921-2), a function from the beadarray package (Dunning et al (2007) Bioinformatics 23(16):2183-4) in Bioconductor, and also log base 2 transformed and quantile normalised using the beadarray packagee"
    templateContent[templateTitle == "Sample_data_processing"] <- preprocessMethod
    templateContent[templateTitle == "Sample_characteristics_ch1"] <- as.character(pData(lumiNormalized)[, 
        "Sample_Group"])
    template <- templateTitle
    for (i in seq(labels)) {
        template <- rbind(template, templateContent)
    }
    template <- cbind(c("sampleID", labels), template)
    template <- cbind(c("Sample_title", as.character(pData(lumiNormalized)[, 
        "Sample_Name"])), template)
    template
    colnames(template) <- template[1, ]
    template <- template[-1, ]
    if (!is.null(fileName)) {
        cat("# For the detailed definition of the column names, please refer to ", 
            link, "\n", sep = "", file = fileName)
        write.table(template, sep = "\t", quote = FALSE, file = fileName, 
            append = TRUE, col.names = FALSE, row.names = FALSE)
    }
    else {
        return(template)
    }
  }
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
