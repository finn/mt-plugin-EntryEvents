package EntryEvent::App;

use strict;
use MT;
use base 'MT::App';
use JSON;

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        events => \&events,
    );
    $app->{default_mode} = 'events';
    $app;
}

sub events {
    my $app = shift;
    my $start_time = $app->param('start_time');
    my $days = $app->param('days');
    my $category_id = $app->param('category_id');

    my $tmpl_id = $app->param('tmpl_id');
    my $tmpl_name = $app->param('tmpl_name');

    return '' unless ($tmpl_id || $tmpl_name);

    require MT::Template;
    require MT::Template::Context;
    require MT::Builder;

    my $tmpl;
    if ($tmpl_name) {
        $tmpl = MT::Template->load({ name => $tmpl_name });
    } elsif ($tmpl_id) {
        $tmpl = MT::Template->load($tmpl_id);
    }
    return '' unless ($tmpl);

    my $ctx = new MT::Template::Context;
    # we want to restrict the amt of time you can request here to a max of one week
    if (!$days || $days > 7) {
        $days = 7;
    }

    $ctx->stash('start_time', $start_time);
    $ctx->stash('days', $days);

    if ($category_id && $category_id =~ m/,/) {
        my @ids = split(",", $category_id);
        my @cats = MT::Category->load({ id => \@ids });
        $ctx->stash('categories', \@cats);
    } else {
        my $cat = MT::Category->load($category_id);
        $ctx->stash('category', $cat);
    }


    my $page = $tmpl->build($ctx);
    return $page || '';
}


1;
