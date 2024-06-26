#' @title       calcYieldgainPotential
#' @description reports yield gain potential for irrigatable area under different
#'              scenarios
#'
#' @param scenario          Non-agricultural water use and EFP scenario, separated
#'                          by "." (e.g. "on.ssp2")
#' @param lpjml             LPJmL version used
#' @param selectyears       Years for which yield gain potential is calculated
#' @param iniyear           Initialization year
#' @param climatetype       Switch between different climate scenarios or
#'                          historical baseline "GSWP3-W5E5:historical"
#' @param efrMethod         EFR method used including selected strictness of EFRs
#'                          (e.g. Smakhtin:good, VMF:fair)
#' @param accessibilityrule Strictness of accessibility restriction:
#'                          discharge that is exceeded x percent of the time on average throughout a year (Qx).
#'                          (e.g. Q75: 0.25, Q50: 0.5)
#' @param rankmethod     Rank and optimization method consisting of
#'                       Unit according to which rank is calculated:
#'                       USD_ha (USD per hectare) for relative area return, or
#'                       USD_m3 (USD per cubic meter) for relative volumetric return;
#'                       USD for absolute return (total profit);
#'                       Price aggregation:
#'                       "GLO" for global average prices, or
#'                       "ISO" for country-level prices
#'                       and boolean indicating fullpotential (TRUE, i.e. cell
#'                       receives full irrigation requirements in total area)
#'                       or reduced potential (FALSE, reduced potential of cell
#'                       receives at later stage in allocation algorithm);
#'                       separated by ":"
#' @param yieldcalib        If TRUE: LPJmL yields calibrated to FAO country yield in iniyear
#'                               Also needs specification of refYields, separated by ":".
#'                               Options: FALSE (for single cropping analyses) or
#'                                        "TRUE:actual:irrig_crop" (for multiple cropping analyses)
#'                          If FALSE: uncalibrated LPJmL yields are used
#' @param allocationrule    Rule to be applied for river basin discharge allocation
#'                          across cells of river basin ("optimization", "upstreamfirst", "equality")
#' @param gainthreshold     Threshold of yield improvement potential required
#'                          (in USD per hectare)
#' @param irrigationsystem  Irrigation system used
#'                          ("surface", "sprinkler", "drip", "initialization")
#' @param landScen          Land availability scenario consisting of two parts separated by ":":
#'                          1. available land scenario (currCropland, currIrrig, potCropland)
#'                          2. protection scenario (WDPA, or one of the scenarios available in
#'                             calcConservationPriorities, e.g., 30by20, BH, BH_IFL, PBL_HalfEarth,
#'                             or NA for no protection).
#'                          For case of no land protection select "NA" in second part of argument
#'                          or do not specify second part of the argument
#' @param cropmix           Selected cropmix (options:
#'                          "hist_irrig" for historical cropmix on currently irrigated area,
#'                          "hist_total" for historical cropmix on total cropland,
#'                          or selection of proxycrops)
#' @param multicropping     Multicropping activated (TRUE) or not (FALSE) and
#'                          Multiple Cropping Suitability mask selected
#'                          (mask can be:
#'                          "none": no mask applied (only for development purposes)
#'                          "actual:total": currently multicropped areas calculated from total harvested areas
#'                                          and total physical areas per cell from LandInG
#'                          "actual:crop" (crop-specific), "actual:irrigation" (irrigation-specific),
#'                          "actual:irrig_crop" (crop- and irrigation-specific) "total"
#'                          "potential:endogenous": potentially multicropped areas given
#'                                                  temperature and productivity limits
#'                          "potential:exogenous": potentially multicropped areas given
#'                                                 GAEZ suitability classification)
#'                          (e.g. TRUE:actual:total; TRUE:none; FALSE)
#' @param unlimited         TRUE: no water limitation to potentially irrigated area
#'                          FALSE: irrigatable area limited by water availability
#' @param transDist         Water transport distance allowed to fulfill locally
#'                          unfulfilled water demand by surrounding cell water availability
#' @param fossilGW          If TRUE: non-renewable groundwater can be used.
#'                          If FALSE: non-renewable groundwater cannot be used.
#'
#' @return magpie object in cellular resolution
#' @author Felicitas Beier
#'
#' @examples
#' \dontrun{
#' calcOutput("YieldgainPotential", aggregate = FALSE)
#' }
#'
#' @importFrom stringr str_split
#' @importFrom madrat calcOutput
#' @importFrom magclass collapseNames getCells getNames setYears dimSums new.magpie
#' @importFrom mstools toolGetMappingCoord2Country
#'
#' @export

calcYieldgainPotential <- function(scenario, selectyears, iniyear, lpjml, climatetype,
                                   efrMethod, yieldcalib, irrigationsystem,
                                   accessibilityrule, rankmethod,
                                   gainthreshold, allocationrule,
                                   transDist, fossilGW,
                                   landScen, cropmix, multicropping, unlimited) {

  thresholdtype <- paste("USD_ha",
                         unlist(strsplit(rankmethod, split = ":"))[2],
                         sep = ":")

  # Cellular yield improvement potential for all crops (in USD/ha)
  yieldGain <- calcOutput("IrrigYieldImprovementPotential",
                          selectyears = selectyears, iniyear = iniyear,
                          lpjml = lpjml, climatetype = climatetype, cropmix = NULL,
                          unit = thresholdtype, yieldcalib = yieldcalib,
                          comagyear = NULL,
                          irrigationsystem = irrigationsystem,
                          landScen = landScen,
                          multicropping = as.logical(stringr::str_split(multicropping, ":")[[1]][1]),
                          aggregate = FALSE)

  # Total area that can potentially be irrigated (in Mha)
  if (unlimited) {

    # Area that can potentially be irrigated without water limitation
    area <- calcOutput("AreaPotIrrig",
                       selectyears = selectyears, iniyear = iniyear,
                       landScen = landScen, cropmix = cropmix, comagyear = NULL,
                       aggregate = FALSE)
    croplist    <- getItems(area, dim = "crop")

    d    <- "Potentially Irrigated Area only considering land constraint"

  } else {

    # Area that can potentially be irrigated given land and water constraints
    area <- collapseNames(calcOutput("PotIrrigAreas", gainthreshold = gainthreshold,
                                     selectyears = selectyears, iniyear = iniyear,
                                     climatetype = climatetype, lpjml = lpjml,
                                     accessibilityrule = accessibilityrule, efrMethod = efrMethod,
                                     rankmethod = rankmethod, yieldcalib = yieldcalib, allocationrule = allocationrule,
                                     irrigationsystem = irrigationsystem,
                                     landScen = landScen, cropmix = cropmix,
                                     comAg = FALSE, multicropping = multicropping,
                                     transDist = transDist, fossilGW = fossilGW,
                                     aggregate = FALSE)[, , "irrigatable"][, , scenario])
    croplist <- getItems(area, dim = "crop")
    d    <- "Potentially Irrigated Area considering land and water constraints"

  }

  # Potential yield gain per cell (in mio. USD)
  x <- dimSums(yieldGain[, , croplist] * area, dim = "crop")
  u <- "mio. USD"

  out <- collapseNames(x)

  return(list(x            = out,
              weight       = NULL,
              unit         = u,
              description  = d,
              isocountries = FALSE))
}
