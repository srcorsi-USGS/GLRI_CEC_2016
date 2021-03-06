library(readxl)
library(dplyr)
library(readr)

get_csv <- function(file_classes){
  
  classes <- data.frame(read_csv(file_classes))
  
  return(classes)
}

get_sites <- function(tracking, file.sites){
  
  sites <- readRDS(file.sites)
  sites$USGS.station.number[which(sites$USGS.station.number == "04157005")]  <- "04157000"
  
  tracking$SiteID[which(tracking$SiteID == "04157005")] <- "04157000"

  from_NWIS <- readNWISsite(zeroPad(unique(tracking$SiteID),padTo = 8))

  dfSites <- left_join(from_NWIS, sites, by=c("site_no"="USGS.station.number")) %>%
    rename(shortName = Site)

  return(dfSites)
}

get_neonic_data <- function(file.neonic,
                            file.MDL,
                            dfSites,
                            dfTracking){

  dfNeonic <- read.csv(file.neonic,stringsAsFactors = FALSE)
  
  dfMDL <- read.csv(file.MDL,stringsAsFactors = FALSE)
  
  #remove rows without sample information
  dfNeonic <- dfNeonic[grep("WS",dfNeonic$Sample,ignore.case = TRUE),]
  
  #Reconcile differences in site names to make them unique
  dfNeonic$Site <- sub(" at "," @ ",dfNeonic$Site)
  dfNeonic$Site[grep("Saginaw",dfNeonic$Site)] <- "Saginaw R @ Saginaw, MI" 
  dfNeonic$Site[grep("Cuyahoga",dfNeonic$Site)] <- "Cuyahoga R @ Saginaw, MI" 

  dfNeonic <- rename(dfNeonic, Imidacloprid_Surr = imidacloprid.d4..suurrogate...recovery.)
  neonics <- names(dfNeonic)[11:17]
  
  # set NA values to MDL and create remark columns with "<" and estimated values
  for(i in 1:length(neonics)){
    MDL <- dfMDL[which(dfMDL$neonic==neonics[i]),"MDL"]
    naRows <- which(is.na(dfNeonic[,neonics[i]]))
    dfNeonic[naRows,neonics[i]] <- MDL
    dfNeonic$remarkCol <- NA
    dfNeonic[naRows,"remarkCol"] <- "<"
    estRows <- which(dfNeonic[,neonics[i]] < 0)
    dfNeonic[estRows,neonics[i]] <- -dfNeonic[estRows,neonics[i]]
    dfNeonic[estRows,"remarkCol"] <- "estimated"                 
    names(dfNeonic)[dim(dfNeonic)[2]] <- paste0("R_",neonics[i])
  }
  
  ## Merge tracking data with neonic results
  dfTracking <- as.data.frame(dfTracking)
  dfNeonic$Sample <- toupper(dfNeonic$Sample)
  dfTracking$Neonics <- toupper(dfTracking$Neonics)
  
  # Hand correcting inconsistencies:
  # Same site/time, but 3751's not in tracking and 3646's not in data"
  dfNeonic$Sample[dfNeonic$Sample == "WS3751"] <- "WS3646"
  dfNeonic$Sample[dfNeonic$Sample =="WS3836"] <- "WS3838"
  dfTracking$Neonics[dfTracking$NWISRecordNumber =="1600273(DB01)"] <- "WS3928"
  dfNeonic$Sample[dfNeonic$Sample =="WS4288"] <- "WS4422"
  
  df <- dfNeonic %>%
    mutate(Date = as.Date(Date)) %>%
    left_join(select(dfTracking, -Site),
                  by = c("Sample"="Neonics")) %>%
    select(-Date.x, -Time.y, -Time.x, -Date.y) %>%
    filter(Sample.Type %in% c("9","J"))

  return(df)
}