use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Test::Warn;
use Moose::Meta::Class;
use Perl6::Slurp;
use JSON;
use Archive::Extract;
use File::Temp qw/ tempdir /;
use List::MoreUtils qw/ uniq /;

use npg_testing::db;
use t::autoqc_util qw/ write_samtools_script /; 

use_ok('npg_qc::autoqc::db_loader');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

subtest 'simple attributes and methods' => sub {
  plan tests => 14;

  my $db_loader = npg_qc::autoqc::db_loader->new();
  isa_ok($db_loader, 'npg_qc::autoqc::db_loader');

  $db_loader = npg_qc::autoqc::db_loader->new(
      path    =>['t/data/autoqc/tag_decode_stats'],
      schema  => $schema,
      verbose => 0,
  );
  is(scalar @{$db_loader->json_file}, 1, 'one json file found');
  my $json_file = 't/data/autoqc/tag_decode_stats/6624_3_tag_decode_stats.json';
  is($db_loader->json_file->[0], $json_file, 'correct json file found');
  my $values = decode_json(slurp($json_file));
  ok($db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test positive');
  $db_loader = npg_qc::autoqc::db_loader->new(id_run=>[3, 2, 6624]);
  ok($db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test positive');
  $db_loader = npg_qc::autoqc::db_loader->new(id_run=>[3, 2]);
  ok(!$db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test negative');
  $db_loader = npg_qc::autoqc::db_loader->new(lane=>[4,3]);
  ok($db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test positive');
  $db_loader = npg_qc::autoqc::db_loader->new(lane=>[4,5]);
  ok(!$db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test negative');
  $db_loader = npg_qc::autoqc::db_loader->new(check=>[]);
  ok($db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test positive');
  $db_loader = npg_qc::autoqc::db_loader->new(check=>['tag_decode_stats','other']);
  ok($db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test positive');
  $db_loader = npg_qc::autoqc::db_loader->new(check=>['insert_size','other']);
  ok(!$db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test negative');
  ok(!$db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test negative');

  $db_loader = npg_qc::autoqc::db_loader->new(
      path     =>['t/data/autoqc/tag_decode_stats'],
      schema   => $schema,
      verbose  => 1,
      id_run   => [1234],
      position => [1]
  );
  $values = {'some' => 'data', 'composition' => 'composed'};
  my $outcome;
  warning_like { $outcome = $db_loader->_pass_filter($values, 'sequence_summary') }
    qr/Filtering compositions is not implemented, will be loaded/,
    'warning that composition fields cannot be screened';
  is ($outcome, 1, 'composition passed filter')
};

subtest 'excluding non-db attributes' => sub {
  plan tests => 4;

  my $db_loader = npg_qc::autoqc::db_loader->new(
      path    =>['t/data/autoqc/tag_decode_stats'],
      schema  => $schema,
      verbose => 1,
  );
  my $values = {'pear' => 1, 'apple' => 2, 'orange' => 3,};
  $db_loader->_exclude_nondb_attrs($values, qw/pear apple orange/);
  is_deeply($values, {'pear' => 1, 'apple' => 2, 'orange' => 3,},
    'hash did not change');
  $values->{'__CLASS__'} = 'fruits';
  warning_like {$db_loader->_exclude_nondb_attrs($values, qw/pear apple/)}
    qr/Not loading field \'orange\'/,
    'warning about filtering out orange, but not __CLASS__';
  is_deeply($values, {'pear' => 1, 'apple' => 2,},
    'non-db orange and __CLASS__ filtered out');
  $db_loader->_exclude_nondb_attrs($values, qw/pear apple orange/);
  is_deeply($values, {'pear' => 1, 'apple' => 2,},
    'hash did not change');
};

subtest 'loading insert_size results' => sub {
  plan tests => 25;

  my $is_rs = $schema->resultset('InsertSize');
  my $current_count = $is_rs->search({})->count;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/insert_size/6062_8#1.insert_size.json'],
  );

  my $count_loaded;
  warnings_exist {$count_loaded = $db_loader->load()}
   [qr/not a directory, skipping/, qr/0 json files have been loaded/],
   'non-directory path entry skipped';
  is($count_loaded, 0, 'nothing loaded');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/dbix_loader/is'],
       verbose => 0,
  );
  lives_ok {$count_loaded = $db_loader->load()} 'file loaded';
  is($count_loaded, 1, 'reported one file loaded');
  $current_count++;
  is ($is_rs->search({})->count, $current_count, 'one record added to the table');
  lives_ok {$db_loader->load()} 'reload insert size result';
  my $rs = $is_rs->search({});
  is($rs->count, $current_count, 'no new records added');
  my $row = $rs->next;
  is(join(q[ ],@{$row->expected_size}), '50 200', 'insert size');
  is($row->num_well_aligned_reads, 50, 'number well-aligned reads');
  is($row->norm_fit_nmode, 22, 'norm_fit_nmode');
  is($row->norm_fit_confidence, .55, 'norm_fit_confidence');
  is($row->norm_fit_pass, 1, 'norm_fit_pass');
  is(scalar(@{$row->norm_fit_modes}), 15, 'norm_fit_modes');
  is($row->norm_fit_modes->[0], 1, 'norm_fit_modes[0]');
  is($row->norm_fit_modes->[14], 15, 'norm_fit_modes[14]');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/dbix_loader/is/update'],
       verbose => 0,
  );
  lives_ok {$db_loader->load()} 'reload updated insert size result';
  $rs = $is_rs->search({});
  is($rs->count, $current_count, 'no new records added');
  $row = $rs->next;
  is(join(q[ ],@{$row->expected_size}), '100 300', 'updated insert size');
  is($row->num_well_aligned_reads, 60, 'updated number well-aligned reads');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/dbix_loader/is'],
       update => 0,
  );
  warnings_exist {$db_loader->load()}
    [qr(Skipped t/data/autoqc/dbix_loader/is/12187_2\.insert_size\.json),
     qr(0 json files have been loaded)],
    'file skipped warning';
  $rs = $is_rs->search({});
  is($rs->count, $current_count, 'no new records added');
  $row = $rs->next;
  is(join(q[ ],@{$row->expected_size}), '100 300', 'insert size not updated');
  is($row->num_well_aligned_reads, 60, 'number well-aligned reads not updated');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/dbix_loader/is/more'],
       update => 0,
       verbose => 0,
  );
  lives_ok {$db_loader->load()} 'load new insert size result';
  is($is_rs->search({})->count, $current_count+1, 'a new records added');
};

subtest 'loading veryfy_bam_id results' => sub {
  plan tests => 8;

  my $is_rs = $schema->resultset('VerifyBamId');
  my $current_count = $is_rs->search({})->count;
  my $count_loaded;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       json_file   => ['t/data/autoqc/7321_7#8.verify_bam_id.json'],
       verbose => 0,
  );
  lives_ok {$count_loaded = $db_loader->load()} 'file loaded';
  is($count_loaded, 1, 'reported one file loaded');
  $current_count++;
  is ($is_rs->search({})->count, $current_count, 'one record added to the table');
  lives_ok {$db_loader->load()} 'reload VerifyBamId result';
  my $rs = $is_rs->search({});
  is($rs->count, $current_count, 'no new records added');
  my $row = $rs->next;
  is($row->freemix, 0.00025, 'freemix');
  is($row->freeLK0, 823213.22, 'freeLK0');
  is($row->freeLK1, 823213.92, 'freeLK1');
};

subtest 'loading from multiple paths' => sub {
  plan tests => 3;

  my $is_rs = $schema->resultset('InsertSize');
  $is_rs->delete_all();
  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/dbix_loader/is/more',
                  't/data/autoqc/dbix_loader/is/update',
                  't/data/autoqc/dbix_loader/is'
                 ],
       verbose => 0,
  );
  my $count;
  lives_ok {$count = $db_loader->load()} 'loading from multiple paths';
  is($count, 3, '3 loaded records reported');
  is($is_rs->search({})->count, 2, 'two records created');
};

subtest 'errors and warnings' => sub {
  plan tests => 4;

  my $is_rs = $schema->resultset('InsertSize');
  $is_rs->delete_all();
  my $file_good = 't/data/autoqc/dbix_loader/is/12187_2.insert_size.json';

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       json_file => [$file_good,
                     't/data/autoqc/insert_size/6062_8#2.insert_size.json'],
       verbose => 0,
  );
  throws_ok {$db_loader->load()} qr/Loading aborted, transaction has rolled back/,
    'error loading a set of files with the last file corrupt';
  is ($is_rs->search({})->count, 0, 'table is empty, ie transaction has been rolled back');

  my $file = 't/data/autoqc/insert_size/6062_8#1.insert_size.json';
  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       json_file => [$file_good,$file],
  );
  warnings_like {$db_loader->load()}  [
    qr/Loaded $file_good/,
    qr/Not loading field 'obins'/,
    qr/Loaded $file/,
    qr/2 json files have been loaded/ ],
    'loaded a file with incorrect attribute, gave warning';
  is ($is_rs->search({})->count, 2, 'two records created');
  $is_rs->delete_all();
};

