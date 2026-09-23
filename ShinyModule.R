library("shiny")
library("move2")

# to display messages to the user in the log file of the App in MoveApps
# one can use the function from the src/common/logger.R file:
# logger.fatal(), logger.error(), logger.warn(), logger.info(), logger.debug(), logger.trace()

shinyModuleUserInterface <- function(id, label) {
  # all IDs of UI functions need to be wrapped in ns()
  ns <- NS(id)

  tagList(
    tags$head(tags$style(HTML(paste0(
      # mandatory attributes are shown as greyed-out, disabled checkboxes
      "#", ns("attributeColumns"), " .ra-mandatory { color: #999; }",
      "#", ns("attributeColumns"), " .ra-mandatory input { cursor: not-allowed; }",
      # long attribute lists stay usable: the list scrolls, the column heading
      # and the select/unselect all links stay in place
      "#", ns("attributeColumns"), " .ra-attribute-list {",
      "  max-height: 60vh; overflow-y: auto;",
      "  border: 1px solid #ddd; border-radius: 4px; padding: 0.3em 0.8em; }",
      ".ra-hint { color: #31708f; background: #d9edf7;",
      "  border: 1px solid #bce8f1; border-radius: 4px; padding: 0.6em 0.8em; }"
    )))),
    titlePanel("Remove Attributes"),
    p("Untick the attributes that shall be removed from the data. Attributes that are greyed out are",
      "mandatory for a move2 object (timestamp, track ID and geometry) and cannot be removed.",
      "Click", strong("Apply"), "to remove the unticked attributes from the output data."),
    p(class = "ra-hint",
      "To keep the selection for future runs of the workflow, click", strong("Apply"),
      "first and then", strong("Store settings"), "(top right). Settings that are stored before",
      strong("Apply"), "has been clicked leave the data unchanged in automatic workflow runs."),
    actionButton(inputId = ns("apply"), label = "Apply", class = "btn-primary"),
    tags$div(style = "margin: 1em 0;", textOutput(ns("status"))),
    uiOutput(ns("attributeColumns"))
  )
}

