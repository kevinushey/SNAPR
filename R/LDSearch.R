#' Search for SNPs in LD with a set of SNPs
#' 
#' This function queries SNAP for SNPs in high linkage disequilibrium with
#' a set of SNPs.
#' 
#' @param SNPs A vector of SNPs (rs numbers).
#' @param dataset The dataset to query. Must be one of: \itemize{
#'   \item{\code{rel21: }}{HapMap Release 21}
#'   \item{\code{rel22: }}{HapMap Release 22}
#'   \item{\code{hapmap3r2: }}{HapMap 3 (release 2)}
#'   \item{\code{onekgpilot: }}{1000 Genomes Pilot 1}
#'   }
#' @param panel The panel to use from the queried data set. 
#' Must be one of: \itemize{
#'  \item{\code{CEU}}
#'  \item{\code{YRI}}
#'  \item{\code{JPT+CHB}}
#'  }
#' @param RSquaredLimit The R Squared limit to specify as a filter for returned
#' SNPs; that is, only SNP pairs with R-squared greater than \code{RSquaredLimit}
#' will be returned.
#' @param distanceLimit The distance (in kilobases) upstream and downstream
#' to search for SNPs in LD with each set of SNPs.
#' @return A list of data.frames, one for each SNP queried, containing
#' information about the SNPs found to be in LD with that SNP.
#' @export
LDSearch <- function( SNPs,
                      dataset="onekgpilot",
                      panel="CEU",
                      RSquaredLimit=0.6,
                      distanceLimit=10 ) {
  
  require( RCurl )
  require( NCBI2R )
  
  distanceLimit_bp <- distanceLimit * 1E3
  
  query_start <- "http://www.broadinstitute.org/mpg/snap/ldsearch.php?"
  SNP_query <- paste( sep="", "snpList=", paste(SNPs, collapse=",") )
  dataset_query <- paste( sep="", "hapMapRelease=", dataset )
  panel_query <- paste( sep="", "hapMapPanel=", panel )
  RSquaredLimit_query <- paste( sep="", "RSquaredLimit=", RSquaredLimit )
  distanceLimit_query <- paste( sep="", "distanceLimit=", distanceLimit_bp )
  downloadType_query <- paste( sep="", "downloadType=file" )
  columnList_query <- paste( sep="", "columnList[]=DP,GA,MAF")
  includeQuerySNP_query <- "includeQuerySnp=on"
  submit_query <- paste( sep="", "submit=search" )  
  
  query_end <- paste( sep="&",
                      SNP_query,
                      dataset_query,
                      panel_query,
                      RSquaredLimit_query,
                      distanceLimit_query,
                      downloadType_query,
                      columnList_query,
                      includeQuerySNP_query,
                      submit_query )
  
  query <- paste( sep="", query_start, query_end )
  
  dat <- getURL( query )
  
  ## search through for missing SNPs and remove them from output
  tmp <- unlist( strsplit( dat, "\r\n", fixed=TRUE ) )
  warning_SNPs <- grep( "WARNING", tmp, value=TRUE )
  for( line in warning_SNPs ) {
    cat( line, "\n" )
  }
  tmp <- tmp[ -c( grep( "WARNING", tmp ) ) ]
  
  out <- SNAPR:::str_split( tmp, sep="\t", fixed=TRUE )
  names( out ) <- unlist( unclass( out[1,] ) )
  out <- out[2:nrow(out),]
  
  out_split <- split(out, out$SNP)
  for( i in 1:length(out_split) ) {
    rownames( out_split[[i]] ) <- 1:nrow( out_split[[i]] )
  }
  
  ## query NCBI for additional SNP information
  SNP_info <- vector("list", length(out_split))
  for( i in 1:length(out_split) ) {
    SNP_info[[i]] <- NCBI2R::GetSNPInfo( out_split[[i]]$Proxy )
    out_split[[i]] <- merge( out_split[[i]], SNP_info[[i]], 
                             by.x="Proxy", by.y="marker",
                             all.x=TRUE )
    Sys.sleep(3)
    out_split[[i]]$Distance[ out_split[[i]]$Distance == 0 ] <- NA
    out_split[[i]]$Distance <- 
      rep( out_split[[i]]$chrpos[[1]], nrow(out_split[[i]]) ) - out_split[[i]]$chrpos
    out_split[[i]] <- out_split[[i]][ 
      order( out_split[[i]]$RSquared, decreasing=TRUE ), 
      ]
  }
  
  return( out_split )
  
}