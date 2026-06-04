unit class Parser;

use AetherAST;

method parse(Str $source) {

    my @statements;

    my @lines = $source.lines;

    my $i = 0;

    while $i < @lines.elems {

        my $line = @lines[$i].trim;

        # Ignore blank lines

        if $line eq '' {
            $i++;
            next;
        }

        # -------------------------
        # IF statement
        # -------------------------

        if $line.starts-with('IF ') {

            my $condition =
                $line.substr(3).trim;

            my @thenBlock;
            my @elseBlock;

            my $inElse = False;

            loop {

                $i++;

                die "Missing ENDIF"
                    if $i >= @lines.elems;

                my $next =
                    @lines[$i].trim;

                if $next eq 'THEN' {
                    next;
                }

                if $next eq 'ELSE' {
                    $inElse = True;
                    next;
                }

                if $next eq 'ENDIF' {
                    last;
                }

                my $parsed = self.parse($next);

                my $stmt = $parsed.statements.[0];

                if $inElse {
                    @elseBlock.push($stmt);
                }
                else {
                    @thenBlock.push($stmt);
                }
            }

            @statements.push(
                AetherAST::IfStatement.new(
                    condition => $condition,
                    thenBlock => @thenBlock,
                    elseBlock => @elseBlock
                )
            );

            $i++;
            next;
        }

        # -------------------------
        # OUTPUT
        # -------------------------

        if $line.starts-with('OUTPUT ') {

            my $value =
                $line.substr(7).trim;

            @statements.push(
                AetherAST::OutputStatement.new(
                    values => [$value]
                )
            );

            $i++;
            next;
        }

        # -------------------------
        # INPUT
        # -------------------------

        if $line.starts-with('INPUT ') {

            my $name =
                $line.substr(6).trim;

            @statements.push(
                AetherAST::InputStatement.new(
                    name => $name
                )
            );

            $i++;
            next;
        }

        # -------------------------
        # Assignment
        # -------------------------

        if $line.contains('←') {

            my ($name, $expr) =
                $line.split('←', 2);

            @statements.push(
                AetherAST::AssignmentStatement.new(
                    name => $name.trim,
                    expression => $expr.trim
                )
            );

            $i++;
            next;
        }

        die "Unknown statement: $line";
    }

    AetherAST::Program.new(
        statements => @statements
    );
}