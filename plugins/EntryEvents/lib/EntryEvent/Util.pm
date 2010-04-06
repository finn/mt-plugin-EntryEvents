############################################################################
# Copyright © 2010 Six Apart Ltd.
# This program is free software: you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# version 2 for more details. You should have received a copy of the GNU
# General Public License version 2 along with this program. If not, see
# <http://www.gnu.org/licenses/>.
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
