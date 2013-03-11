#!perl -T

use strict;
use warnings;
use utf8;
use Unicode::Normalize;

use Test::More tests => 26;

BEGIN {
    ok(defined($ENV{'SPSID_CONFIG'})) or BAIL_OUT('');
    require_ok($ENV{'SPSID_CONFIG'})  or BAIL_OUT('');
}

use SPSID::Client;

my $client = SPSID::Client->new(url => $ENV{'SPSID_PLACK_URL'});
ok($client, 'SPSID::Client->new');

my $root = $client->get_siam_root();
ok($root, '$client->get_siam_root()');

my $r = $client->search_objects($root, 'SIAM::Device',
                                'siam.device.inventory_id', 'ZUR8050AN33');
ok(scalar(@{$r} == 1), 'search device ZUR8050AN33');
my $device = $r->[0]->{'spsid.object.id'};


# try to create a duplicate root

my $id;
eval {
    $id = $client->create_object
        ('SIAM',
         {
          'spsid.object.container' => 'NIL',
          'siam.object.complete' => 1,
         })};

ok((not defined($id) and $@), 'duplicate SIAM root') or
    BAIL_OUT('Succeeded to create duplicate root objects');

# Searches that should return empty lists
$r = $client->search_objects(undef, 'SIAM::Service',
                             'siam.svcunit.inventory_id', 'BIS.89999.56');
ok(scalar(@{$r} == 0), 'search nonexistent object N1');

$r = $client->search_objects(undef, 'SIAM::Service',
                             'siam.svc.inventory_id', 'BIS');
ok(scalar(@{$r} == 0), 'search nonexistent object N2');

$r = $client->search_objects($root, 'SIAM::Service',
                             'siam.svc.inventory_id', 'BIS0001');
ok(scalar(@{$r} == 0), 'search nonexistent object N3');


# Find a Service by exact match and by prefix and compare

my $r1 = $client->search_objects(undef, 'SIAM::Service',
                                 'siam.svc.inventory_id', 'BIS0002');
ok(scalar(@{$r1} == 1), 'search Service BIS0002');

my $svc = $r1->[0]->{'spsid.object.id'};

my $r2 = $client->search_prefix('SIAM::Service',
                                'xyz.svc.street', 'datas');
ok(scalar(@{$r2} == 2), 'prefix search Service by street');


ok((($svc eq $r2->[0]->{'spsid.object.id'}) or
    ($svc eq $r2->[1]->{'spsid.object.id'})),
   'prefix search and exact search return the same object');


# search by Unicode prefix
my $r3 = $client->search_prefix('SIAM::Service',
                                'xyz.svc.city', 'düben');
ok(scalar(@{$r3} == 2), 'Unicode prefix search Service by city');

ok((($svc eq $r3->[0]->{'spsid.object.id'}) or
    ($svc eq $r3->[1]->{'spsid.object.id'})),
   'Unicode prefix search returns the same object');

# exact Unicode search
my $r4 = $client->search_objects(undef, 'SIAM::Service',
                                 'xyz.svc.city', 'Dübendorf');
ok(scalar(@{$r4} == 2), 'Unicode exact search Service by city');

ok((($svc eq $r4->[0]->{'spsid.object.id'}) or
    ($svc eq $r4->[1]->{'spsid.object.id'})),
   'Unicode prefix search returns the same object');


# Check unicode attribute

my $x = $r1->[0]->{'xyz.svc.city'};
ok(utf8::is_utf8($x),
   'xyz.svc.city is a valid Unicode string');

my $y = 'Dübendorf';
utf8::encode($y);

diag($x);
diag($y);

ok(($x eq $y),
   'Unicode string in attribute value');


# try to create a SIAM::ServiceComponent at the top level
eval {
    $id = $client->create_object
        ('SIAM::ServiceComponent',
         {
          'spsid.object.container' => $root,
          'siam.object.complete' => 1,
          'siam.svcc.name' => 'XX',
          'siam.svcc.type' => 'XX',
          'siam.svcc.inventory_id' => 'XX',
          'siam.svcc.device_id' => $device,
         })};

ok((not defined($id) and $@), 'create object with wrong container');


# try to create a SIAM::ServiceUnit with duplicate inventory ID
eval {
    $id = $client->create_object
        ('SIAM::ServiceUnit',
         {
          'spsid.object.container' => $svc,
          'siam.object.complete' => 1,
          'siam.svcunit.name' => 'xxx',
          'siam.svcunit.type' => 'xxx',
          'siam.svcunit.inventory_id' => 'BIS.64876.45',
         })};

ok((not defined($id) and $@), 'create ServiceUnit with duplicate inventory_id');

# Create, modify, delete SIAM::ServiceUnit

eval {
    $id = $client->create_object
        ('SIAM::ServiceUnit',
         {
          'spsid.object.container' => $svc,
          'siam.object.complete' => 1,
          'siam.svcunit.name' => 'xxx',
          'siam.svcunit.type' => 'xxx',
          'siam.svcunit.inventory_id' => 'xxxx',
          'xyz.xyz.xxx' => 'xxxx',
         })};

ok((defined($id) and not $@), 'create a new ServiceUnit');

$r = $client->get_object($id);
ok(($r->{'xyz.xyz.xxx'} eq 'xxxx'), 'custom attribute in created object');

$client->modify_object
    ($id,
     {
      'siam.svcunit.name' => 'yyyy',
      'xyz.xyz.xyz' => 'xxxx',
      'xyz.xyz.xxx' => undef,
     });

$r = $client->get_object($id);

ok(($r->{'siam.svcunit.name'} eq 'yyyy'), 'attribute value modification');
ok(($r->{'xyz.xyz.xyz'} eq 'xxxx'), 'adding an attribute');
ok((not defined($r->{'xyz.xyz.xxx'})), 'deleting an attribute');


$r = $client->contained_classes($id);
ok((scalar(@{$r}) == 0), 'contained_classes N1');

$r = $client->contained_classes($svc);
ok(((scalar(@{$r}) == 1) and ($r->[0] eq 'SIAM::ServiceUnit')),
   'contained_classes N2');





# Local Variables:
# mode: cperl
# indent-tabs-mode: nil
# cperl-indent-level: 4
# cperl-continued-statement-offset: 4
# cperl-continued-brace-offset: -4
# cperl-brace-offset: 0
# cperl-label-offset: -2
# End:







