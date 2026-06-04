unit class Parser;

use AST;

method parse(Str $source) {

    my @statements;

  for $source.lines -> $raw-line {
        
        my $line = $raw-line.trim;

        next if $line eq '';

        if $line.starts-with('OUTPUT ') {

            my $value = $line.substr(7);

            @statements.push(
                AST::OutputStatement.new(
                    values => [$value]
                )
            );

            next;
        }

        if $line.starts-with('INPUT ') {

            my $name = $line.substr(6).trim;

            @statements.push(
                AST::InputStatement.new(
                    name => $name
                )
            );

            next;
        }

        if $line.contains('←') {

            my ($name,$expr)
                = $line.split('←',2);

            @statements.push(
                AST::AssignmentStatement.new(
                    name => $name.trim,
                    expression => $expr.trim
                )
            );

            next;
        }

        die "Unknown statement: $line";
    }

    AST::Program.new(
        statements => @statements
    );
    
}

