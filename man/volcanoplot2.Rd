\name{volcanoplot2}
\alias{volcanoplot2}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Modified volcano plot
}
\description{
%%  ~~ A concise (1-5 lines) description of what the function does. ~~
}
\usage{
volcanoplot2(fit, coef = 1, highlight = 0, names = fit$genes$ID, xlab = "Log Fold Change", ylab = "Log Odds", pch = 16, cex = 0.35, ...)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{fit}{
%%     ~~Describe \code{fit} here~~
}
  \item{coef}{
%%     ~~Describe \code{coef} here~~
}
  \item{highlight}{
%%     ~~Describe \code{highlight} here~~
}
  \item{names}{
%%     ~~Describe \code{names} here~~
}
  \item{xlab}{
%%     ~~Describe \code{xlab} here~~
}
  \item{ylab}{
%%     ~~Describe \code{ylab} here~~
}
  \item{pch}{
%%     ~~Describe \code{pch} here~~
}
  \item{cex}{
%%     ~~Describe \code{cex} here~~
}
  \item{\dots}{
%%     ~~Describe \code{\dots} here~~
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
function (fit, coef = 1, highlight = 0, names = fit$genes$ID, 
    xlab = "Log Fold Change", ylab = "Log Odds", pch = 16, cex = 0.35, 
    ...) 
{
    if (!is(fit, "MArrayLM")) 
        stop("fit must be an MArrayLM")
    if (is.null(fit$lods)) 
        stop("No B-statistics found, perhaps eBayes() not yet run")
    x <- as.matrix(fit$coef)[, coef]
    y <- as.matrix(fit$lods)[, coef]
    smoothScatter(x, y, xlab = xlab, ylab = ylab, pch = pch, 
        cex = cex, ...)
    if (highlight > 0) {
        if (is.null(names)) 
            names <- 1:length(x)
        names <- as.character(names)
        o <- order(y, decreasing = TRUE)
        i <- o[1:highlight]
        text(x[i], y[i], labels = substring(names[i], 1, 8), 
            cex = 0.8, col = "blue")
    }
    invisible()
  }
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
