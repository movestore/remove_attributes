# Remove Attributes

MoveApps

Github repository: github.com/movestore/remove_attributes

## Description
Select which attributes of the event data and of the track data to keep, and remove all others from the data set. The selection is applied and stored by clicking `Store settings`, so that it is also applied in automatic Workflow runs.

## Documentation
The App shows all attributes that are contained in the input data and lets the User choose which of them to keep. Attributes that are not needed for the subsequent Apps of a Workflow can thereby be removed, which makes the data set smaller and the overview of the attributes easier.

`Event attributes` lists the columns of the event (location) data, `Track attributes` lists the columns of the track data.

The attributes that are mandatory for the data to still be useful are listed greyed out at the top of each column and cannot be unticked: the timestamp column, the geometry column, and the track ID column.

Clicking `Store settings` removes all unticked attributes from the event data and from the track data, and stores the selection at the same time. The reduced data set is passed on to the next App immediately, the Workflow does not have to be run again. As long as `Store settings` has not been clicked, the input data are passed on unchanged.

In the following runs of the Workflow the stored selection is restored and applied automatically, so that an automatic Workflow run produces the reduced data set without the User having to open the user interface.


### Application scope
#### Generality of App usability
This App was developed for any taxonomic group.

#### Required data properties
The App should work for any kind of (location) data. 

### Input type
`move2::move2_loc`

### Output type
`move2::move2_loc`

### Artefacts
None.

### Settings
The settings can be adjusted in the user interface of the App:

`Event attributes` (`eventAttrs`): checkboxes of all attributes of the event data. Ticked attributes are kept, unticked attributes are removed. The timestamp, geometry and track ID columns are greyed out and always kept. Default: all attributes ticked.

`Track attributes` (`trackAttrs`): checkboxes of all attributes of the track data. Ticked attributes are kept, unticked attributes are removed. The track ID column is greyed out and always kept. Default: all attributes ticked.

`Select all` / `Unselect all` (`eventAll`/`eventNone` and `trackAll`/`trackNone`): tick or untick all attributes of the respective column at once.

`Store settings`: removes the unticked attributes from the output data and stores the ticked attributes of both columns for the following runs of the Workflow. 

### Changes in output data
The App removes from the event data and from the track data all attributes that are not ticked.

### Errors and null handling
**Setting `Store settings`:** If `Store settings` is not clicked, no attribute is removed and the input data are passed on unchanged, also if attributes have been unticked. As the ticked attributes are stored, attributes that are not present in the data at the time the settings were stored are removed in later runs, e.g. when the Workflow is run on a study with additional attributes. To keep such new attributes, open the App, tick them and store the settings again.

**Common error:** If a subsequent App of the Workflow stops with a message about a missing column, an attribute was removed that this App requires. Open the user interface, tick the attribute again and click `Store settings`.

### Technical details
- The App is based on `move2`. The mandatory columns are identified with `move2::mt_time_column()` and `move2::mt_track_id_column()`; the geometry column is taken from the `sf_column` attribute, as neither `move2` nor `sf` provides an accessor for its name.
- The attributes are removed with the `dplyr` verbs that `move2` supports: `dplyr::select()` for the event data, which keeps the `move2` object with its time column, geometry and track data intact, and `move2::select_track_data()` for the track data, which keeps the track ID column in any case.
- The data are processed as a whole, not per track, and the attribute values, the coordinate reference system, the units and the time zone of the input data are not touched.
- The selection is stored with the Shiny bookmarking mechanism of MoveApps (`Store settings`). Stored are the ticked attributes of both checkbox groups. The removal is executed in the `shiny::onBookmark()` hook, i.e. when the settings are stored, and in `shiny::onRestore()`, i.e. when a stored selection is restored at the start of the App. As the SDK writes the output of the App whenever the returned reactive changes, the reduced data are passed on within the running App and not only in the next Workflow run.
- Only the names of the attributes are handled, so runtime and memory do not depend noticeably on the number of locations.

