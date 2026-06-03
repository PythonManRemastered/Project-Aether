unit module Aether;

# Aether v0.1 prototype
# Core ideas implemented here:
# - tolerant keyword matching (small deterministic synonym + typo layer)
# - natural-language-ish output and assignment statements
# - a tiny dialect mechanism that can extend synonyms per project
#
# This is intentionally conservative: it is a runnable subset, not the full
# language vision from the spec.

constant VERSION = '0.1.0';

my %DEFAULT-SYNONYMS = (
    print  => <say display show write output tell log echo>,
    let    => <set assign define make put store>,
    const  => <constant immutable fixed always>,
    if     => <when whenever provided should assuming given>,
    return => <giveback yield>,
);

sub build-synonym-index(%groups --> Hash) {
    my %index;
    for %groups.kv -> $canonical, @alts {
        %index{$canonical.lc} = $canonical.lc;
        for @alts -> $alt {
            %index{$alt.lc} = $canonical.lc;
        }
    }
    %index
}

my %CORE-INDEX = build-synonym-index(%DEFAULT-SYNONYMS);

sub levenshtein(Str $a, Str $b --> Int) {
    my @left  = $a.comb;
    my @right = $b.comb;

    my @prev = 0 .. @right.elems;

    for @left.kv -> $i, $ca {
        my @curr;
        @curr.push($i + 1);

        for @right.kv -> $j, $cb {
            my $cost = $ca eq $cb ?? 0 !! 1;
            my $insert = @curr[*-1] + 1;
            my $delete = @prev[$j + 1] + 1;
            my $substitute = @prev[$j] + $cost;
            @curr.push(($insert, $delete, $substitute).min);
        }

        @prev = @curr;
    }

    @prev[*-1]
}

class Aether::Dialect {
    has Str $.name = 'core';
    has %!synonyms;

    submethod BUILD() {
        %!synonyms = %CORE-INDEX;
    }

    method add-synonym(Str $synonym, Str $canonical) {
        %!synonyms{$synonym.lc} = $canonical.lc;
    }

    method resolve(Str $word, Bool :$strict = False --> Str) {
        my $key = $word.lc;

        if %!synonyms{$key}:exists {
            return %!synonyms{$key};
        }

        return $word if $strict;

        my $best = '';
        my $best-distance = 999;

        for %!synonyms.keys -> $candidate {
            my $distance = levenshtein($key, $candidate);
            if $distance < $best-distance {
                $best-distance = $distance;
                $best = $candidate;
            }
        }

        return $best-distance <= 2 ?? %!synonyms{$best} !! $word;
    }
}

class Aether::Runtime {
    has Bool $.strict = False;
    has Aether::Dialect $!dialect = Aether::Dialect.new(name => 'core');
    has %!vars;
    has Bool $!in-dialect = False;
    has @!output;

    method run(Str $source --> Str) {
        @!output = ();
        %!vars = ();
        $!in-dialect = False;

        for $source.lines -> $line {
            self!handle-line($line);
        }

        @!output.join("\n")
    }

    method !emit($value) {
        @!output.push($value.Str);
    }