$schema->resultset('InsertSize')->delete_all();
my $path = 't/data/autoqc/dbix_loader/run';
my $num_lane_jsons = 11;
my $num_plex_jsons = 44;

subtest 'loading and reloading' => sub {
  plan tests => 7;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       verbose => 0,
       path => [$path],
       id_run => [233],
  );
  is($db_loader->load(), 0, 'no files loaded - filtering by id');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       verbose => 0,
       path => [$path],
       id_run => [12233],
       lane => [3,5],
  );
  is($db_loader->load(), 0, 'no files loaded - filtering by lane');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema  => $schema,
       verbose => 0,
       path    => [$path],
       id_run  => [12233],
       lane    => [1,2],
       check   => [qw(pulldown_metrics some_other)],
  );
  is($db_loader->load(), 0, 'no files loaded - filtering by check name');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       verbose => 0,
       path => [$path]
  );
  is ($db_loader->load(), $num_lane_jsons, 'all json files loaded to the db');
  my $count = 0;
  foreach my $table (qw(Adapter InsertSize SpatialFilter
                        GcFraction RefMatch QXYield UpstreamTags
                        SequenceError TagMetrics TagsReporters)) {
    $count +=$schema->resultset($table)->search({})->count;
  }
  is($count, $num_lane_jsons, 'number of new records in the db is correct');

  is ($db_loader->load(), $num_lane_jsons, 'loading the same files again updates all files');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       path         => [$path],
       update       => 0,
  );
  is ($db_loader->load(), 0, 'loading the same files again with update option false'); 
};

