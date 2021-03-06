% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/segVPR.R
\name{seg.VPR}
\alias{seg.VPR}
\title{Segmented Vegetation Climate Relationship}
\usage{
seg.VPR(anu.VI, acu.RF, VI.index, breakpoint, rf.b4, rf.af, acu.TM = NULL,
  tm.b4 = NULL, tm.af = NULL, sig = 0.05)
}
\arguments{
\item{anu.VI}{The annual (Growing season) max VI. Must be a object of class \code{'ts'} without NA's.
if anu.VI=FALSE, it will be calculated from the CTSR.VI using \code{\link{AnMaxVI}}.}

\item{acu.RF}{The optimal accumulated rainfall for anu.VI. Must be a object of class \code{'ts'} without
NA's and be of equal length and temporal range to anu.VI. if anu.RF=FALSE, it will be
calculated from ACP.table usingthe \code{\link{AnnualClim.Cal}}}

\item{VI.index}{the index of the CTSR.VI ts that the anu.VI values occur at. Must be the same length
as anu.VI. NOTE. R indexs from 1 rather than 0.
if VI.index=FALSE, it will be calculated from the CTSR.VI using \code{\link{AnMaxVI}}.}

\item{breakpoint}{The index of the most significant breakpoint as determined using \code{\link{CHOW}}.}

\item{rf.b4}{If a breakpoint in the VPR is detected this is the optimial accumulated rainfall before
the breakpoint. must be the same length as the anu.VI. If ACP.table is provided it will
be generated using \code{\link{AnnualClim.Cal}}}

\item{rf.af}{If a breakpoint in the VPR is detected this is the optimial accumulated rainfall after
the breakpoint. must be the same length as the anu.VI. If ACP.table is provided it will
be generated using \code{\link{AnnualClim.Cal}}}

\item{acu.TM}{The optimal accumulated rainfall for anu.TM. Must be a object of class \code{'ts'} without
NA's and be of equal length and temporal range to anu.TM. if anu.TM=FALSE, it will be
calculated from ACT.table usingthe \code{\link{AnnualClim.Cal}}}

\item{tm.b4}{If a breakpoint in the VCR is detected this is the optimial accumulated temperature before
the breakpoint. It must be the same length as the anu.VI. If ACT.table is provided it will
be generated using \code{\link{AnnualClim.Cal}}}

\item{tm.af}{If a breakpoint in the VCR is detected this is the optimial accumulated temperature after
the breakpoint. It must be the same length as the anu.VI. If ACT.table is provided it will
be generated using \code{\link{AnnualClim.Cal}}}

\item{sig}{Significance of all the functions. defualt sig=0.05}
}
\value{
a list of class TSSRESTREND.
       See \code{\link{TSSRESTREND}} for details. Note. if called seperatly from TSSRESTREND,
       this list will be incomplete.
}
\description{
For a ts with a significant breakpoints in the the VPR/VCR. This function takes annual VI max,
the optimal accumulated precipitation (& temperature) before and after the breakpoint, then
caculates the Standard Variance of the climate cariables.Theen an OLS is performed with a dummy
variable to reperesent the breakpoint (0 before the breakpoint and 1 after it)..
}
\examples{
brkp <- as.integer(24) #calculated using th CHOW (DONTRUN) example
VPRres <- seg.VPR(segVPR$max.NDVI, segVPR$acum.RF, segVPR$index, brkp, segVPR$RFB4, segVPR$RFAF)
print(VPRres)
}
\author{
Arden Burrell, arden.burrell@unsw.edu.au
}
