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
      "mandatory and cannot be removed."),
    p(class = "ra-hint",
      "Click", strong("Store settings"), "(top right) to remove the unticked attributes from the data.",
      "The selection is stored at the same time, so it is applied again in the following runs of the",
      "workflow, also in automatic ones."),
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
  # neither move2 nor sf exports an accessor for the name of the geometry
  # column, the attribute is the documented way to get it
  geomCol <- attr(data, "sf_column")
  mandatoryEvent <- c(timeCol, trackIdCol, geomCol)
  mandatoryTrack <- trackIdCol

  eventAttrs <- setdiff(names(data), mandatoryEvent)
  trackAttrs <- setdiff(names(mt_track_data(data)), mandatoryTrack)

  # attributes to be removed, as chosen by the user and applied when the
  # settings are stored (also filled from the stored settings on a restart)
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

  ## --- removal of the unticked attributes ------------------------------------
  # A checkbox group reports NULL both when nothing is ticked and before the
  # browser has reported it at all. The two are told apart by the name of the
  # input: shiny keeps it once the browser has reported the input, also when the
  # reported value is NULL. Not reported means the checkboxes still show their
  # default, which is all attributes ticked. This is the case directly after a
  # reload, e.g. the one that "Restore default settings" does.
  checkboxesReported <- function() {
    reported <- names(reactiveValuesToList(input))
    c("eventAttrs", "trackAttrs") %in% reported
  }

  selectionOf <- function(id, attrs) {
    if (!(id %in% names(reactiveValuesToList(input)))) {
      attrs
    } else if (is.null(input[[id]])) {
      character(0)
    } else {
      input[[id]]
    }
  }

  selectedEvent <- reactive(selectionOf("eventAttrs", eventAttrs))
  selectedTrack <- reactive(selectionOf("trackAttrs", trackAttrs))

  applyRemoval <- function(selEvent, selTrack) {
    removedEvent(setdiff(eventAttrs, selEvent))
    removedTrack(setdiff(trackAttrs, selTrack))
    logger.info(paste0("Removing ", length(removedEvent()), " event attribute(s): ",
                       paste(removedEvent(), collapse = ", ")))
    logger.info(paste0("Removing ", length(removedTrack()), " track attribute(s): ",
                       paste(removedTrack(), collapse = ", ")))
  }

  # dplyr::select() keeps the move2 object intact (time column, geometry and the
  # track data), move2::select_track_data() does the same for the track data and
  # keeps the track id column in any case. They are called with :: to avoid
  # attaching dplyr, which would mask base functions.
  current <- reactive({
    keptEvent <- setdiff(names(data), removedEvent())
    keptTrack <- setdiff(names(mt_track_data(data)), removedTrack())
    result <- dplyr::select(data, dplyr::all_of(keptEvent))
    select_track_data(result, dplyr::all_of(keptTrack))
  })

  output$status <- renderText({
    applied <- paste0("Output data: ", length(removedEvent()), " of ", length(eventAttrs),
                      " event attribute(s) and ", length(removedTrack()), " of ", length(trackAttrs),
                      " track attribute(s) removed.")
    selectionApplied <- setequal(removedEvent(), setdiff(eventAttrs, selectedEvent())) &&
      setequal(removedTrack(), setdiff(trackAttrs, selectedTrack()))
    if (selectionApplied || !any(checkboxesReported())) {
      # before the browser reported the checkboxes there is nothing the user
      # could have changed, so the hint would be wrong
      applied
    } else {
      paste(applied, "The current selection is not applied yet, click 'Store settings' to apply it.")
    }
  })

  ## --- stored settings ("Store settings") ------------------------------------
  # "Store settings" bookmarks the checkbox inputs, i.e. the selected attributes.
  # The select/unselect all links are excluded, they are not settings.
  setBookmarkExclude(c("eventAll", "eventNone", "trackAll", "trackNone"))

  # The App has no "Apply" button of its own: the removal is executed when the
  # settings are stored. onBookmark() is called by shiny for that click, and the
  # SDK writes the output whenever the returned reactive changes, so the reduced
  # data are passed on right away, without the workflow having to be run again.
  onBookmark(function(state) {
    isolate({
      logger.info("Settings stored, applying the selected attributes")
      applyRemoval(selectedEvent(), selectedTrack())
    })
  })

  # In the following runs of the workflow the stored selection is applied
  # directly, so that automatic runs produce the output without any interaction.
  onRestore(function(state) {
    stored <- names(state$input)
    if (!any(c("eventAttrs", "trackAttrs") %in% stored)) {
      # no selection to restore: after "Restore default settings", or when the
      # SDK dropped stored settings that do not fit the current input data. The
      # App then shows its default, all attributes ticked, and removes nothing.
      logger.warn("No stored attribute selection was restored, all attributes are kept")
      applyRemoval(eventAttrs, trackAttrs)
      return()
    }
    logger.info("Restored stored settings, applying the stored selection")
    applyRemoval(if ("eventAttrs" %in% stored) state$input$eventAttrs else eventAttrs,
                 if ("trackAttrs" %in% stored) state$input$trackAttrs else trackAttrs)
  })

  # data must be returned. Either the unmodified input data, or the modified data by the app
  return(reactive({ current() }))
}
