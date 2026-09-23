# Remove Attributes

MoveApps

Github repository: github.com/movestore/remove_attributes

## Description
Select which attributes of the event data and of the track data to keep, and remove all others from the data set. The selection can be stored, so that it is also applied in automatic Workflow runs.

## Documentation
The App shows all attributes that are contained in the input data and lets the User choose which of them to keep. Attributes that are not needed for the subsequent Apps of a Workflow can thereby be removed, which makes the data set smaller and the overview of the attributes easier.

`Event attributes` lists the columns of the event (location) data, `Track attributes` lists the columns of the track data.

The attributes that are mandatory for the data to still be useful are listed greyed out at the top of each column and cannot be unticked: the timestamp column, the geometry column of the event data, and the track ID column.

Clicking `Apply` removes all unticked attributes from the event data and from the track data, and the reduced data set is passed on to the next App. As long as `Apply` has not been clicked, the input data are passed on unchanged. The line below the button states how many attributes are removed from the output data.


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
This App has no settings in the Settings menu of MoveApps, as the attributes to keep depend on the input data and are therefore selected in the user interface of the App:

`Event attributes` (`eventAttrs`): checkboxes of all attributes of the event data. Ticked attributes are kept, unticked attributes are removed. The timestamp, track ID and geometry columns are greyed out and always kept. Default: all attributes ticked.

`Track attributes` (`trackAttrs`): checkboxes of all attributes of the track data. Ticked attributes are kept, unticked attributes are removed. The track ID column is greyed out and always kept. Default: all attributes ticked.

`Select all` / `Unselect all` (`eventAll`/`eventNone` and `trackAll`/`trackNone`): tick or untick all attributes of the respective column at once.

`Apply` (`apply`): removes all unticked attributes from the output data. Default: not clicked, i.e. the data are passed on unchanged.

`Store settings`: stores the ticked attributes of both columns and whether `Apply` has been clicked, for the following runs of the Workflow.

### Changes in output data
The App removes from the event data and from the track data all attributes that are not ticked. No attributes are added and no values are modified: the number of locations, the number of tracks, the timestamps, the track IDs and the geometries remain unchanged. If `Apply` is not clicked, and no settings with a clicked `Apply` are stored, the input data remain unchanged.

### Errors and null handling
**Setting `Apply`:** If `Apply` is not clicked, no attribute is removed and the input data are passed on unchanged, also if attributes have been unticked. The unticked attributes are only removed when `Apply` is clicked.

**Setting `Store settings`:** The stored settings consist of the names of the ticked attributes and of the number of clicks on `Apply`. If the settings are stored without having clicked `Apply`, automatic Workflow runs pass the data on unchanged; to make automatic runs remove the attributes, click `Apply` before `Store settings`. As the names of the ticked attributes are stored, attributes that are not present in the data at the time the settings were stored are removed in later runs, e.g. when the Workflow is run on a study with additional attributes. To keep such new attributes, open the App, tick them, click `Apply` and store the settings again.

**Common error:** If a subsequent App of the Workflow stops with a message about a missing column, an attribute was removed that this App requires. Open the user interface, tick the attribute again, click `Apply` and store the settings.

### Technical details
- The App is based on `move2`, the mandatory columns are identified with `move2::mt_time_column()` and `move2::mt_track_id_column()`, and with the geometry column of the underlying `sf` object.
- The attributes of the event data are removed by subsetting the columns of the `move2` object, the attributes of the track data by subsetting the table returned by `move2::mt_track_data()` and attaching it again with `move2::mt_set_track_data()`.
- The data are processed as a whole, not per track, and the attribute values, the coordinate reference system, the units and the time zone of the input data are not touched.
- The selection is stored with the Shiny bookmarking mechanism of MoveApps (`Store settings`). Stored are the ticked attributes of both checkbox groups and the click count of `Apply`. When the App starts, the stored selection is restored and, if `Apply` had been clicked, applied.
- Only the names of the attributes are handled, so runtime and memory do not depend noticeably on the number of locations.

### References
None.
