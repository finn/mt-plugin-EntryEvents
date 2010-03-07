package EntryEvent::Tags;

use strict;
use warnings;

use MT;
use MT::Util qw( format_ts epoch2ts );
use EntryEvent::Util qw( ts2datetime );
require EntryEvent::EntryEvent;

sub build_event_template {
	my ($ctx, $args, $cond, $events) = @_;

	# do the tmpl buildy parts
    my $res     = '';
    my $tokens     = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my $count = 0;
	my $total = scalar @$events;
	my $vars = $ctx->{__stash}{vars} ||= {};
	my $check_day = 0;
	my $new_day = 0;
	for my $entry_event (@$events) {
		my $event = $entry_event->{event};
		my $event_date = epoch2ts(undef, $entry_event->epoch);
		my $entry = MT::Entry->load($event->entry_id);
		local $ctx->{__stash}{blog} = $entry->blog;
        local $ctx->{__stash}{blog_id} = $entry->blog_id;
		local $ctx->{__stash}{entry} = $entry;
		local $ctx->{__stash}{event} = $event;
		local $ctx->{__stash}{event_date} = $event_date;
		# do a calculation to know when we're on a new day
		my ($yr, $mo, $dy, $hr, $mn, $sc) = unpack('A4A2A2A2A2A2', $event_date);
		if ($dy != $check_day) {
			$new_day = 1;
		} else {
			$new_day = 0;
		}
		local $vars->{new_day} = $new_day;
		$check_day = $dy;
        local $vars->{__first__} = $count == 0;
        local $vars->{__last__} = ($count == $total || ($count+1) == $args->{limit});
        local $vars->{__odd__} = ($count % 2) == 1;
        local $vars->{__even__} = ($count % 2) == 0;
        local $vars->{__counter__} = $count;
		my $out = $builder->build( $ctx, $tokens );
		return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
		$count++;
		last if ($args->{limit} && $count == $args->{limit});
	}
	
	return $res;
}


sub all_events_container { # a container to return all events in a given time period
	my ($ctx, $args, $cond) = @_;
	my $blog = $ctx->stash('blog');
	my $start = $args->{start} || $ctx->stash('start_time');
	my $end = $args->{end}|| $ctx->stash('end_time');
	if ($start) {
		# start is passed as YYYYMMDDHHMMSS so parse that to a DateTime obj
		$start = ts2datetime($start);
	} else {
		# default to now
		$start = DateTime->now;
	}
	if ($end) {
		$end = ts2datetime($end);
	} else {
		if ($args->{days} || $ctx->stash('days')) {
			$end = $start->clone;
			my $days = $args->{days} || $ctx->stash('days');
			$end->add( days => $days );
		} elsif (!$args->{no_end}) { # we can explicitly pass in a "no_end" var here to NOT limit things, else..
			# if $end isn't passed and $days isn't set, we want to limit to 7 days by default
			$end = $start->clone;
			$end->add( days => 7 );
		}
	}
	my @events; 
	# first check for repeating events that fall within the range given
	my $check_set = DateTime::Span->from_datetimes( start => $start, ($end)?( end => $end ):());

	my $type = MT::Meta->metadata_by_name('EntryEvent::EntryEvent', 'ical');

	my $event_iter = EntryEvent::EntryEvent->load_iter(undef, { 
		join => [ 
			EntryEvent::EntryEvent->meta_pkg(),
			undef,
			{ type =>  $type->{name},
	         'entryevent_id' => \'= entryevent_id',
			$type->{type} => \'IS NOT NULL' } ] 
		}); # we have to go through all events with ical fields, ugh

	my @seen_ids;
	while (my $event = $event_iter->()) {
		push @seen_ids, $event->id;
		my $ical = $event->ical;

		# doing some datetime intersection stuff with our start and end dates to find out whether our event 
		# falls within the provided dates (or just one date)
		$ical->{dtstart} = ts2datetime($ical->{dtstart}) unless (ref $ical->{dtstart} eq 'DateTime');
		$ical->{until} = ts2datetime($ical->{until}) unless (ref $ical->{until} eq 'DateTime');


		my $event_recur = DateTime::Event::ICal->recur(%$ical);
		# now we need to iterate through occurrences of this event as well, woohoo
		my $recurrence_iter = $event_recur->iterator();
		while (my $recurrence_check = $recurrence_iter->next()) {
			if ($check_set->intersects($recurrence_check)) {
				$recurrence_check->{event} = $event;
				push @events, $recurrence_check;
			}
		}
	}
	
	# now load the explicit set of events that occur in our defined window that we have not already picked up
	my $ts_start = epoch2ts(undef, $start->epoch);
	my $ts_end = (defined $end)?epoch2ts(undef, $end->epoch):undef;
	my @events_set = EntryEvent::EntryEvent->load({ (scalar @seen_ids)?( id => { not => \@seen_ids } ):( ), event_date => [ $ts_start, $ts_end ] }, { range => { event_date => 1 } });
	for my $e_set (@events_set) {
		my $dt = ts2datetime($e_set->event_date);
		$dt->{event} = $e_set;
		push @events, $dt;
	}
	
	# now sort by event occurrence
	@events = sort { $a->{event}->get_next_occurrence($ts_start, $a) <=> $b->{event}->get_next_occurrence($ts_start, $b) } @events;
	return build_event_template($ctx, $args, $cond, \@events);
}

