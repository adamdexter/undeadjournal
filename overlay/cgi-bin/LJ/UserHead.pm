package LJ::UserHead;
use strict;
# Stub: SUP-era "userhead" (purchasable avatar) catalog, referenced by
# htdocs/manage/profile but never open-sourced. An empty catalog keeps the
# profile page rendering; the userhead picker simply offers nothing.
# get_all_userheads must return an ARRAYREF — manage/profile does @$uhs_all.
sub get_all_userheads { return []; }
sub get_userhead      { return undef; }
1;
