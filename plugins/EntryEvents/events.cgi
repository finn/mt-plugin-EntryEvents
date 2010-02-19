#!/usr/bin/perl -w
#
# dynamic events

use strict;
use lib "lib", ($ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : "../../lib");

use MT::Bootstrap App => 'EntryEvent::App';

__END__