sub entry_event_container { # a container that will return all occurrences of the event associated with this entry
	my ($ctx, $args, $cond) = @_;
	my $blog = $ctx->stash('blog');
	my $entry = $ctx->stash('entry');
	
	my @events;
	
	my $event = EntryEvent::EntryEvent->load({ entry_id => $entry->id }) or return '';
	
	# args for limit & whatnot
	my $limit = $args->{limit};
	my $start = $args->{start} || epoch2ts(time);
	my $end = $args->{end};
	
	if ($start) {
		# start is passed as YYYYMMDDHHMMSS so parse that to a DateTime obj
		$start = ts2datetime($start);
	}
	
	if ($end) {
		$end = ts2datetime($end);
	}
	
	my $check_set = DateTime::Span->from_datetimes( start => $start, ($end)?( end => $end ):());
	my $ical = $event->ical;
	if ($ical) { # this is a recurring event, we want to push an iter of events into @events
		# doing some datetime intersection stuff with our start and end dates to find out whether our event 
		# falls within the provided dates (or just one date)
		$ical->{dtstart} = ts2datetime($ical->{dtstart}) unless (ref $ical->{dtstart} eq 'DateTime');
		$ical->{until} = ts2datetime($ical->{until}) unless (ref $ical->{until} eq 'DateTime');

		my $event_recur = DateTime::Event::ICal->recur(%$ical);
		# now we need to iterate through occurrences of this event as well, woohoo
		my $recurrence_iter = $event_recur->iterator();
		my $count = 0;
		while (my $recurrence_check = $recurrence_iter->next()) {
			if ($check_set) { # we have a set of dates to check against
				if ($check_set->intersects($recurrence_check)) {
					$count++;
					$recurrence_check->{event} = $event;
					push @events, $recurrence_check;
					last if ($limit && $count >= $limit);
				}
			} else {
				$count++;
				$recurrence_check->{event} = $event;
				push @events, $recurrence_check;
				last if ($limit && $count >= $limit);
			}
		}
	} else { # this is just one event, need to just push that into the array
		my $dt = ts2datetime($event->event_date);
		$dt->{event} = $event;
		push @events, $dt;
	}
	@events = sort { $a->{event}->get_next_occurrence(epoch2ts(undef, $start->epoch), $a) <=> $b->{event}->get_next_occurrence(epoch2ts(undef, $start->epoch), $b) } @events;
	return build_event_template($ctx, $args, $cond, \@events);
}

sub featured_container { # just find featured events
	my ($ctx, $args, $cond) = @_;
	my $blog = $ctx->stash('blog');

	my $limit = $args->{limit};
	my $start = $args->{start} || epoch2ts(undef, time);
	
	if ($start) {
		# start is passed as YYYYMMDDHHMMSS so parse that to a DateTime obj
		$start = ts2datetime($start);
	}

	
	my $check_set = DateTime::Span->from_datetimes( start => $start );


	my $tag = lc $ctx->stash('tag');

	my @events;
	my @load_events = EntryEvent::EntryEvent->load({ featured => 1 }, { limit => $limit }) or return '';

	for my $event (@load_events) {
		if (my $ical = $event->ical) {
			# doing some datetime intersection stuff with our start and end dates to find out whether our event 
			# falls within the provided dates (or just one date)
			$ical->{dtstart} = ts2datetime($ical->{dtstart}) unless (ref $ical->{dtstart} eq 'DateTime');
			$ical->{until} = ts2datetime($ical->{until}) unless (ref $ical->{until} eq 'DateTime');;

			my $event_recur = DateTime::Event::ICal->recur(%$ical);
			my $event_next = $event_recur->next($start); # just get the next recurrence of this event after $start
			$event_next->{event} = $event;
			push @events, $event_next;
			
		} else {
			my $dt = ts2datetime($event->event_date);
			$dt->{event} = $event;
			push @events, $dt;
		}
	}
	@events = sort { $a->{event}->get_next_occurrence(epoch2ts(undef, $start->epoch), $a) <=> $b->{event}->get_next_occurrence(epoch2ts(undef, $start->epoch), $b) } @events;
	return build_event_template($ctx, $args, $cond, \@events);
	
}

