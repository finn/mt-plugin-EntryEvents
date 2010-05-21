# EntryEvents

## Requirements

This plugin requires the Perl DateTime module as well as DateTime::Event::Ical.

## Usage

The plugin needs to be enabled from the plugin settings screen for each blog on which you'd like to use it. To do this, navigate to Tools->Plugins for the blog you'd like to enable, click on EntryEvents, click on Settings, and check the "Show Events" checkbox.

Now the next time you create or edit an entry in that blog, you will see an Events widget in the right column. Clicking on the "Click to add event date" link will show a calendar.

To select a date/time for an event that only occurs once, simply click the date for which the event is scheduled and select a time from the dropdowns beneath the calendar. To navigate future or past months, click the « and » buttons next to the current month name in the header. Once a date has been selected for your event, you can add recurrence details by selecting the Recurrence checkbox below the calendar, which will show more options. Recurrence options are:

* Every Day - this event will recur at the selected time every single day
* Every Week - this event will recur at the same time on the selected day every single week
* Every Month - this event will recur on the same date every single month (eg, an event on January 12 that recurs monthly will happen on February 12, March 12, etc.)
* Every Year - this event will recur on this date every year
* Custom... - selecting this will bring up further options for refining when an event recurs

Selecting a particular Frequency for your custom recurrence will bring up a menu of options for that recurrence:

* Daily - for an event that recurs every X days.
* Weekly - for an event that recurs every X number of weeks on a particular day or days. For example, you can specify an event that recurs every Monday, Wednesday, and Friday every other week.
* Monthly - for an event that recurs on a particular day of the month that does not follow on the same date consistently. For example, an event may occur on the third Monday of every month. This will be pre-filled to reflect the date that you selected on the calendar.
* Yearly - for an event that recurs every X number of years on the same date every year.

For whichever form of recurrence you select, you must also specify a date that the recurrence ends in the Until box. This is pre-filled with a date a year from the selected event start.

## Template Tags

### Container Tags

``<mt:Events />`` -- this is a container tag that will retrieve all events for the blog in context. Optional parameters are:

* start -- the timestamp to start events from, in YYYYMMDDHHMMSS format. Defaults to today.
* days -- the number of days' worth of events data to load. Defaults to 7.
* end -- the timestamp to grab events until, in YYYYMMDDHHMMSS format. If specified, will override the days argument.

An ``<mt:Events>`` tag with no parameters will default to displaying 7 days worth of events, starting with the time the template is published. This tag returns the entry objects associated with the events as well, so that one can retrieve the entry's title, description, tags, etc. in this context.

``<mt:FeaturedEvents />`` -- this is a container tag that will retrieve all featured events for the blog in context. Optional parameters are:
* start -- the timestamp to start events from, in YYYYMMDDHHMMSS format. Defaults to today.
* limit -- the number of dates to load. If this is specified, it will override the days parameter & only display limit number of dates, even if that is fewer than the number of days specified.

An ``<mt:FeaturedEvents>`` tag will load all (or up to limit=n) events marked "featured" starting on the date specified.

``<mt:CategoryEvents />`` -- this is a container tag that will retrieve all events for the category in context. Optional parameters are:

* start -- the timestamp to start events from, in YYYYMMDDHHMMSS format. Defaults to today.
* days -- the number of days' worth of events data to load. Defaults to 7.
* end -- the timestamp to grab events until, in YYYYMMDDHHMMSS format. If specified, will override the days argument.
* featured -- set this to 1 and we will load featured events in the specific category.

``<mt:EntryEvents>`` -- this is a container tag which will retrieve a list of the occurrences of the event associated with the current entry in context. Useful for retrieving the future dates of a recurring event. Optional parameters are:
    
* start -- the timestamp to start events from, in YYYYMMDDHHMMSS format. If this is not passed, all recurrences of this event will be listed, including those in the past.
* days -- the number of days' worth of events data to load.
* end -- the timestamp to grab events until, in YYYYMMDDHHMMSS format. If specified, will override the days argument.
    

### Function Tags

``<mt:EventDate>`` -- will return the date of the current instance of the event in context. If this is an event that only occurs once, it will return just that date. However, if it's a recurring event it will return the date of the recurrence in context (this tag will only work within one of the Events container tags). This takes a format_ts parameter that can be structured per the Movable Type Date Formats documentation.


### Conditional Tags

``<mt:IfEventHasRecurrence>`` -- a conditional tag which returns true if the event is recurring, false if it is a one-off event.
``<mt:IfEventFeatured>`` -- a conditional tag which returns true if the event is marked as "featured"


An example template using the above tags to display 7 days' worth of events and their details:

	This week's upcoming events:<br />
	<ul>
	<mt:Events days="7">
		<li><mt:EntryTitle> -- on <mt:EventDate></li>
	</mt:Events>
	</ul>


### Technical Stuff

Each event lives in a separate mt_entryevent table tied to the entries via an entryevent_entry_id link. That means that every event is a one-to-one relationship with an entry which means that future recurrences of an event will end up having the same comments. If you end up wanting events that have different comments from occurrence to occurrence, I would recommend creating new entries for each one.