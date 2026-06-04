unit class Runtime;

use AetherAST;

has %!vars;

method execute(AetherAST::Program $program) {

    for $program.statements -> $stmt {

        given $stmt {

            when AetherAST::OutputStatement {

                my $value =
                    self!evaluate(
                        $stmt.values[0]
                    );

                say $value;
            }

            when AetherAST::InputStatement {

                my $answer = prompt("");

                %!vars{$stmt.name}
                    = $answer;
            }

            when AetherAST::AssignmentStatement {

                %!vars{$stmt.name}
                    =
                    self!evaluate(
                        $stmt.expression
                    );
            }

            when AetherAST::IfStatement {

                if self!evaluate(
                    $stmt.condition
                ) {

                    my $program =
                        AetherAST::Program.new(
                            statements =>
                            $stmt.thenBlock
                        );

                    self.execute(
                        $program
                    );
                }
                else {

                    my $program =
                        AetherAST::Program.new(
                            statements =>
                            $stmt.elseBlock
                        );

                    self.execute(
                        $program
                    );
                }
            }

        }
    }
}

method !evaluate($expr) {

    my $text = $expr.Str.trim;

    if $text.contains(">") {

        my ($left,$right)
            = $text.split(">",2);

        return
            self!evaluate($left)
            >
            self!evaluate($right);
    }

    if $text.contains("<") {

        my ($left,$right)
            = $text.split("<",2);

        return
            self!evaluate($left)
            <
            self!evaluate($right);
    }

    if $text.contains("=") {

        my ($left,$right)
            = $text.split("=",2);

        return
            self!evaluate($left)
            eq
            self!evaluate($right);
    }

    if $text.starts-with('"')
    && $text.ends-with('"') {

        return $text.substr(
            1,
            $text.chars - 2
        );
    }

    if $text ~~ /^ \d+ $/ {

        return $text.Int;
    }

    if %!vars{$text}:exists {

        return %!vars{$text};
    }

    return $text;
}