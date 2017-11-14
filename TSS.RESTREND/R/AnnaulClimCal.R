#' @title Antecedental accumulation calculator for the annual max VI time series
#'
#' @description
#' Takes the Annual Max VI Time Series, the VI.index and tables of every possible accumulation
#' period and offset period for preciptation and Temperature (optional).  A OLS is calculated
#' \code{\link[stats]{lm}} for every combination of VI ~ rainfall.If temperature is provided
#' The formula is (VI ~ rainfall +temperature).  This Function preferences those results where
#' slope>0 (increase in rainfall causes an increase in vegetation), returning the rainfall accumulation
#' that has the highest R-squared and a positive slope. If no combinations produce a positive slope then the
#' one with the highest Rsquared is returned. .
#' TO DO: non peramtric and other variables
#' @author Arden Burrell, arden.burrell@unsw.edu.au
#' @inheritParams TSSRESTREND
#' @param Breakpoint
#'        Used when calcualting rf.bf and rf.af for ts with breakpoints in the VPR.  See \code{\link{CHOW}}
#'
#' @return \bold{summary}
#'        a Matrix containing "slope", "intercept", "p.value", "R^2.Value", "Break.Height", "Slope.Change"
#'        of the \code{\link[stats]{lm}} of VI ~ rainfall. If Breakpoint, summary covers both rf.b4 and rf.af.
#' @return \bold{acu.RF}
#'        (aka. annual.precip)The optimal accumulated rainfall for anu.VI. Mut be a object of class 'ts' and of equal length to anu.VI. It is caculated
#'        from the ACP.table by finding the acp and osp that has the largest R^2 value. \code{\link[stats]{lm}}(anu.VI ~ rainfall)
#' @return \bold{acu.TM}
#'        (aka, annual.temp) The optimal accumulated rainfall for anu.T<. Mut be a object of class 'ts' and of equal length to anu.VI. It is caculated
#'        from the ACT.table by finding the tacp and tosp that has the largest R^2 value. \code{\link[stats]{lm}}(anu.VI ~ rainfall+temperature)
#' @return \bold{rf.b4}
#'        The optimal acumulated rainfall before the Breakpoint
#' @return \bold{rf.af}
#'        The Optimally accumulated rainfall after the Breakpoint
#' @return \bold{tm.b4}
#'        The optimal acumulated temperature before the Breakpoint
#' @return \bold{tm.af}
#'        The Optimally accumulated temperature after the Breakpoint
#' @return \bold{osp}
#'        The offest period for the annual max time series rainfall
#' @return \bold{acp}
#'        The accumulation period for the annual max time series rainfall
#' @return \bold{tosp}
#'        The offest period for the annual max time series temperature
#' @return \bold{tacp}
#'        The accumulation period for the annual max time series temperature


#' @export
#'
#' @examples
#' ARC <- AnnualClim.Cal(stdRESTREND$max.NDVI, stdRESTREND$index, stdRESTRENDrfTab)
#' print(ARC)
#' \dontrun{
#'
#' #Test the complete time series for breakpoints
#' VPRBFdem <- VPR.BFAST(segVPRCTSR$cts.NDVI, segVPRCTSR$cts.precip)
#' bp<-as.numeric(VPRBFdem$bkps)
#'
#' #test the significance of the breakpoints
#' reschow <- CHOW(segVPR$max.NDVI, segVPR$acum.RF, segVPR$index, bp)
#' brkp <- as.integer(reschow$bp.summary["yr.index"])
#' ARCseg <-AnnualClim.Cal(segVPR$max.NDVI, segVPR$index, segVPRrfTab, Breakpoint = brkp)
#' print(ARCseg)
#' }
AnnualClim.Cal <- function(anu.VI, VI.index, ACP.table, ACT.table=NULL, Breakpoint = FALSE, allow.negative=FALSE, allowneg.retest=FALSE){
  # browser("The M part of this script is broken")
  #Perform the basic sanity checks
  if (class(anu.VI) != "ts")
    stop("anu.VI Not a time series object")
  if (length(VI.index) != length(anu.VI))
    stop("acu.VI and VI.index are not of the same length")

  #Get the start year and month
  yst <- start(anu.VI)[1]
  mst <- start(anu.VI)[2]

  # Function to perform the linear regressions
  linreg <- function(VI.in, ACP.N, ACT.N = NULL, simple=TRUE){
    #get the lm
    # Simple tells me which values to return
    if (sd(ACP.table[n, ])== 0){
      #if a combination of acp and osp leads to SD=0 rainfall, this will catch it
      # All values are bad. Matches the number of columns ss
      if (is.null(ACT.N)){return(c(0, -1))}else{return(0)}
      # return(c(-1, -1, 1, 0, NaN, NaN))
    }else{
      if (is.null(ACT.N)) {
        fit <- lm(VI.in ~ ACP.N)
        # if (class(fit)=="try-error"){browser()}
        R.Rval <- summary(fit)$r.square
        R.slpe <- as.numeric(coef(fit)[2])
        if (simple) {return(c(R.Rval, R.slpe))} #To speed up looping over all the pixels
        R.pval <- glance(fit)$p.value
        R.intr <- as.numeric(coef(fit)[1])
        R.Tcoef <- NA
        # pass a true value for the tempurature sig test
        t.sig <- TRUE

      }else{
        # do the multivariate regression with precip and temperature
        fit <- lm(VI.in ~ ACP.N + ACT.N)
        R.Rval <- summary(fit)$r.square
        if (simple) {return(R.Rval)}#To speed up looping over all the pixels
        R.pval <- glance(fit)$p.value
        R.intr <- as.numeric(coef(fit)[1])
        R.slpe <- as.numeric(coef(fit)[2]) #precip Coefficent
        R.Tcoef <- as.numeric(coef(fit)[3]) #Temperatur coefficent
        # test to see if temperature should be left in tegression
        t.sig <- (coef(summary(fit))["ACT.N","Pr(>|t|)"] < 0.05)

      }

      R.BH <- NaN
      R.SC <- NaN
      R.SCT <- NaN
      #Return the results
      return(structure(list(lm.sum=c(R.slpe, R.Tcoef, R.intr, R.pval, R.Rval, R.BH, R.SC, R.SCT), temp.sig=t.sig)))
    }}

  # Function to determine the optimal combination
  exporter <- function(res.mat, anu.VI, precip.m, temp.m=NULL){
    # find the line with the max R^2 in res.mat
    max.line <- which.max(res.mat[, "R^2.Value"])
    # Get that lines name
    fulname <- rownames(res.mat)[max.line]
    # call the linreg function And get the long form of the data
    if (is.null(temp.m)){
      sum.res <- linreg(anu.VI, precip.m[fulname, ], simple = FALSE)
      suma <- sum.res$lm.sum
      # Setup for below the else
      precip.nm <- fulname
      # Empty variables to make the array the correct size
      anu.ATM <- NULL
      t.osp <- NA
      t.acp <- NA
    }else{
      # namesplit the precip part
      part.nm <- strsplit(fulname, "\\:")[[1]]
      precip.nm <- part.nm[1]
      temp.nm <- part.nm[2]
      #perform the regression
      sum.res <- linreg(anu.VI, precip.m[precip.nm, ], temp.m[part.nm[2],], simple = FALSE)
      suma <- sum.res$lm.sum
      anu.ATM <- ts(anu.ACUT[temp.nm, ], start=c(yst, mst), frequency = 1)
      #get the ops and acp for temperature
      t.nmsplit <- strsplit(temp.nm, "\\-")[[1]]
      t.osp <- as.numeric(t.nmsplit[1])
      t.acp <- as.numeric(t.nmsplit[2])
    }
    # create a timeseries for both the precip and temp
    anu.ARF <- ts(anu.ACUP[precip.nm, ], start=c(yst, mst), frequency = 1)
    # get the osp and acp (precip and temperature)
    nmsplit <- strsplit(precip.nm, "\\-")[[1]]
    osp <- as.numeric(nmsplit[1])
    acp <- as.numeric(nmsplit[2])
    # Return the results
    return(structure(list(summary=suma, annual.precip = anu.ARF, annual.temp = anu.ATM, osp=osp, acp=acp,  tosp=t.osp, tacp=t.acp, tsig=sum.res$temp.sig)))
  }

  # While Truye exists to test if temperature is significant
  while(TRUE){

    # Subset the complete ACP.table using the indexs of the an mav values and get dims
    anu.ACUP <- ACP.table[, VI.index]
    #add a subset of the temp data if its present
    if (!is.null(ACT.table)) {anu.ACUT <- ACT.table[, VI.index]}
    #Get the dimensions of the data for indexing
    len <- dim(anu.ACUP)[2]
    if (is.null(ACT.table)){
      lines <- dim(ACP.table)[1]
    }else{
      #Add the climate table, This should allow for variable size tables
      lines <- dim(ACP.table)[1]*dim(ACT.table)[1]
    }
    #create a blank matrix and assign it colum headings to hold lm() results
    if (is.null(ACT.table)){
      # Build an empy array for the numbers
      m<- matrix(nrow=(lines), ncol=2)
      #Get the names of the rows and colunms
      rownames(m)<- rownames(ACP.table)
      colnames(m)<- c("R^2.Value", "slope")

    }else{
      # Build an empy array for the numbers
      m<- matrix(nrow=(lines), ncol=1)
      #Get the names of the rows and colunms
      rn.names <- NULL
      for (rnm in rownames(ACP.table)){
        rnms <- cbind(rnm, rownames(ACT.table))
        rmx <- paste(rnms[,1] , rnms[,2], sep = ":")
        rn.names <- c(rn.names, rmx)}
      #Set the row and column names
      rownames(m)<- rn.names
      colnames(m)<- c("R^2.Value")
    }
    # Duplicate the matrix if there is a breakpoint
    if (class(Breakpoint)!="logical") {p <- m}

    # browser()
    # For loops to call the linreg function and fit a LM to every combination of rainfall and vegetation
    for (n in 1:dim(ACP.table)[1]){
      # browser()
      if (is.null(ACT.table)){ #no Temperature data
        # Stack the results in the empyt matryx m
        # if there is a breakpoint do the same on the other side
        if (class(Breakpoint)!="logical"){ #means breakpoint is a number (not logical)
          #perform the regressions on either side of the breakpoint. m before and p after
          m[n, ] <- linreg(anu.VI[1:Breakpoint],  anu.ACUP[n, 1:Breakpoint])
          p[n, ] <- linreg(anu.VI[(Breakpoint+1):len], anu.ACUP[n, (Breakpoint+1):len])
        }else{
          # perform the linear regressions
          m[n, ] <- linreg(anu.VI, anu.ACUP[n, ])
        }
      }else{ # Temperature data
        for (nx in 1:dim(ACT.table)[1]){
          #Get the row name of the correct line
          rn.loop <- paste(rownames(ACP.table)[n], rownames(ACT.table)[nx], sep = ":")
          # Stack the results in the empyt matryx m
          if (class(Breakpoint)!="logical"){ #Means breakpoint is a number (not logical)
            m[rn.loop, ] <- linreg(anu.VI[1:Breakpoint], anu.ACUP[n, 1:Breakpoint], anu.ACUT[nx, 1:Breakpoint])
            p[rn.loop, ] <- linreg(anu.VI[(Breakpoint+1):len], anu.ACUP[n, (Breakpoint+1):len], anu.ACUT[nx, (Breakpoint+1):len])
          }else{
            m[rn.loop, ] <- linreg(anu.VI, anu.ACUP[n, ], anu.ACUT[nx,])
          }
        }
      }
    }


    # depending on the breakpoints and the allow.negative state do things
    if (!Breakpoint){ # No Breakpoint
      if (allow.negative){ # all values are considered
        if (is.null(ACT.table)){ # no temperature data
          results <- exporter(m, anu.VI, anu.ACUP)
          tsig <- results$tsig
          results$tsig = NULL
        }else{ # considereing temperature
          results <- exporter(m, anu.VI, anu.ACUP, anu.ACUT)
          #upll out the significance then remove it
          tsig <- results$tsig
          results$tsig = NULL
        }
        # TEST THE SIG OF TEMPERATURE
        if (tsig){
          return(results)
        }else{ # Temperature doesnt help, sending the script around again
          ACT.table=NULL
          allow.negative=allowneg.retest
        }
      }else{ #allow.negative=FALSE
        mx <- matrix(m[m[, "slope"] > 0,], ncol=2)
        colnames(mx)<- c("R^2.Value", "slope")
        rownames(mx)<- rownames(m[m[, "slope"] > 0,])
        if (dim(mx)[1] <= 2){
          warning("Insufficent positve slopes exist. Returing most significant negative slope")
          if (is.null(ACT.table)){ # no temperature data
            results <- exporter(m, anu.VI, anu.ACUP)
            #upll out the significance then remove it
            tsig <- results$tsig
            results$tsig = NULL

            browser()
          }else{stop("There shold be no tmp data here (V1)")}
          return(results)
        }else{ # only looking at positive slopes
          if (is.null(ACT.table)){ # no temperature data
            results <- exporter(m[m[, "slope"] >= 0,], anu.VI, anu.ACUP[m[, "slope"] >= 0,])
            #upll out the significance then remove it
            tsig <- results$tsig
            results$tsig = NULL
            }else{stop("There shold be no tmp data here (V2)")}
          return(results)
        }
      }
    }else{ # has a breakpoint
      if (allow.negative){ # all values are considered
        if (is.null(ACT.table)){ # no temperature data
          results.b4 <- exporter(m, anu.VI[1:Breakpoint], anu.ACUP[, 1:Breakpoint])
          results.af <- exporter(p, anu.VI[(Breakpoint+1):len], anu.ACUP[, (Breakpoint+1):len])
        }else{ # considereing temperature
          results.b4 <- exporter(m, anu.VI[1:Breakpoint], anu.ACUP[, 1:Breakpoint], anu.ACUT[, 1:Breakpoint])
          results.af <- exporter(p, anu.VI[(Breakpoint+1):len], anu.ACUP[, (Breakpoint+1):len], anu.ACUT[, (Breakpoint+1):len])
        }
      }else{ # no temperature, only condidering positive slopes
        mx <- matrix(m[m[, "slope"] > 0,], ncol=2)
        colnames(mx)<- c("R^2.Value", "slope")
        rownames(mx)<- rownames(m[m[, "slope"] > 0,])

        px <- matrix(p[p[, "slope"] > 0,], ncol=2)
        colnames(px)<- c("R^2.Value", "slope")
        rownames(px)<- rownames(p[p[, "slope"] > 0,])

        if ((dim(mx)[1] <= 2)||(dim(px)[1] <= 2)){
          warning("<2 positve slopes exist before or after the bp. Returing most significant negative slope")
          results.b4 <- exporter(m, anu.VI[1:Breakpoint], anu.ACUP[, 1:Breakpoint])
          results.af <- exporter(p, anu.VI[(Breakpoint+1):len], anu.ACUP[, (Breakpoint+1):len])
        }else{
          results.b4 <- exporter(mx, anu.VI[1:Breakpoint], anu.ACUP[, 1:Breakpoint])
          results.af <- exporter(px, anu.VI[(Breakpoint+1):len], anu.ACUP[, (Breakpoint+1):len])
        }
      }
      # remove the temperature variables
      tsig.b4 = results.b4$tsig
      tsig.af = results.af$tsig
      results.b4$tsig = NULL
      results.af$tsig = NULL
      # Test and see if temperature was a significant component
      if (!tsig.b4 && !tsig.af){
        ACT.table=NULL
        allow.negative=allowneg.retest
      }else{
         #Bind the summary together
         summ <- rbind(results.b4$summary, results.af$summary)
         return(structure(list(summary=summ, rf.b4 = results.b4$annual.precip, rf.af=results.af$annual.precip,
                               tm.b4 = results.b4$annual.temp, tm.af= results.af$annual.temp, osp.b4 = results.b4$osp,
                               acp.b4 = results.b4$acp, tosp.b4 = results.b4$tosp, tacp.b4 = results.b4$tacp,
                               osp.af = results.af$osp, acp.af = results.af$acp, tosp.af = results.af$tosp,
                               tacp.af = results.af$tacp)))
      }
    }
  }
}