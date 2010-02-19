package EntryEvent::EntryEvent;
use strict;
use warnings;

use base qw( MT::Object );
use MT::Util qw( epoch2ts );
use EntryEvent::Util qw( ts2datetime );

require DateTime;
require DateTime::Event::ICal;
require DateTime::Set;
require DateTime::Span;

__PACKAGE__->install_properties({
	column_defs => {
        'id' => 'integer not null auto_increment',
        'blog_id' => 'integer not null',
        'entry_id' => 'integer not null',
        'event_date' => 'datetime not null',
		'featured' => 'boolean',
	},
    indexes => {
        entry_id => 1,
        blog_id => 1,
    },
    datasource => 'entryevent',
    primary_key => 'id',
    child_of    => 'MT::Entry',
	meta => 1,
});

__PACKAGE__->install_meta({
	columns => [ 'ical' ]
});

sub recurrence { # format this event's recurrence params in DateTime::Event::ICal format
	my $event = shift;
	my $ical = $event->ical;
	return unless ($ical); # return undef if this has no ical param

	# convert these time params to datetime objects.. unless they already are
	$ical->{dtstart} = ts2datetime($ical->{dtstart}) unless (ref $ical->{dtstart} eq 'DateTime');
	if ($ical->{until}) {
		$ical->{until} = ts2datetime($ical->{until}) unless (ref $ical->{until} eq 'DateTime');
	}
	my $recur = DateTime::Event::ICal->recur(%$ical);
	return $recur;
}


sub get_next_occurrence { # function to get the next occurence of the given event that occurs after a particular time
	my $event = shift;
	my ($time, $recurrence) = @_; # time is passed in YYYYMMDDHHMMSS format
	
	unless ($time) {
		$time = epoch2ts(undef, time);
	}
	if ($recurrence) {
		return epoch2ts(undef, $recurrence->epoch);
	} else {
		$recurrence = $event->recurrence;
		if ($recurrence) { # if this event recurs, let's return the next instance of it after $time
			my $dtime = ts2datetime($time);
			return epoch2ts(undef, $recurrence->next($dtime)->epoch);
		} else { # this does not recur, so let's just spit out the next date if it's > time
			return ($event->event_date > $time)?$event->event_date:undef;
		}
	}
}


1;