# The parameter "data" is reserved for the data object passed on from the previous app
shinyModule <- function(input, output, session, data) {
  # all IDs of UI functions need to be wrapped in ns()
  ns <- session$ns

  ## --- attribute names ------------------------------------------------------
  timeCol <- mt_time_column(data)
  trackIdCol <- mt_track_id_column(data)
  geomCol <- attr(data, "sf_column")
  mandatoryEvent <- c(timeCol, trackIdCol, geomCol)
  mandatoryTrack <- trackIdCol

  eventAttrs <- setdiff(names(data), mandatoryEvent)
  trackAttrs <- setdiff(names(mt_track_data(data)), mandatoryTrack)

  # attributes to be removed, as chosen by the user and applied with "Apply"
  # (also filled from the stored settings when the App is restarted)
  removedEvent <- reactiveVal(character(0))
  removedTrack <- reactiveVal(character(0))

  ## --- UI: two columns with checkboxes --------------------------------------
  mandatoryCheckbox <- function(attr) {
    tags$div(
      class = "checkbox ra-mandatory",
      tags$label(tags$input(type = "checkbox", checked = "checked", disabled = "disabled"),
                 tags$span(attr, " (mandatory)"))
    )
  }

  attributeColumn <- function(title, inputId, allId, noneId, mandatory, attrs) {
    column(
      width = 6,
      h4(title),
      tags$div(
        style = "margin-bottom: 0.5em;",
        actionLink(inputId = ns(allId), label = "Select all"), " | ",
        actionLink(inputId = ns(noneId), label = "Unselect all")
      ),
      tags$div(
        class = "ra-attribute-list",
        tags$div(class = "shiny-options-group", lapply(mandatory, mandatoryCheckbox)),
        if (length(attrs) > 0) {
          # all attributes are selected by default; when stored settings are
          # restored, shiny replaces this default by the stored selection
          checkboxGroupInput(inputId = ns(inputId), label = NULL,
                             choices = attrs, selected = attrs)
        } else {
          p(em("No further attributes."))
        }
      )
    )
  }

  output$attributeColumns <- renderUI({
    fluidRow(
      attributeColumn(title = "Event attributes", inputId = "eventAttrs",
                      allId = "eventAll", noneId = "eventNone",
                      mandatory = mandatoryEvent, attrs = eventAttrs),
      attributeColumn(title = "Track attributes", inputId = "trackAttrs",
                      allId = "trackAll", noneId = "trackNone",
                      mandatory = mandatoryTrack, attrs = trackAttrs)
    )
  })

  ## --- select / unselect all -------------------------------------------------
  observeEvent(input$eventAll, {
    updateCheckboxGroupInput(session = session, inputId = "eventAttrs", selected = eventAttrs)
  })
  observeEvent(input$eventNone, {
    updateCheckboxGroupInput(session = session, inputId = "eventAttrs", selected = character(0))
  })
  observeEvent(input$trackAll, {
    updateCheckboxGroupInput(session = session, inputId = "trackAttrs", selected = trackAttrs)
  })
  observeEvent(input$trackNone, {
    updateCheckboxGroupInput(session = session, inputId = "trackAttrs", selected = character(0))
  })

  ## --- apply -----------------------------------------------------------------
  # unticked checkboxes give NULL, not character(0)
  selectedEvent <- reactive(if (is.null(input$eventAttrs)) character(0) else input$eventAttrs)
  selectedTrack <- reactive(if (is.null(input$trackAttrs)) character(0) else input$trackAttrs)

  applyRemoval <- function(selEvent, selTrack) {
    removedEvent(setdiff(eventAttrs, selEvent))
    removedTrack(setdiff(trackAttrs, selTrack))
    logger.info(paste0("Removing ", length(removedEvent()), " event attribute(s): ",
                       paste(removedEvent(), collapse = ", ")))
    logger.info(paste0("Removing ", length(removedTrack()), " track attribute(s): ",
                       paste(removedTrack(), collapse = ", ")))
  }

  # Click count of "Apply" as restored from the stored settings. It is reported
  # by the browser like a click, but at that moment the values of the checkboxes
  # have not arrived yet (an empty checkbox group cannot be told apart from one
  # with nothing ticked), which would remove every attribute. The removal for a
  # restored click is done by onRestore(), which runs before this observer
  # because the bookmark observers of shiny are created before this module.
  restoredApplyValue <- NULL

  observeEvent(input$apply, {
    if (identical(as.integer(input$apply), as.integer(restoredApplyValue))) {
      return()
    }
    applyRemoval(selectedEvent(), selectedTrack())
  })

  current <- reactive({
    result <- data[, setdiff(names(data), removedEvent())]
    trackData <- mt_track_data(data)
    trackData <- trackData[, setdiff(names(trackData), removedTrack()), drop = FALSE]
    mt_set_track_data(x = result, data = trackData)
  })

  output$status <- renderText({
    paste0("Output data: ", length(removedEvent()), " of ", length(eventAttrs),
           " event attribute(s) and ", length(removedTrack()), " of ", length(trackAttrs),
           " track attribute(s) removed.")
  })

  ## --- stored settings (bookmark) --------------------------------------------
  # "Store settings" bookmarks the checkbox inputs (the selected attributes) and
  # the click count of "Apply", so that it is also stored whether the removal was
  # applied. The select/unselect all links are excluded, they are not settings.
  setBookmarkExclude(c("eventAll", "eventNone", "trackAll", "trackNone"))
  onRestore(function(state) {
    restoredApplyValue <<- state$input$apply
    if (isTRUE(state$input$apply > 0)) {
      # "Apply" had been clicked when the settings were stored, so execute it
      # right away: automated workflow runs produce the output without any click
      logger.info("Restored stored settings, applying the stored selection")
      applyRemoval(state$input$eventAttrs, state$input$trackAttrs)
    } else {
      logger.info("Restored stored settings, but 'Apply' had not been clicked: data are passed on unchanged")
    }
  })

  # data must be returned. Either the unmodified input data, or the modified data by the app
  return(reactive({ current() }))
}