subtest 'loading a range of results' => sub {
  plan tests => 4;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       path         => [$path, "$path/lane"],
       update       => 0,
       load_related => 0,
  );
  is ($db_loader->load(), $num_plex_jsons, 'loading from two paths without update');
  my $total_count = 0;
  my $plex_count = 0;
  my $tag_zero_count = 0;
  my @tables = qw(Adapter InsertSize GcFraction RefMatch QXYield Genotype
                  SequenceError BamFlagstats PulldownMetrics GcBias
                  AlignmentFilterMetrics);
  foreach my $table (@tables) {
    $total_count +=$schema->resultset($table)->search({})->count;
    $plex_count +=$schema->resultset($table)->search({tag_index => {'>', -1},})->count;
    $tag_zero_count +=$schema->resultset($table)->search({tag_index => 0,})->count;
  }

  foreach my $table (qw(TagMetrics UpstreamTags TagsReporters SpatialFilter)) {
    $total_count +=$schema->resultset($table)->search({})->count;
  }
  is ($plex_count, $num_plex_jsons, 'number of plexes loaded');
  is ($total_count, $num_plex_jsons+$num_lane_jsons, 'number of records loaded');
  is ($tag_zero_count, 8, 'number of tag zero records loaded');
};

subtest 'checking bam_flagstats records' => sub {
  plan tests => 6;

  my $rs = $schema->resultset('BamFlagstats');
  is ($rs->search({human_split => 'all'})->count, 6, '6 bam flagstats records for target files');
  is ($rs->search({human_split => 'human'})->count, 2, '2 bam flagstats records for human files');
  is ($rs->search({human_split => 'phix'})->count, 1, '1 bam flagstats records for phix files');
  is ($rs->search({subset => 'target'})->count, 6, '6 bam flagstats records for target files');
  is ($rs->search({subset => 'human'})->count, 2, '2 bam flagstats records for human files');
  is ($rs->search({subset => 'phix'})->count, 1, '1 bam flagstats records for phix files');
};