    method !handle-line(Str $raw-line) {
        my $line = $raw-line.trim;
        return if $line eq '';
        return if $line.starts-with('--');

        if $!in-dialect {
            if $line.lc eq 'end' {
                $!in-dialect = False;
                return;
            }

            my @parts = $line.words;
            if @parts.elems >= 4 && @parts[0].lc eq 'synonym' && @parts[2].lc eq 'means' {
                $!dialect.add-synonym(@parts[1], @parts[3]);
                return;
            }

            if @parts.elems >= 4 && @parts[0].lc eq 'synonym' && @parts[2] eq '=' {
                $!dialect.add-synonym(@parts[1], @parts[3]);
                return;
            }

            return;
        }

        if $line.lc.starts-with('dialect ') && $line.ends-with(':') {
            $!in-dialect = True;
            return;
        }

        if $line.lc.starts-with('write to screen') {
            my $expr = $line.substr('write to screen'.chars).trim;
            $expr = $expr.substr(1).trim if $expr.starts-with(':');
            self!emit(self!eval-expression($expr));
            return;
        }

        my @parts = $line.split(/\s+/, 2);
        my $first = @parts[0].lc;
        my $cmd = $!dialect.resolve($first, :strict($!strict));

        if $cmd eq 'print' {
            my $expr = @parts.elems > 1 ?? @parts[1] !! '';
            self!emit(self!eval-expression($expr));
            return;
        }

        if $cmd eq 'let' || $cmd eq 'const' {
            my $rest = @parts.elems > 1 ?? @parts[1].trim !! '';
            if $rest eq '' {
                return;
            }

            my @bits = $rest.split(/\s+/, 2);
            my $name = @bits[0];
            my $expr = @bits.elems > 1 ?? @bits[1].trim !! '';

            $expr = $expr.substr(2).trim if $expr.lc.starts-with('be ');
            $expr = $expr.substr(2).trim if $expr.lc.starts-with('to ');
            $expr = $expr.substr(2).trim if $expr.lc.starts-with('as ');
            $expr = $expr.substr(1).trim if $expr.starts-with('=');

            if $expr.index(':').defined && $expr.index(':') > 0 && $expr ~~ /^ \w+ ':' / {
                $expr = $expr.substr($expr.index(':') + 1).trim;
            }

            %!vars{$name} = self!eval-expression($expr);
            return;
        }

        if $line ~~ /^ \h* (\w+) \h* '=' \h* (.+) $/ {
            my $name = ~$0;
            my $expr = ~$1;
            %!vars{$name} = self!eval-expression($expr);
            return;
        }

        # Unknown statement: keep the prototype forgiving, but don't crash.
        note "Aether warning: ignored line -> $line";
    }

    method !eval-expression(Str $expr) {
        my $s = $expr.trim;
        return '' if $s eq '';

        # Remove optional type annotations such as `integer: 42`.
        $s = self!strip-type-prefix($s);

        if $s.starts-with("'") && $s.ends-with("'") && $s.chars >= 2 {
            return $s.substr(1, $s.chars - 2);
        }

        if $s.starts-with('"') && $s.ends-with('"') && $s.chars >= 2 {
            return $s.substr(1, $s.chars - 2);
        }

        if $s ~~ /^ '-'? \d+ [ '.' \d+ ]? $/ {
            return $s.Numeric;
        }

        if %!vars{$s}:exists {
            return %!vars{$s};
        }

        for 'joined with', 'divided by', 'times', 'plus', 'minus' -> $op {
            my $pos = $s.lc.index($op);

            next unless $pos.defined;

            my $left = $s.substr(0, $pos).trim;
            my $right = $s.substr($pos + $op.chars).trim;

            my $a = self!eval-expression($left);
            my $b = self!eval-expression($right);

            return self!apply-op($op, $a, $b);
        }

        return $s;
    }

    method !apply-op(Str $op, $a, $b) {
        given $op {
            when 'joined with' {
                return ~$a ~ ~$b;
            }
            when 'plus' {
                return +$a + +$b;
            }
            when 'minus' {
                return +$a - +$b;
            }
            when 'times' {
                return +$a * +$b;
            }
            when 'divided by' {
                return +$a / +$b;
            }
            default {
                return $b;
            }
        }
    }

    method !strip-type-prefix(Str $text --> Str) {
        my $s = $text.trim;
        if $s ~~ /^ \w+ ':' \h* (.+) $/ {
            return ~$0.trim;
        }
        return $s;
    }
}

sub run-aether(Str $source, Bool :$strict = False --> Str) is export {
    Aether::Runtime.new(:$strict).run($source)
}

sub run-file(Str $path, Bool :$strict = False --> Str) is export {
    run-aether(slurp($path), :$strict)
}
