unit module Aether;

use Parser;
use Runtime;
use FuzzyResolver; 
sub run-aether(
    Str $source,
    Bool :$strict = False
) is export {

    my $processed = $source;

    unless $strict {

        $processed =
            FuzzyResolver.new
                .normalize($source);
    }

    my $parser = Parser.new;

    my $program =
        $parser.parse($processed);

    my $runtime = Runtime.new;

    $runtime.execute($program);

    '';
}