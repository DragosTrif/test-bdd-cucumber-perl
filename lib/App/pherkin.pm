package App::pherkin;

use strict;
use warnings;
use FindBin::libs;
use Getopt::Long;
use Data::Dumper;

use Moose;
has 'tags' => ( is => 'rw', isa => 'ArrayRef', required => 0 );
has 'tag_scheme' => ( is => 'rw', isa => 'ArrayRef', required => 0 );

=head1 NAME

App::pherkin - Run Cucumber tests from the command line

=head1 SYNOPSIS

 pherkin
 pherkin some/path/features/

=head1 DESCRIPTION

C<pherkin> will search the directory specified (or C<./features/>) for
feature files (any file matching C<*.feature>) and step definition files (any
file matching C<*_steps.pl>), loading the step definitions and then executing
the features.

Steps that pass will be printed in green, those that fail in red, and those
for which there is no step definition as yellow (for TODO).

=cut

use Test::BDD::Cucumber::Loader;
use Test::BDD::Cucumber::Harness::TermColor;

=head1 METHODS

=head2 run

The C<App::pherkin> class, which is what the C<pherkin> command uses, makes
use of the C<run()> method, which accepts currently a single path as a string,
or nothing.

Returns a L<Test::BDD::Cucumber::Model::Result> object for all steps run.

=cut

sub run {
    my ( $self, @arguments ) = @_;

    @arguments = $self->_process_arguments(@arguments);

    my ( $executor, @features ) = Test::BDD::Cucumber::Loader->load(
        $arguments[0] || './features/', $self->tag_scheme
    );
    die "No feature files found" unless @features;

    my $harness  = Test::BDD::Cucumber::Harness::TermColor->new();
    $executor->execute( $_, $harness ) for @features;

    return $harness->result;
}

sub _process_arguments {
    my ( $self, @args ) = @_;
    local @ARGV = @args;

    # Allow -Ilib, -bl
    Getopt::Long::Configure('bundling');

    my $includes = [];
    my $tags = [];
    GetOptions(
        'I=s@'   => \$includes,
        'l|lib'  => \(my $add_lib),
        'b|blib' => \(my $add_blib),
        't|tags=s@' => \$tags,
    );
    unshift @$includes, 'lib'                   if $add_lib;
    unshift @$includes, 'blib/lib', 'blib/arch' if $add_blib;

    lib->import(@$includes) if @$includes;

    my $tag_scheme = [];
    my @ands = ();
    foreach my $tag (@{$tags}) {
        my @parts = ();
        foreach my $part (split(',', $tag)) {
            $part =~ s/^(~?)@//;
            if ($1 eq '~') {
                push @parts, [ not => $part ];
            } else {
                push @parts, $part;
            }
        }
        if (scalar @parts > 1) {
            push @ands, [ or => @parts ];
        } else {
            push @ands, @parts;
        }
    }
    $tag_scheme = [ and => @ands ];
    $self->tag_scheme($tag_scheme);

    return @ARGV;
}

=head1 AUTHOR

Peter Sergeant C<pete@clueball.com>

=head1 LICENSE

Copyright 2011, Peter Sergeant; Licensed under the same terms as Perl

=cut

1;
