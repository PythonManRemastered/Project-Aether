unit module Aether;

use Parser;
use Runtime;

sub run-aether(Str $source, Bool :$strict = False) is export {

    my $parser = Parser.new;

    my $program = $parser.parse($source);

    my $runtime = Runtime.new;

    $runtime.execute($program);

    '';
    
}