subtest 'testing load_related flag' => sub {
  plan tests => 2;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 1,
       path         => ['t/data/autoqc/bam_flagstats'],
       load_related => 0,
  );
  warnings_like { $db_loader->load() } [
    qr/Skipped t\/data\/autoqc\/bam_flagstats\/4783_5_bam_flagstats\.json/, # no __CLASS__ key
    qr/Loaded t\/data\/autoqc\/bam_flagstats\/4921_3_bam_flagstats\.json/,
    qr/1 json files have been loaded/
  ], 'warnings when loading bam_flagstats results';

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       path         => ['t/data/autoqc/bam_flagstats'],
  );
  throws_ok { $db_loader->load() }
    qr/Attribute \(sequence_file\) does not pass the type constraint/,
    'error building related objects - no bam file where expected';
};

my $archive = '17448_1_9';
my $tempdir = tempdir( CLEANUP => 1);
my $ae = Archive::Extract->new(archive => "t/data/autoqc/bam_flagstats/${archive}.tar.gz");
$ae->extract(to => $tempdir) or die $ae->error;
$archive = join q[/], $tempdir, $archive;
my $json_dir1 = join q[/], $archive, 'qc';
my $json_dir2 = join q[/], $json_dir1, 'all_json';
#note `find $archive`;
my $samtools_path  = join q[/], $tempdir, 'samtools1';
local $ENV{'PATH'} = join q[:], $tempdir, $ENV{'PATH'};
# Create mock samtools1 that will output the header
write_samtools_script($samtools_path, join(q[/],$archive,'cram.header'));

