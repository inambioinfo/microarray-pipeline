\name{plotDensity}
\alias{plotDensity}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Density plot
}
\description{
%%  ~~ A concise (1-5 lines) description of what the function does. ~~
}
\usage{
plotDensity(mat, ylab = "density", xlab = "log2 Intensity", type = "l", col = 1:6, na.rm = TRUE, ...)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{mat}{
%%     ~~Describe \code{mat} here~~
}
  \item{ylab}{
%%     ~~Describe \code{ylab} here~~
}
  \item{xlab}{
%%     ~~Describe \code{xlab} here~~
}
  \item{type}{
%%     ~~Describe \code{type} here~~
}
  \item{col}{
%%     ~~Describe \code{col} here~~
}
  \item{na.rm}{
%%     ~~Describe \code{na.rm} here~~
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
function (mat, ylab = "density", xlab = "log2 Intensity", type = "l", 
    col = 1:6, na.rm = TRUE, ...) 
{
    x.density <- apply(mat, 2, density, na.rm = na.rm)
    all.x <- do.call("cbind", lapply(x.density, function(x) x$x))
    all.y <- do.call("cbind", lapply(x.density, function(x) x$y))
    matplot(all.x, all.y, ylab = ylab, xlab = xlab, type = type, 
        col = col, ...)
    invisible(list(all.x = all.x, all.y = all.y))
  }
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ ~kwd1 }
\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
