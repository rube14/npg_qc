#########
# Author:        Ruben Bautista
# Created:       2015-08-13
#

package npg_qc::autoqc::results::rna_seqc;

use Moose;
use namespace::autoclean;

extends qw(npg_qc::autoqc::results::result);

our $VERSION = '0';

=head1 NAME

npg_qc::autoqc::results::rna_seqc

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 sample

Sample ID. sample name or library

=cut

has 'sample' => (isa        => 'Maybe[Num]',
                 is         => 'rw',
                 required   => 0,);

has 'note' => (isa        => 'Maybe[Num]',
               is         => 'rw',
               required   => 0,);

has 'total_purity_filtered_reads_sequenced' => (isa        => 'Maybe[Num]',
                                                is         => 'rw',
                                                required   => 0,);

has 'alternative_aligments' => (isa        => 'Maybe[Num]',
                                is         => 'rw',
                                required   => 0,);

has 'failed_vendor_qc_check' => (isa        => 'Maybe[Num]',
                                 is         => 'rw',
                                 required   => 0,);

has 'read_length' => (isa        => 'Maybe[Num]',
                      is         => 'rw',
                      required   => 0,);

has 'estimated_library_size' => (isa        => 'Maybe[Num]',
                                 is         => 'rw',
                                 required   => 0,);


has 'mapped' => (isa        => 'Maybe[Num]',
                 is         => 'rw',
                 required   => 0,);

has 'mapping_rate' => (isa        => 'Maybe[Num]',
                       is         => 'rw',
                       required   => 0,);

has 'mapped_unique' => (isa        => 'Maybe[Num]',
                        is         => 'rw',
                        required   => 0,);

has 'mapped_unique_rate_of_total' => (isa        => 'Maybe[Num]',
                                      is         => 'rw',
                                      required   => 0,);

has 'unique_rate_of_mapped' => (isa        => 'Maybe[Num]',
                                is         => 'rw',
                                required   => 0,);

has 'duplication_rate_of_mapped' => (isa        => 'Maybe[Num]',
                                     is         => 'rw',
                                     required   => 0,);

has 'base_mismatch_rate' => (isa        => 'Maybe[Num]',
                             is         => 'rw',
                             required   => 0,);

has 'rrna' => (isa        => 'Maybe[Num]',
               is         => 'rw',
               required   => 0,);

has 'rrna_rate' => (isa        => 'Maybe[Num]',
                    is         => 'rw',
                    required   => 0,);

has 'mapped_pairs' => (isa        => 'Maybe[Num]',
                       is         => 'rw',
                       required   => 0,);

has 'unpaired_reads' => (isa        => 'Maybe[Num]',
                         is         => 'rw',
                         required   => 0,);

has 'end_1_mapping_rate' => (isa        => 'Maybe[Num]',
                             is         => 'rw',
                             required   => 0,);

has 'end_2_mapping_rate' => (isa        => 'Maybe[Num]',
                             is         => 'rw',
                             required   => 0,);

has 'end_1_mismatch_rate' => (isa        => 'Maybe[Num]',
                              is         => 'rw',
                              required   => 0,);

has 'end_2_mismatch_rate' => (isa        => 'Maybe[Num]',
                              is         => 'rw',
                              required   => 0,);

has 'fragment_length_mean' => (isa        => 'Maybe[Num]',
                               is         => 'rw',
                               required   => 0,);

has 'fragment_length_stdev' => (isa        => 'Maybe[Num]',
                                 is         => 'rw',
                                 required   => 0,);

has 'chimeric_pairs' => (isa        => 'Maybe[Num]',
                         is         => 'rw',
                         required   => 0,);

has 'intragenic_rate' => (isa        => 'Maybe[Num]',
                          is         => 'rw',
                          required   => 0,);

has 'exonic_rate' => (isa        => 'Maybe[Num]',
                      is         => 'rw',
                      required   => 0,);

has 'intronic_rate' => (isa        => 'Maybe[Num]',
                        is         => 'rw',
                        required   => 0,);

has 'intergenic_rate' => (isa        => 'Maybe[Num]',
                          is         => 'rw',
                          required   => 0,);

has 'split_reads' => (isa        => 'Maybe[Num]',
                      is         => 'rw',
                      required   => 0,);

has 'expression_profiling_efficiency' => (isa        => 'Maybe[Num]',
                                          is         => 'rw',
                                          required   => 0,);

has 'transcripts_detected' => (isa        => 'Maybe[Num]',
                               is         => 'rw',
                               required   => 0,);

has 'genes_detected' => (isa        => 'Maybe[Num]',
                         is         => 'rw',
                         required   => 0,);

has 'end_1_sense' => (isa        => 'Maybe[Num]',
                      is         => 'rw',
                      required   => 0,);

has 'end_1_antisense' => (isa        => 'Maybe[Num]',
                          is         => 'rw',
                          required   => 0,);

has 'end_2_sense' => (isa        => 'Maybe[Num]',
                      is         => 'rw',
                      required   => 0,);

has 'end_2_antisense' => (isa        => 'Maybe[Num]',
                          is         => 'rw',
                          required   => 0,);

has 'end_1_pct_sense' => (isa        => 'Maybe[Num]',
                          is         => 'rw',
                          required   => 0,);

has 'end_2_pct_sense' => (isa        => 'Maybe[Num]',
                          is         => 'rw',
                          required   => 0,);

has 'mean_per_base_cov' => (isa        => 'Maybe[Num]',
                             is         => 'rw',
                             required   => 0,);

has 'mean_cv' => (isa        => 'Maybe[Num]',
                  is         => 'rw',
                  required   => 0,);

has 'num_covered_5_end' => (isa        => 'Maybe[Num]',
                            is         => 'rw',
                            required   => 0,);

has 'end_5_norm' => (isa        => 'Maybe[Num]',
                     is         => 'rw',
                     required   => 0,);

has 'end_3_norm' => (isa        => 'Maybe[Num]',
                     is         => 'rw',
                     required   => 0,);

has 'num_gaps' => (isa        => 'Maybe[Num]',
                   is         => 'rw',
                   required   => 0,);

has 'cumul_gap_length' => (isa        => 'Maybe[Num]',
                           is         => 'rw',
                           required   => 0,);

has 'gap_pct' => (isa        => 'Maybe[Num]',
                  is         => 'rw',
                  required   => 0,);

has 'other_metrics'  => (isa        => 'HashRef',
                         is         => 'rw',
                         required   => 0,);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

  npg_qc::autoqc::results::rna_seqc

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_qc::autoqc::results::result

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Ruben E Bautista-Garcia<lt>rb11@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Limited

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut