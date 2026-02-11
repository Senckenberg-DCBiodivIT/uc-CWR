## Default flags for runtime environment
RUNNING_ON_LUMI <- FALSE
RUNNING_ON_DESTINE <- FALSE

## Packages ---------------------------------------------------------------
package_vec <- c(
	'cowplot', # grid plotting
	'ggplot2', # ggplot machinery
	'ggpmisc', # table plotting in ggplot environment
	'ggpubr', # t-test comparison in ggplot
	'gridExtra', # ggplot saving in PDF
	'parallel', # parallel runs
	'pbapply', # parallel runs with estimator bar
	'raster', # spatial data
	'remotes', # remote installation
	'rgbif', # GBIF access
	'rnaturalearth', # shapefiles
	'sdm', # SDM machinery
	'sf', # spatial data
	'sp', # spatial data
	'terra', # spatial data
	'tidyr', # gather()
	'usdm', # vifcor()
	'viridis', # colour palette
	'iterators',
	'KrigR',
	'mraster'
)


require('ggpmisc') # table plotting in ggplot environment
require('ggpubr') # t-test comparison in ggplot
require('parallel') # parallel runs
require('rgbif') # GBIF access
library('sdm')
require('dismo')
require('rJava')
require('gbm')
require('bit64')
require('rnaturalearthdata')

### NON-CRAN PACKAGES ----
# for developping always install the latest version of KrigR
renv::install("Senckenberg-DCBiodivIT/KrigR@add-alternative-data-source-DEDL")
library(KrigR)
library(mraster)

## Functionality ----------------------------------------------------------
`%nin%` <- Negate(`%in%`) # a function for negation of %in% function

#' Progress bar for data loading
saveObj <- function(object, file.name){
	outfile <- file(file.name, "wb")
	serialize(object, outfile)
	close(outfile)
}
loadObj <- function(file.name){
	library(foreach)
	filesize <- file.info(file.name)$size
	chunksize <- ceiling(filesize / 100)
	pb <- txtProgressBar(min = 0, max = 100, style=3)
	infile <- file(file.name, "rb")
	data <- foreach(it = iterators::icount(100), .combine = c) %do% {
		setTxtProgressBar(pb, it)
		readBin(infile, "raw", chunksize)
	}
	close(infile)
	close(pb)
	return(unserialize(data))
}

## Directories ------------------------------------------------------------
### Define directories in relation to project directory
Dir.Data <- file.path(Dir.Base, "Data")
Dir.Data.ModGP <- file.path(Dir.Data, "ModGP")
Dir.Data.GBIF <- file.path(Dir.Data, "GBIF")
Dir.Data.Envir <- file.path(Dir.Data, "Environment")
Dir.Exports <- file.path(Dir.Base, "Exports")
Dir.Exports.ModGP <- file.path(Dir.Exports, "ModGP")
### Create directories which aren't present yet
Dirs <- grep(ls(), pattern = "Dir.", value = TRUE)
CreateDir <- sapply(Dirs, function(x){
	x <- eval(parse(text=x))
	if(!dir.exists(x)) dir.create(x)})
rm(Dirs)

## Sourcing ---------------------------------------------------------------
source(file.path(Dir.Scripts,"SHARED-Data.R"))
source(file.path(Dir.Scripts,"ModGP-SDM.R"))
source(file.path(Dir.Scripts,"ModGP-Outputs.R"))
