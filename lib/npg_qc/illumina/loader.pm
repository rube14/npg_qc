package npg_qc::illumina::loader;

use Moose;
use namespace::autoclean;
use Carp;
use Readonly;
use Module::Pluggable::Object;
with qw{MooseX::AttributeCloner MooseX::Getopt};
extends qw{npg_qc::illumina::loader::base};

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::illumina::loader

=head1 SYNOPSIS

  npg_qc::illumina::loader->new(id_run => $iIdRun)->run();
  npg_qc::illumina::loader->new(run_folder => $sRunFolder)->run();
  npg_qc::illumina::loader->new()->run_all();

=head1 DESCRIPTION

 Illumina analysis data loader 

=cut

Readonly::Array  my @LOADER_MODULES => qw/
                                  Runinfo
                                  Recipe
                                  Bustard_Summary
                                  Signal_Mean
                                  Matrix
                                  Run_Caching
                                        /;

Readonly::Array  my @PRELOADER_MODULES => qw/
                                  Run_Caching
                                  Recipe
                                  Runinfo
                                  Cluster_Density
                                           /;

=head1 SUBROUTINES/METHODS

=head2 BUILD

 Loads into memory plugins - individual per-table loaders

=cut

sub BUILD {
  Module::Pluggable::Object->new(
    require     => 1,
    search_path => __PACKAGE__,
    except      => [ __PACKAGE__ . q[::base] ]
                                )->plugins;
  return;
}

=head2 run

 Loads one run Illumina analysis statistics to a database

=cut

sub run {
  my ($self) = @_;

  $self->mlog(q{Loading Illimina Analysis Data for Run } . $self->id_run() . q{ into QC database});

  my $schema = $self->schema(); #ensure the same connection is used

  foreach my $mod (@LOADER_MODULES) {
    my $m = join q[::], __PACKAGE__ , $mod;
    $self->mlog(qq{***** Calling $m *****});
    if ($mod ne q{Run_Caching}) {
      $self->new_with_cloned_attributes($m)->run();
    } else {
      $m->new(schema => $self->schema)->cache_run($self->id_run, $self->is_paired_read);
    }
  }
  $self->mlog(q{All QC data loading finished for run }.$self->id_run());
  return;
}

=head2 run_all

 Loads Illumina analysis statistics for all eligible runs to a database

=cut

sub run_all {
  my $self = shift;

  $self->mlog(q{Loading Illimina Analysis Data});
  my $ref = {'schema' => $self->schema,
             'schema_npg_tracking' => $self->schema_npg_tracking,};
  foreach my $mod (@PRELOADER_MODULES) {
    my $m = join q[::], __PACKAGE__ , $mod;
    $self->mlog(qq{***** Calling $m *****});
    $m->new($ref)->run_all();
  }
  return;
}

=head2 lane_summary_saved

 Returns true if per-end lane summary has been saved to the
 cache_query table, false otherwise.

=cut

sub lane_summary_saved {
  my $self = shift;

  if (!$self->id_run) {
    croak 'id_run should be set';
  }
  my @ends = $self->is_paired_read ? qw/ 1 2 /: qw/ 1 /;
  my $where = {
          id_run     => $self->id_run,
          is_current => 1,
          type       => 'lane_summary',
  };
  my $count = 0;
  foreach my $end (@ends) {
    $where->{'end'} = $end;
    $count += $self->schema->resultset('CacheQuery')->search($where)->count;
  }
  return $count >= scalar @ends;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Carp

=item Readonly

=item MooseX::Getopt

=item MooseX::AttributeCloner

=item Module::Pluggable::Object

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
