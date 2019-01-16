use strict;
use warnings;
use File::Basename;
use Cwd qw/getcwd abs_path cwd/;
use File::Spec::Functions qw(catfile catdir);
use Test::More tests => 4;
use Test::Exception;
use Test::Warn;
use Test::Deep;
use File::Temp qw/tempdir/;

my $dir = '/tmp/hzSrgyv18v'; #tempdir( CLEANUP => 0 );
my $current_dir = cwd();
my $central = 't/data/autoqc/mapd';
my $repos = catdir($central, 'references');
my $data_dir = catdir($central, 'data');

local $ENV{no_proxy} = '';
local $ENV{http_proxy} = 'http://wibble.do';
local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = qq[$central/metadata_cache/samplesheet_27128.csv];
local $ENV{CLASSPATH} = $dir;

my $ref_dir = catdir($dir,'custom_analysis','mapd','Homo_sapiens','1000Genomes_hs37d5');
`mkdir -p $ref_dir/{MappableBINS,chromosomes}`;
`touch $ref_dir/MappableBINS/Combined_Homo_sapiens_1000Genomes_hs37d5_100000_151bases_mappable_bins_GCperc_INPUT.txt`;
`touch $ref_dir/MappableBINS/Combined_Homo_sapiens_1000Genomes_hs37d5_100000_151bases_mappable_bins.bed`;
`touch $ref_dir/MappableBINS/Combined_Homo_sapiens_1000Genomes_hs37d5_500000_151bases_mappable_bins_GCperc_INPUT.txt`;
`touch $ref_dir/MappableBINS/Combined_Homo_sapiens_1000Genomes_hs37d5_500000_151bases_mappable_bins.bed`;
`touch $ref_dir/chromosomes/chr_list.txt`;

