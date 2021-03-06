#' @title Update existing key file to version 2 with additional information and
#'   new features
#'
#' @description Early work with the SOM data indicated that additional details
#'   about the data sets are required. To accomodate more detail, new additions
#'   to the key file are needed. The key_update_v2 function addresses desired
#'   changes to the key files. It is critical that information already entered
#'   into key files was not lost, so the new key file features had to be added
#'   to existing key file without information loss.
#'
#' @note **key_update_v2 workflow:**
#'   1. download project key file with googledrive
#'   2. load downloaded (now xlsx) into R with openxlsx::loadWorkbook (see note)
#'   3. additions to the workbook object as needed
#'   4. prescribe validations with openxlsx::dataValidation
#'   5. fix styling as needed with openxlsx::createSytle/addStyle
#'   6. write workbook back to file with openxlsx::write.xlsx (or saveWorkbook)
#'   7. upload workbook back to project directory to be followed by a re-homog
#'
#' @note The workflow was getting hung up at step 2 in the workflow. The
#'   solution was to use the development branch of the openxlsx package (see
#'   https://github.com/awalker89/openxlsx/issues/386)
#'   devtools::install_github("awalker89/openxlsx") Rcpp package is a dependency
#'
#' @note **Key file version 2 new features include:**
#'   1. several new metadata fields in the location tab ('time_series',
#'   'gradient', 'experiments', 'control_id', 'number_treatments',
#'   'merge_align', 'key_version').
#'   2. A new 'logical' column in the Units tab to facilitate a YES, NO
#'   drop-down option for several of the new metadata fields added to the
#'   location tab.
#'   3. Revised options in the Units tab for the list of drop-down options in
#'   the treatment rows of the Profile tab.
#'   4. Add pull-down menu for units field of lit_lig in location tab.
#'   5. Clarify meanings (Var_long field) of profle tab c_tot and soc (bulk, not
#'   fraction).
#'   6. Duplicate var values in the Location and Profile tabs are renamed with
#'   unique names.
#'
#' @note Though specific to version 2 features, this workflow could be modified
#'   to implement new features for future versions.
#'
#' @note This workflow defaults to being run on Aurora with default file paths
#'   set to that environment. These paths can be altered for the function to
#'   work outside of the Aurora environemnt, but the lter-som group should not
#'   do this as we need to document all changes, and a log file must exist.
#'
#' @note **To establish or reset a keyfile update log:**
#' ```
#'   create template for logging details of key file upversions (caution: this code
#'   will overwrite an existing log)
#'
#'   keyFileUpdateLogPath <- '/home/shares/lter-som/key_file_update_log.csv'
#'
#'   tibble(
#'     keyFileName = as.character(NA),
#'     keyFileDirectory = as.character(NA),
#'     timestamp = as.POSIXct(NA)
#'   ) %>%
#'   write_csv(path = keyFileUpdateLogPath, append = FALSE)
#'
#'  ```
#'
#' @param sheetName name of or https path to key file in Google Drive to update
#'   with version 2 changes
#' @param keyFileDownloadPath a intermediary directory to where the key file
#'   from Google Drive may be downloaded for importing into the R environment
#' @param keyFileArchivePath directory to where csv versions of the location and
#'   profile tabs of the sheet to be updated will be archived
#' @param keyFileUploadPath a intermediary directory to where the new key
#'   workbook from the R environment can be saved for eventual upload to Google
#'   Drive
#' @param keyFileUpdateLogPath log file that catalogs the occurence of a
#'   succesful update of a key file. This file must exist in advance of running
#'   the update utility
#'
#' @import googledrive
#' @import openxlsx
#' @import tools
#' @import purrr
#' @import readr
#' @import dplyr
#' @import tibble
#'
#' @return key_update_v2 actions and output include: (1) csv versions of the
#'   source key file location and profie tabs are written to a specified
#'   directory; (2) a new key file is created with desired version 2
#'   modifications; if successful, the key file update action is written to an
#'   identified key file update log.
#'
#' @examples
#' \dontrun{
#'
#'  If running on Aurora, the only relevant parameter is the name of the key
#'  file to update.
#'
#'  key_update_v2('621_Key_Key_test')
#'
#'  However, if not running on Aurora, all directory-related parameters must be
#'  passed (the path to a key file log is optional).
#'
#'  key_update_v2(sheetName = 'cap.557.Key_Key_master',
#'                keyFileDownloadPath = '~/Desktop/somdev/key_file_download/',
#'                keyFileArchivePath = '~/Desktop/somdev/key_file_archive/',
#'                keyFileUploadPath = '~/Desktop/somdev/key_file_upload/')
#'
#'  Example with path to keyFileUpdateLog - the log must exist at the specified
#'  location.
#'
#'  key_update_v2(sheetName = 'cap.557.Key_Key_master',
#'                keyFileDownloadPath = '~/Desktop/somdev/key_file_download/',
#'                keyFileArchivePath = '~/Desktop/somdev/key_file_archive/',
#'                keyFileUploadPath = '~/Desktop/somdev/key_file_upload/',
#'                keyFileUpdateLogPath = '~/Desktop/keyUpdateLogFile.csv' )
#'
#' }
#'
#' @export