sub category_container { # a container to find events in a specific category
	my ($ctx, $args, $cond) = @_;

	my $start = $args->{start} || $ctx->stash('start_time');
	my $end = $args->{end} || $ctx->stash('end_time');
	my $limit = $args->{limit};
	my $featured = $args->{featured}; # we can also filter by featured on this
    my $blog_id = $args->{blog_id} || $ctx->stash('blog_id');
	my $blog = MT::Blog->load($blog_id) or return $ctx->error('Unable to load blog for <mt:categoryevents> tag');

	my ($cat, @cat_ids);
	if ($args->{category}) {
		my $category = $args->{category} or return $ctx->error("You must pass a 'category' param to the categoryevents tag if not called in a category context");
		$cat = MT::Category->load({ label => $category, blog_id => $blog_id }) or return $ctx->error("Unable to find category '$category'");
	} elsif ($ctx->stash('category') || $ctx->stash('archive_category')) {
		$cat = ($ctx->stash('category') || $ctx->stash('archive_category')) or return $ctx->error("Cannot find category for categoryevents tag");
	} elsif ($ctx->stash('categories')) {
		@cat_ids = map { $_->id } @{$ctx->stash('categories')};
	}
	
	if ($start) {
		# start is passed as YYYYMMDDHHMMSS so parse that to a DateTime obj
		$start = ts2datetime($start);
	} else {
		# default to now
		$start = DateTime->now;
	}
	if ($end) {
		$end = ts2datetime($end);
	} else {
		if ($args->{days}) {
			$end = $start->clone;
			$end->add( days => $args->{days} );
		} elsif (!$args->{no_end}) { # we can explicitly pass in a "no_end" var here to NOT limit things, else..
			# if $end isn't passed and $days isn't set, we want to limit to 7 days by default
			$end = $start->clone;
			$end->add( days => 7 );
		}
	}
	my @events;
	# we're doing this backwards -- we want to find entries in this category & then figure out if they fall in our event limit
	my @entries;
	if (@cat_ids) {
		@entries = MT::Entry->load({ blog_id => $blog->id }, { join => MT::Placement->join_on( 'entry_id', { category_id => \@cat_ids }) } );
	} elsif ($cat) {
		@entries = MT::Entry->load({ blog_id => $blog->id }, { join => MT::Placement->join_on( 'entry_id', { category_id => $cat->id }) } );
	} else {
		return $ctx->error("No category was found in context for a categoryevents tag");
	}
	
	my @entry_ids = map { $_->id } @entries;
	my $event_iter = EntryEvent::EntryEvent->load_iter({ entry_id => \@entry_ids, ($featured)? ( featured => 1 ):() });
	my $check_set = DateTime::Span->from_datetimes( start => $start, ($end)?( end => $end ):());
	while (my $event = $event_iter->()) {
		my $ical = $event->ical;
		if ($ical) { # this is a recurring event, we want to push an iter of events into @events
			# doing some datetime intersection stuff with our start and end dates to find out whether our event 
			# falls within the provided dates (or just one date)
			$ical->{dtstart} = ts2datetime($ical->{dtstart}) unless (ref $ical->{dtstart} eq 'DateTime');
			$ical->{until} = ts2datetime($ical->{until}) unless (ref $ical->{until} eq 'DateTime');

			my $event_recur = DateTime::Event::ICal->recur(%$ical);
			# now we need to iterate through occurrences of this event as well, woohoo
			my $recurrence_iter = $event_recur->iterator();
			my $count = 0;
			while (my $recurrence_check = $recurrence_iter->next()) {
				if ($check_set) { # we have a set of dates to check against
					if ($check_set->intersects($recurrence_check)) {
						$count++;
						$recurrence_check->{event} = $event;
						push @events, $recurrence_check;
						last if ($limit && $count >= $limit);
					}
				} else {
					$count++;
					$recurrence_check->{event} = $event;
					push @events, $recurrence_check;
					last if ($limit && $count >= $limit);
				}
			}
		} else { # this is just one event, need to just push that into the array
			my $dt = ts2datetime($event->event_date);
			if (DateTime->compare($dt, $start) >= 0) {
				$dt->{event} = $event;
				push @events, $dt;
			}
		}
	}

    my $ts = epoch2ts(undef, $start->epoch);
	# sort by occurrence
	@events = sort { $a->{event}->get_next_occurrence($ts, $a) <=> $b->{event}->get_next_occurrence($ts, $b) } @events;
	return build_event_template($ctx, $args, $cond, \@events);
	
}

sub entry_event_date {
	my ($ctx, $args, $cond) = @_;
	my $event_date = $ctx->stash('event_date') or return $ctx->error('There was no event found in context.');
	my $format = $args->{format} || '%A, %B %e at %l:%M %p';
	my $date = format_ts($format, $event_date);
	return $date;
}

sub event_has_recurrence {
	my ($ctx, $args, $cond) = @_;
	my $event = $ctx->stash('event') or return $ctx->error('There was no event found in context.');
	if (defined $event->ical) {
		return 1;
	}
	return 0;
}

sub event_is_featured {
	my ($ctx, $args, $cond) = @_;
	my $event = $ctx->stash('event') or return $ctx->error('There was no event found in context.');
	return $event->featured || 0;
}


1;