my $si = catfile($dir, 'samtools');
`touch $si`;
`chmod +x $si`;
open my $fh,  '>', $si;
print $fh q{#!/bin/bash}.qq{\n};
print $fh q{rpt_regex='([[:digit:]]+)_([[:digit:]]+)(_([[:alpha:]]+))?(#([[:digit:]]+))?(_([[:alpha:]]+))?'}.qq{\n};
print $fh q{while (( "$#" )); do}.qq{\n};
print $fh q{if [[ "$1" =~ $rpt_regex ]]; then bam=$1; break; }. qq{\n};
print $fh q{elif [[ "$1" = -H ]]; then print=header; }. qq{\n};
print $fh q{elif [[ "$1" = -c ]]; then print=count; }. qq{\n};
print $fh q{elif [[ "$1" = view ]]; then print=view; fi; shift; }. qq{\n};
print $fh q{done}.qq{\n};
print $fh q{if [ "$print" = "header" ]; then grep '@' $bam; }. qq{\n};
print $fh q{elif [ "$print" = "count" ]; then echo 100; }. qq{\n};
print $fh q{elif [ "$print" = "view" ]; then cat $bam; fi;}. qq{\n};
print $fh q{exit 0};
close $fh;

use_ok ('npg_qc::autoqc::checks::mapd');

subtest 'Create MAPD score check, find input files and create output dir' => sub {
    plan tests => 6;

    my $check = npg_qc::autoqc::checks::mapd->new(
        id_run => 27128,
        position => 1,
        tag_index => 1,
        repository => $dir,
        ref_repository => $ref_dir,
        path => $data_dir,
        read_length => 151,
        bin_size => 100000,
        qc_out => $dir,
    );

    isa_ok($check, 'npg_qc::autoqc::checks::mapd');

    is(basename($check->mappability_file),
        'Combined_Homo_sapiens_1000Genomes_hs37d5_100000_151bases_mappable_bins_GCperc_INPUT.txt',
        'finds mappability file');
    is(basename($check->mappability_bed_file),
        'Combined_Homo_sapiens_1000Genomes_hs37d5_100000_151bases_mappable_bins.bed',
        'finds mappability bed file');
    is(basename($check->chromosomes_file),
        'chr_list.txt',
        'finds chromosomes list file');
    is(basename($check->bam_file), '27128_1#1.cram',
        'finds input bam file');
    is($check->_mapd_output_dir, catdir($dir, '_MAPD_27128_1#1'),
        'sets output directory');
};

subtest 'Commands and R scripts' => sub {
    plan tests => 12;

    local $ENV{PATH} = join q[:], $dir, $ENV{PATH};

    my $coveragebed_bin = catfile($dir, 'coverageBed');
    my $rscript_bin = catfile($dir, 'Rscript');
    `touch $coveragebed_bin`;
    `touch $rscript_bin`;
    `chmod +x $coveragebed_bin`;
    `chmod +x $rscript_bin`;
    `mkdir -p $dir/rscripts`;

    my $logr_script = catfile($dir, 'rscripts', 'LogR.R');
    my $mapd_script = catfile($dir, 'rscripts', 'MAPD.R');
    `touch $logr_script`;
    `touch $mapd_script`;

    my $check = npg_qc::autoqc::checks::mapd->new(
        id_run => 27128,
        position => 1,
        tag_index => 2,
        repository => $dir,
        ref_repository => $ref_dir,
        path => $data_dir,
        bin_size => 500000,
        qc_out => $dir,
        _rscripts_path => catdir($dir, 'rscripts'),
    );

    # define read_length
    is($check->read_length,
        151,
        'gets read length');

    # Find appropriate files for a different bin size
    is(basename($check->mappability_file),
        'Combined_Homo_sapiens_1000Genomes_hs37d5_500000_151bases_mappable_bins_GCperc_INPUT.txt',
        'finds mappability file');
    is(basename($check->mappability_bed_file),
        'Combined_Homo_sapiens_1000Genomes_hs37d5_500000_151bases_mappable_bins.bed',
        'finds mappability bed file');

    # commands (some shortened for convenience)
    my $coveragebed_command = $check->coverageBed_cmd. ' -a - -b '. basename($check->mappable_bins_bed_file);
    is($coveragebed_command,
        "$dir/coverageBed -a - -b Combined_Homo_sapiens_1000Genomes_hs37d5_500000_151bases_mappable_bins.bed",
        'coverageBed command is correct');

    # Find R scripts home and files
    is($check->_rscripts_path,
        "$dir/rscripts",
        'finds rscripts path');
    is($check->_find_rscript('LogR.R'),
        $logr_script,
        'finds logR R script');
    is($check->_find_rscript('MAPD.R'),
        $mapd_script,
        'finds MAPD R script');

    # Generate Rscript commands and check outputs
    # LogR
    my $logr_cmd = "$dir/Rscript $dir/rscripts/LogR.R".
                   ' --mappable_bins '. $check->mappability_file.
                   ' --sample_bin_counts '. $check->_bin_counts_file.
                   ' --output_dir '. catdir($dir, '_MAPD_27128_1#2').
                   ' --rscripts_dir '. catdir($dir, 'rscripts').
                   ' --chromosomes '. $check->chromosomes_file.
                   ' --bin_size 500000'.
                   ' --sample_name 4884STDY7663261'.
                   ' --read_length 151'.
                   ' --gamma 25';
    is($check->_logr_cmd,
        $logr_cmd,
        'Rscript command for LogR script is correct');
    is(basename($check->_logr_segmentation_file),
        '4884STDY7663261-logr_segmentation-500000_151bases_25gamma.txt',
        'logR output filename is correct');
    # MAPD
    is($check->threshold,
        0.3,
        'threshold score for this species is correct');
    my $mapd_cmd = "$dir/Rscript $dir/rscripts/MAPD.R".
                   ' --logr_segmentation_file '. $check->_logr_segmentation_file.
                   ' --output_dir '. catdir($dir, '_MAPD_27128_1#2').
                   ' --chromosomes '. $check->chromosomes_file.
                   ' --threshold 0.3'.
                   ' --bin_size 500000'.
                   ' --sample_name 4884STDY7663261'.
                   ' --read_length 151';
    is($check->_mapd_cmd,
        $mapd_cmd,
        'Rscript command for MAPD script is correct');
    is(basename($check->_mapd_results_file),
        '4884STDY7663261-mapd_results-500000_151bases_0.3threshold.txt',
        'logR output filename is correct');
};

subtest 'Preprocess input data' => sub {
    plan tests => 4;

    my $check = npg_qc::autoqc::checks::mapd->new(
        id_run => 27128,
        position => 1,
        tag_index => 2,
        repository => $dir,
        ref_repository => $ref_dir,
        path => $data_dir,
        bin_size => 100000,
        qc_out => $dir,
        read_length => 151,
    );

    is(basename($check->bam_file),
        '27128_1#2.cram',
        'output counts file name is correct');
    is(basename($check->_bin_counts_file),
        '4884STDY7663261_100000_mappable_151bases.count',
        'finds input bam file');
    TODO: {
        todo_skip 'take too long to run: need tiny test data', 2 if 1;
        `mkdir -p $dir/_MAPD_27128_1\#2`;
        is($check->_generate_bin_counts,
            1272,
            'generate counts OK');
        lives_ok { $check->execute } 'execution ok';
    }

};

1;