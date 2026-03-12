#' ####################################################################### #
#' PROJECT: [BioDT CWR - ModGP] 
#' CONTENTS: 
#'  - Execution of ModGP pipeline
#'  DEPENDENCIES:
#'  - R_scripts directory containing:
#'  	- "ModGP-Outputs.R"
#'  	- "ModGP-SDM.R"
#'  	- "SHARED-APICredentials.R" 
#'  	- "SHARED-Data.R" 
#' AUTHOR: [Erik Kusch]
#' ####################################################################### #

# PREAMBLE ================================================================
set.seed(42) # making things reproducibly random
rm(list=ls())

parse_bool_arg <- function(x, default = FALSE){
	if (is.null(x) || length(x) == 0 || is.na(x)) return(default)
	x <- tolower(trimws(as.character(x)))
	if (x %in% c("1", "true", "t", "yes", "y")) return(TRUE)
	if (x %in% c("0", "false", "f", "no", "n")) return(FALSE)
	default
}

# Read species from command-line argument
args = commandArgs(trailingOnly=TRUE)
if (length(args)==0) {
	# Default species
	SPECIES <- "Lathyrus"
	T_Start <- 1985
	T_End <- 2015
	Occurrences <- 40
	Locations <- 40
	ForceGBIF <- TRUE
	ForceBV <- FALSE
	ForcePrep <- TRUE
	ForceExec <- TRUE
} else {
	SPECIES <- args[1]
	T_Start <- if (length(args) > 1) as.numeric(args[2]) else 1985
	T_End <- if (length(args) > 2) as.numeric(args[3]) else 2015
	Occurrences <- if (length(args) > 3) as.numeric(args[4]) else 40
	Locations <- if (length(args) > 4) as.numeric(args[5]) else 40
	ForceGBIF <- if (length(args) > 5) parse_bool_arg(args[6], TRUE) else TRUE
	ForceBV <- if (length(args) > 6) parse_bool_arg(args[7], FALSE) else FALSE
	ForcePrep <- if (length(args) > 7) parse_bool_arg(args[8], TRUE) else TRUE
	ForceExec <- if (length(args) > 8) parse_bool_arg(args[9], TRUE) else TRUE
}
message(sprintf(
	paste0(
		"Run parameters: SPECIES=%s; T_Start=%s; T_End=%s; Occurrences=%s; Locations=%s; ",
		"ForceGBIF=%s; ForceBV=%s; ForcePrep=%s; ForceExec=%s"
	),
	SPECIES, T_Start, T_End, Occurrences, Locations,
	ForceGBIF, ForceBV, ForcePrep, ForceExec
))

## Directories ------------------------------------------------------------
### Define directories in relation to project directory
Dir.Base <- getwd()
Dir.Scripts <- file.path(Dir.Base, "R_scripts")

source(file.path(Dir.Scripts, "ModGP-commonlines.R"))

## API Credentials --------------------------------------------------------
try(source(file.path(Dir.Scripts, "SHARED-APICredentials.R")))
if (!exists("API_User")) {
	API_User <- "none@"
}
if(as.character(options("gbif_user")) == "NULL" ){
	options(gbif_user=rstudioapi::askForPassword("my gbif username"))}
if(as.character(options("gbif_email")) == "NULL" ){
	options(gbif_email=rstudioapi::askForPassword("my registred gbif e-mail"))}
if(as.character(options("gbif_pwd")) == "NULL" ){
	options(gbif_pwd=rstudioapi::askForPassword("my gbif password"))}

if(!exists("API_Key")){ # CDS API check: if CDS API credentials have not been specified elsewhere
	API_Key <- readline(prompt = "Please enter your Climate Data Store API key number and hit ENTER.")
} # end of CDS API check

# Choose the number of parallel processes
numberOfCores <- parallel::detectCores()

RUNNING_ON_DESTINE <- !is.na(strtoi(Sys.getenv("CWR_ON_DESTINE")))
if(RUNNING_ON_DESTINE){
	numberOfCores <- 9
}

# NUMBER OF CORES
if(!exists("numberOfCores")){ # Core check: if number of cores for parallel processing has not been set yet
	numberOfCores <- as.numeric(readline(prompt = paste("How many cores do you want to allocate to these processes? Your machine has", parallel::detectCores())))
} # end of Core check
message(sprintf("numberOfCores = %d", numberOfCores))

# DATA ====================================================================
## GBIF Data --------------------------------------------------------------
message("Retrieving GBIF data")
## species of interest
Species_ls <- FUN.DownGBIF(
	species = SPECIES, # which species to pull data for
	Dir = Dir.Data.GBIF, # where to store the data output on disk
	Force = ForceGBIF, # do not overwrite already present data unless forced
	Mode = "ModGP", # query download for entire genus
	parallel = 1 # no speed gain here for parallelising on personal machine
	)

## Environmental Data -----------------------------------------------------
message("Retrieving environmental data")
BV_ras <- FUN.DownBV(T_Start = T_Start, # what year to begin climatology calculation in
										 T_End = T_End, # what year to end climatology calculation in
										 Dir = Dir.Data.Envir, # where to store the data output on disk
									 Force = ForceBV # do not overwrite already present data unless forced
										 )

## Posthoc Data -----------------------------------------------------------
message("Retrieving additional covariates")
#' For relating SDM outputs to other characteristics of interest to users
PH_nutrient <- raster("https://www.fao.org/fileadmin/user_upload/soils/docs/HWSD/Soil_Quality_data/sq1.asc")
PH_toxicity <- raster("https://www.fao.org/fileadmin/user_upload/soils/docs/HWSD/Soil_Quality_data/sq6.asc")
PH_stack <- stack(PH_nutrient, PH_toxicity)
PH_stack <- raster::resample(PH_stack, BV_ras[[1]])
PH_stack <- stack(PH_stack, BV_ras$BIO1, BV_ras$BIO12)
names(PH_stack) <- c("Nutrient", "Toxicity", "Temperature", "Soil Moisture")

## SDM Data Preparations --------------------------------------------------
message("Preparing data for SDM workflow")
SDMInput_ls <- FUN.PrepSDMData(
    occ_ls = Species_ls$occs, # list of occurrence data frames per species
    BV_ras = BV_ras, # bioclimatic rasterstack
    Dir = Dir.Data.ModGP, # where to store the data output on disk
	Force = ForcePrep, # do not overwrite already present data unless forced
    parallel = numberOfCores, # parallelised execution
	Occurrences = Occurrences,
	Locations = Locations
)

# ANALYSIS ================================================================
## SDM Execution ----------------------------------------------------------
message("Executing SDM workflows")
SDMModel_ls <- FUN.ExecSDM(
	SDMData_ls = SDMInput_ls, 
	BV_ras = BV_ras, 
	Dir = Dir.Exports.ModGP,
	Force = ForceExec,
	Drivers = PH_stack,
	parallel = numberOfCores)
