unit class Runtime;

use AST;

has %!vars;

method execute(AST::Program $program) {

    for $program.statements -> $stmt {

        given $stmt {

            when AST::OutputStatement {

                my $value =
                    self!evaluate(
                        $stmt.values[0]
                    );

                say $value;
            }

            when AST::InputStatement {

                my $answer = prompt("");

                %!vars{$stmt.name}
                    = $answer;
            }

            when AST::AssignmentStatement {

                %!vars{$stmt.name}
                    =
                    self!evaluate(
                        $stmt.expression
                    );
            }
        }
    }
}

method !evaluate($expr) {

    my $text = $expr.Str.trim;

    if $text.starts-with('"')
    && $text.ends-with('"') {

        return $text.substr(
            1,
            $text.chars - 2
        );
    }

    if $text ~~ /^\d+$/ {

        return $text.Int;
    }

    if %!vars{$text}:exists {

        return %!vars{$text};
    }

    return $text;
    
}