key_update_v2 <- function(sheetName,
                          keyFileDownloadPath = '/home/shares/lter-som/key_file_download/',
                          keyFileArchivePath = '/home/shares/lter-som/key_file_archive/',
                          keyFileUploadPath = '/home/shares/lter-som/key_file_upload/',
                          keyFileUpdateLogPath = '/home/shares/lter-som/key_file_update_log.csv') {


# identify sheetName v downloadName ---------------------------------------

  # R <--> Google interaction is sometimes thwarted by error detailed below.
  # Passing the URL to the key file instead of the name circumvents this error.

  # Error in add_id_path(nodes, root_id = root_id, leaf = leaf) :
  #   !anyDuplicated(nodes$id) is not TRUE`

  if (grepl("https://", sheetName)) {

    downloadName <- sheetName
    sheetName <- drive_get(sheetName)$name

  } else {

    downloadName <- sheetName

  }

  # access Google Drive sheet -----------------------------------------------

  # keyFileDownloadPath is a intermediary directory to where the key file from
  # Google Drive may be downloaded for importing into the R environment

  # keyFileDownloadPath <- '/home/shares/lter-som/key_file_download/'

  drive_download(file = downloadName,
                 path = paste0(keyFileDownloadPath, sheetName, '.xlsx'),
                 overwrite = TRUE)


  # openxlsx workbook and access sheets -------------------------------------

  # currently set to a local directory but this should eventually direct to the
  # lter-som directory on Aurora

  # load downloaded key file as a openxlsx workbook
  keyfileWorkbook <- loadWorkbook(file = paste0(keyFileDownloadPath, sheetName, '.xlsx'))

  # import location tab sheet
  sheetLocation <- read.xlsx(xlsxFile = keyfileWorkbook,
                             sheet = 'Location_data')

  # before proceeding, check for key file version 2 features and stop if they are
  # present
  key_v2_location_additions <- c('time_series',
                                 'gradient',
                                 'experiments',
                                 'control_id',
                                 'number_treatments',
                                 'key_version')

  if(all(key_v2_location_additions %in% sheetLocation$var)) {

    stop("the key file in this data set seems to already be at or above version 2")

  }

  # import profile tab sheet
  sheetProfile <- read.xlsx(xlsxFile = keyfileWorkbook,
                            sheet = 'Profile_data (Key-Key)')


  # DEV only feature: import profile tab sheet - not needed until later imported
  # at this point for dev only
  sheetUnits <- read.xlsx(xlsxFile = keyfileWorkbook,
                          sheet = 'Units')


  # write location and profile sheets to file for archiving -----------------

  # keyFileArchivePath <- '/home/shares/lter-som/key_file_archive/'

  write_csv(x = sheetLocation,
            path = paste0(keyFileArchivePath, sheetName, "_location.csv"),
            append = FALSE)
  write_csv(x = sheetProfile,
            path = paste0(keyFileArchivePath, sheetName, "_profile.csv"),
            append = FALSE)


  # add new drop down options to units sheet --------------------------------

  # revised treatment level options
  revisedTreatmentOptions <- c(
    'nutrients',
    'litter_manip',
    'warming',
    'precip',
    'fire',
    'forest_harvest',
    'ag_harvest',
    'times-series',
    'tillage',
    'CO2',
    'other (add notes)')

  writeData(wb = keyfileWorkbook,
            sheet = 'Units',
            x = revisedTreatmentOptions,
            startCol = 2,
            startRow = 2)

  # logical for new location metadata

  # append logical column to end of Units sheet
  numColsModifiedUnits <- ncol(read.xlsx(xlsxFile = keyfileWorkbook,
                                         sheet = 'Units'))

  newLogical <- tibble(
    logical = c('YES', 'NO')
  )

  writeData(wb = keyfileWorkbook,
            sheet = 'Units',
            x = newLogical,
            startCol = numColsModifiedUnits + 1,
            startRow = 1,
            colNames = TRUE)


  # new location sheet metadata ---------------------------------------------

  # set keyVersion to 2
  if (sheetLocation %>% filter(var == "key_version") %>% nrow() == 0) {

    keyVersion <- 2

  }

  # get max row of location sheet
  locationMaxRow <- as.integer(nrow(sheetLocation))

  # build tibble of new metadata to add to location tab
  newLocationMetadata <- tibble(
    Value = c(NA, NA, NA, NA, NA, NA, keyVersion),
    Unit = c(NA, NA, NA, NA, NA, NA, NA),
    Var_long = c('includes time-series data',
                 'is a gradient study',
                 'includes experimental manipulations',
                 'control samples identifier',
                 'number of treatments',
                 'merging datafiles required? please add details to alignment notes',
                 'key file version (do not edit)'),
    var = c('time_series',
            'gradient',
            'experiments',
            'control_id',
            'number_treatments',
            'merge_align',
            'key_version'),
    Level = c('location',
              'location',
              'location',
              'location',
              'location',
              'location',
              'location')
  )

  # add tibble of new metadata to location tab; note `startRow = locationMaxRow +
  # 2` is to account for the next row and the header row, which R does not
  # recognize as a data row
  writeData(wb = keyfileWorkbook,
            sheet = 'Location_data',
            x = newLocationMetadata,
            startCol = 1,
            startRow = locationMaxRow + 2,
            colNames = FALSE)


  # new profile sheet validations -------------------------------------------

  # key file units sheet can be different so we must reference columns by name

  # helper function to make a spreadsheet-style vector of letters
  letterwrap <- function(n, depth = 1) {
    args <- lapply(1:depth, FUN = function(x) return(LETTERS))
    x <- do.call(expand.grid, args = list(args, stringsAsFactors = F))
    x <- x[, rev(names(x)), drop = F]
    x <- do.call(paste0, x)
    if (n <= length(x)) return(x[1:n])
    return(c(x, letterwrap(n - length(x), depth = depth + 1)))
  }

  # access revised sheetUnits to coordinate columns for validation
  sheetUnits <- read.xlsx(xlsxFile = keyfileWorkbook,
                          sheet = 'Units')

  # tibble of column names and corresponding column ids (e.g. D, AB)
  spreadsheetLetters <- tibble(
    column = letterwrap(length(colnames(sheetUnits))),
    columnName = colnames(sheetUnits)
  )


  # add validation to treatments

  # identify range of treatment level cells in profile sheet; add one to account
  # for header row, which is not seen as a row of data by R
  trtMinCell <- min(grep("Treatment_", sheetProfile$Var_long)) + 1
  trtMaxCell <- max(grep("Treatment_", sheetProfile$Var_long)) + 1

  # get spreadsheet id of treatment column
  treatmentColID <- spreadsheetLetters %>%
    filter(grepl('treatment', columnName)) %>%
    select(column) %>%
    pull()

  # add validation to treatment input
  dataValidation(wb = keyfileWorkbook,
                 sheet = "Profile_data (Key-Key)",
                 cols = 2,
                 rows = trtMinCell:trtMaxCell,
                 type = "list",
                 value = paste0("'Units'!$", treatmentColID, "$2:$", treatmentColID, "$12"))


  # add validation to new location tab metadata

  # access revised sheetLocation to coordinate columns for validation
  sheetLocation <- read.xlsx(xlsxFile = keyfileWorkbook,
                             sheet = 'Location_data')

  # access revised sheetUnits to coordinate columns for validation
  sheetUnits <- read.xlsx(xlsxFile = keyfileWorkbook,
                          sheet = 'Units')

  # tibble of column names and corresponding column ids (e.g. D, AB)
  spreadsheetLetters <- tibble(
    column = letterwrap(length(colnames(sheetUnits))),
    columnName = colnames(sheetUnits)
  )

  # get the column id of the new logical column in the Units sheet
  logicalColID <- spreadsheetLetters %>%
    filter(grepl('logical', columnName)) %>%
    select(column) %>%
    pull()

  # get the column id of the soil.C,.soil.N column in the Units sheet
  soilCNColID <- spreadsheetLetters %>%
    filter(grepl('soil', columnName)) %>%
    select(column) %>%
    pull()

  # add Units::logical validation to Location::time_series

  # add validation to treatment input
  dataValidation(wb = keyfileWorkbook,
                 sheet = "Location_data",
                 cols = 1,
                 rows = grep("time_series", sheetLocation$var) + 1,
                 type = "list",
                 value = paste0("'Units'!$", logicalColID, "$2:$", logicalColID, "$11"))

  # add Units::logical validation to Location::gradient
  dataValidation(wb = keyfileWorkbook,
                 sheet = "Location_data",
                 cols = 1,
                 rows = grep("gradient", sheetLocation$var) + 1,
                 type = "list",
                 value = paste0("'Units'!$", logicalColID, "$2:$", logicalColID, "$11"))

  # add Units::logical validation to Location::experiments
  dataValidation(wb = keyfileWorkbook,
                 sheet = "Location_data",
                 cols = 1,
                 rows = grep("experiments", sheetLocation$var) + 1,
                 type = "list",
                 value = paste0("'Units'!$", logicalColID, "$2:$", logicalColID, "$11"))

  # add Units::logical validation to Location::merge_align
  dataValidation(wb = keyfileWorkbook,
                 sheet = "Location_data",
                 cols = 1,
                 rows = grep("merge_align", sheetLocation$var) + 1,
                 type = "list",
                 value = paste0("'Units'!$", logicalColID, "$2:$", logicalColID, "$11"))

  # add Units::soil C, soil N#1-5 validation to Location::lit_lig
  dataValidation(wb = keyfileWorkbook,
                 sheet = "Location_data",
                 cols = 2,
                 rows = grep("lit_lig", sheetLocation$var) + 1,
                 type = "list",
                 value = paste0("'Units'!$", soilCNColID, "$2:$", soilCNColID, "$6"))


  # change c_tot & soc Var_long ---------------------------------------------

  if (!is.null(grep("Bulk Layer Total Carbon", sheetProfile$Var_long))) {

    writeData(wb = keyfileWorkbook,
              sheet = 'Profile_data (Key-Key)',
              x = 'Bulk Layer Total Carbon, not acid treated to remove inorganic C',
              startCol = 3,
              startRow = grep("Bulk Layer Total Carbon", sheetProfile$Var_long) + 1,
              colNames = TRUE)

  }

  if (!is.null(grep("Bulk Layer Organic Carbon \\(CN analyzer\\) concentration", sheetProfile$Var_long))) {

    writeData(wb = keyfileWorkbook,
              sheet = 'Profile_data (Key-Key)',
              x = 'Bulk Layer Organic Carbon (CN analyzer) concentration, inorganic C removed or not present',
              startCol = 3,
              startRow = grep("Bulk Layer Organic Carbon \\(CN analyzer\\) concentration", sheetProfile$Var_long) + 1,
              colNames = TRUE)

  }


  # edit var names such that they are unique ----

  # LOCATION tab vars

  # re-import location tab sheet
  sheetLocation <- read.xlsx(xlsxFile = keyfileWorkbook,
                             sheet = 'Location_data')

  update_duplicateNames_location <- function(varLongSearchTerm, newVarTerm) {

    # check if the search term (from list of new names Var_long) can be found in
    # all possible Var_long in sheetLocation. This check uses both a grep to
    # compare these string values and equivalence (==) as one or the other fails
    # inexpliably in some cases.
    if (length(grep(varLongSearchTerm, sheetLocation$Var_long)) > 0 | length(which(varLongSearchTerm == sheetLocation$Var_long)) > 0) {

      # use if-else flow to identify the starting row depending on whether string
      # match identified by grep or equivalence
      if (length(grep(varLongSearchTerm, sheetLocation$Var_long)) == 1) {

        start_row <- grep(varLongSearchTerm, sheetLocation$Var_long)

      } else if (length(which(varLongSearchTerm == sheetLocation$Var_long)) == 1) {

        start_row <- which(varLongSearchTerm == sheetLocation$Var_long)

      } else {

        stop("error encountered when attempting to enforce unique names in location tab")

      }

      writeData(wb = keyfileWorkbook,
                sheet = 'Location_data',
                x = newVarTerm,
                startCol = 4,
                startRow = start_row + 1,
                colNames = TRUE)

    } # close outer if

  } # close update_duplicateNames_location

  # walk through updates to location tab
  walk2(.x = newNamesLocation[['Var_long']], .y = newNamesLocation[['var_new_name']], .f = update_duplicateNames_location)

  # PROFILE tab vars

  # re-import profile tab sheet
  sheetProfile <- read.xlsx(xlsxFile = keyfileWorkbook,
                            sheet = 'Profile_data (Key-Key)')

  for (i in 1:nrow(newNamesProfile)) {

    if(!is.null(which(newNamesProfile[['Var_long']][i] == sheetProfile$Var_long & newNamesProfile[['Level']][i] == sheetProfile$Level))) {

      writeData(wb = keyfileWorkbook,
                sheet = 'Profile_data (Key-Key)',
                x = newNamesProfile[['var_new_name']][i],
                startCol = 4,
                startRow = which(newNamesProfile[['Var_long']][i] == sheetProfile$Var_long & newNamesProfile[['Level']][i] == sheetProfile$Level) + 1,
                colNames = TRUE)

    } # close if

  } # close loop

  # confirm edits to make vars unique was successful

  # re-import location tab sheet
  sheetLocation <- read.xlsx(xlsxFile = keyfileWorkbook,
                             sheet = 'Location_data')

  # re-import profile tab sheet
  sheetProfile <- read.xlsx(xlsxFile = keyfileWorkbook,
                            sheet = 'Profile_data (Key-Key)')

  numberDuplicateLocationVars <- sheetLocation %>%
    group_by(var) %>%
    count() %>%
    filter(n > 1) %>%
    nrow()

  numberDuplicateProfileVars <- sheetProfile %>%
    group_by(var) %>%
    count() %>%
    filter(n > 1) %>%
    nrow()


  if (numberDuplicateLocationVars > 0) {

    print(
      sheetLocation %>%
        group_by(var) %>%
        count() %>%
        filter(n > 1)
    )

    stop("key update failed, there are still duplicate location vars")

  }

  if (numberDuplicateProfileVars > 0) {

    print(
      sheetProfile %>%
        group_by(var) %>%
        count() %>%
        filter(n > 1)
    )

    stop("key update failed, there are still duplicate profile vars")

  }


  # fix Excel date format imposed by openxlsx -------------------------------

  # re-import location tab sheet
  sheetLocation <- read.xlsx(xlsxFile = keyfileWorkbook,
                             sheet = 'Location_data')

  if (!is.null(sheetLocation[grepl('modification_date', sheetLocation[['var']]),][['Value']])) {

    tryCatch({

      rDate <- convertToDate(sheetLocation[grepl('modification_date', sheetLocation[['var']]),][['Value']])
      rDate <- as.character(rDate)

      writeData(wb = keyfileWorkbook,
                sheet = 'Location_data',
                x = rDate,
                startCol = 1,
                startRow = which(grepl('modification_date', sheetLocation[['var']])) + 1,
                colNames = TRUE)

    },
    warning = function(cond) {

      NULL

    },
    error = function(cond) {

      NULL

    })

  }


  # fix formatting imposed by openxlsx --------------------------------------

  # create styles
  bodyStyle <- createStyle(fontSize = 10,
                           fontName = 'Arial')

  headerStyle <- createStyle(fontSize = 10,
                             fontName = 'Arial',
                             textDecoration = 'bold')


  # function to apply styles
  updateStyle <- function(uniqueSheet) {

    numRowsModified <- nrow(read.xlsx(xlsxFile = keyfileWorkbook,
                                      sheet = uniqueSheet))
    numColsModified <- ncol(read.xlsx(xlsxFile = keyfileWorkbook,
                                      sheet = uniqueSheet))

    # body style to body
    addStyle(wb = keyfileWorkbook,
             sheet = uniqueSheet,
             style = bodyStyle,
             rows = 1:numRowsModified + 1,
             cols = 1:numColsModified + 1,
             gridExpand = TRUE,
             stack = FALSE)

    # body style to first column (not sure why this is not caught above)
    addStyle(wb = keyfileWorkbook,
             sheet = uniqueSheet,
             style = bodyStyle,
             rows = 1:numRowsModified + 1,
             cols = 1,
             gridExpand = TRUE,
             stack = FALSE)

    # header style to first row
    addStyle(wb = keyfileWorkbook,
             sheet = uniqueSheet,
             style = headerStyle,
             rows = 1,
             cols = 1:numColsModified,
             gridExpand = TRUE,
             stack = FALSE)

  }

  # apply styles to all sheets
  walk(c('Location_data', 'Profile_data (Key-Key)', 'Units'), ~updateStyle(.x))


  # save modified workbook to file ------------------------------------------

  # keyFileUploadPath is a intermediary directory to where the new key
  # workbook from the R environment can be saved for eventual upload to Google
  # Drive

  # save workbook to file
  saveWorkbook(wb = keyfileWorkbook,
               file = paste0(keyFileUploadPath, sheetName, '_KEY_V2.xlsx'),
               overwrite = TRUE)


  # upload revised key file to google drive --------------------------------

  # Because of increasing incompatibilities with Google Drive, the steps to
  # (automatically) upload the new key file version 2 are disabled. The user
  # should edit the key file version 2 locally with LibreOffice then manually
  # upload it to Google Drive.

  # retrieve key file details
  # keyFileDetails <- drive_get(sheetName)

  # retrieve key file parent directory
  # keyFileParent <- keyFileDetails[["drive_resource"]][[1]][["parents"]][[1]]

  # upload to google drive
  # drive_upload(media = paste0(keyFileUploadPath, sheetName, '_KEY_V2.xlsx'),
  #              path = as_id(keyFileParent),
  #              type = "spreadsheet")


  # log upversion -----------------------------------------------------------

  # keyFileUpdateLogPath <- '/home/shares/lter-som/key_file_update_log.csv'

  if (!missing(keyFileUpdateLogPath)) {

    tibble(
      keyFileName = sheetName,
      keyFileDirectory = drive_get(as_id(keyFileParent))[['name']],
      timestamp = Sys.time()
    ) %>%
      write_csv(path = keyFileUpdateLogPath,
                append = TRUE)

  }

}
