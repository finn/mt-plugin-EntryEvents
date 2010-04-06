package EntryEvent::Util;

use strict;

use base 'Exporter';
our @EXPORT_OK = qw( ts2datetime eventsort );

sub ts2datetime { # utility function to turn YYYYMMDDHHMMSS datestamp into a datetime obj
    my $ts = shift;
    my ($yr, $mo, $dy, $hr, $mn, $sc) = unpack('A4A2A2A2A2A2', $ts);

    my $dtime = DateTime->new(year => $yr, month => $mo, day => $dy, hour => $hr, minute => $mn, second => $sc);
    return $dtime;
}

1;