subtest 'loading bam_flagstats and its related objects from files' => sub {
  plan tests => 48;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       path         => [$json_dir2],
  );
  lives_ok { $db_loader->load() }
    'can load bamflag_stats w/o related, samtools stats and sequence summary';
  
  my @objects = $schema->resultset('BamFlagstats')->search(
    {'id_run' => 17448}, {order_by => {'-asc' => 'subset'}})->all();
  is (scalar @objects, 2, 'two objects');
  is ($objects[0]->subset, 'phix', 'object for target subset');
  is ($objects[1]->subset, undef,  'object for phix subset');

  @objects = $schema->resultset('SamtoolsStats')->search({})->all();
  is (scalar @objects, 4, 'four objects');
  my @filters = sort { $a cmp $b } uniq map { $_->filter} @objects;
  is (join(q[ ],@filters), 'F0x900 F0xB00', 'two distinct filters');

  my @da_component = qw(
    9c2dfacdbfa50be10bfbab6df20a8ebdcd8e67bf0e659b1fe6be667c6258d33c
    31d7631510fd4090dddc218ebc46d4d3cab3447964e620f25713293a21c7d6a6
  ); # two distinct components
  my @da_composition = qw(
    bfc10d33f4518996db01d1b70ebc17d986684d2e04e20ab072b8b9e51ae73dfa
    ca4c3f9e6f8247fed589e629098d4243244ecd71f588a5e230c3353f5477c5cb
  ); # two distinct compositions

  is (join(q[ ], sort {$a cmp $b} (uniq map { $_->seq_composition->digest} @objects)),
   join(q[ ], @da_composition), 'two distinct composition keys');
  my @da = @da_composition;
  unshift @da, $da[0];
  push @da, $da[-1];
  my $i = 0;
  foreach my $o (@objects) {
    my $composition = $o->seq_composition;
    isa_ok ($composition, 'npg_qc::Schema::Result::SeqComposition');
    is ($composition->size, 1, 'composition of one');
    is ($composition->digest, $da[$i], 'composition digest');
    my $cc_link_rs = $composition->seq_component_compositions;
    is ($cc_link_rs->count, 1, 'one link to component');
    my $component = $cc_link_rs->next->seq_component;
    isa_ok ($component, 'npg_qc::Schema::Result::SeqComponent');
    $i++;
  }

  $i = 0;
  @objects = $schema->resultset('SequenceSummary')->search({})->all();
  is (scalar @objects, 2, 'two objects');
  foreach my $o (@objects) {
    my $composition = $o->seq_composition;
    isa_ok ($composition, 'npg_qc::Schema::Result::SeqComposition');
    is ($composition->size, 1, 'composition of one');
    is ($composition->digest, $da_composition[$i], 'composition digest');
    my $cc_link_rs = $composition->seq_component_compositions;
    is ($cc_link_rs->count, 1, 'one link to component');
    my $component = $cc_link_rs->next->seq_component;
    isa_ok ($component, 'npg_qc::Schema::Result::SeqComponent');
    is ($component->digest, $da_component[$i], 'component digest');
    is ($component->id_run, 17448, 'run id');
    is ($component->position, 1, 'position');
    is ($component->tag_index, 9, 'tag_index');
    is ($component->subset, $i ? 'phix' : undef, 'subset value');
    $i++;
  }
};

subtest 'loading bam_flagstats and its related objects from memory' => sub {
  plan tests => 14;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       id_run       => [17448],
       path         => [$json_dir1],
  );
  throws_ok { $db_loader->load() }
    qr/Attribute \(sequence_file\) does not pass the type constraint/,
    'no cram file upstream - error';

  rename "${json_dir1}/17448_1#9.no_related.bam_flagstats.json",
         "${json_dir1}/17448_1#9.bam_flagstats.json";
  rename "${json_dir1}/17448_1#9_phix.no_related.bam_flagstats.json",
         "${json_dir1}/17448_1#9_phix.bam_flagstats.json";
      
  $schema->resultset('SequenceSummary')->delete();
  $schema->resultset('SamtoolsStats')->delete();
 
  $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       id_run       => [17448],
       path         => [$json_dir1],
  );
  lives_ok { $db_loader->load() }
    'can load bamflag_stats with in-memory related objects';

  is ($schema->resultset('SeqComposition')->search({})->count, 2,
    'no new compositions'); 
  is ($schema->resultset('SeqComponent')->search({})->count, 2,
    'no new components');
  is ($schema->resultset('SeqComponentComposition')->search({})->count, 2,
    'no new memberships');
  is ($schema->resultset('SamtoolsStats')->search({})->count, 4,
    'samtools stats number of rows as before');
  is ($schema->resultset('SequenceSummary')->search({})->count, 2,
    'sequence summary number of rows as before');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       id_run       => [17448],
       path         => [$json_dir1],
  );
  $db_loader->load(); # reload

  is ($schema->resultset('SamtoolsStats')->search({})->count, 4,
    'samtools stats number of rows as before');
  my @ss = $schema->resultset('SequenceSummary')->
    search({}, {'order_by' => 'id_sequence_summary'})->all();
  is (scalar @ss, 4,
    'sequence summary number of rows twice the previous number');
  is ($ss[0]->iscurrent, 0, 'iscurrent flag is reset to false');
  is ($ss[1]->iscurrent, 0, 'iscurrent flag is reset to false');
  is ($ss[2]->iscurrent, 1, 'iscurrent flag is set to true');
  is ($ss[3]->iscurrent, 1, 'iscurrent flag is set to true');
  ok ($ss[0]->date, 'date is set');
};

1;
