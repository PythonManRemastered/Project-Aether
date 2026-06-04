unit class FuzzyResolver;

sub levenshtein(Str $a, Str $b --> Int) {

    my @left = $a.comb;
    my @right = $b.comb;

    my @prev = 0 .. @right.elems;

    for @left.kv -> $i, $ca {

        my @curr;
        @curr.push($i + 1);

        for @right.kv -> $j, $cb {

            my $cost =
                $ca eq $cb ?? 0 !! 1;

            @curr.push(
                (
                    @curr[*-1] + 1,
                    @prev[$j + 1] + 1,
                    @prev[$j] + $cost
                ).min
            );
        }

        @prev = @curr;
    }

    @prev[*-1];
}

my %KEYWORD-GROUPS = (

    OUTPUT => <
        output
        print
        say
        show
        display
        echo
        write
        tell
        log
    >,

    INPUT => <
        input
        read
        receive
        get
        ask
        fetch
    >,

    IF => <
        if
        when
        whenever
        provided
        assuming
        given
    >,

    THEN => <
        then
    >,

    ELSE => <
        else
        otherwise
    >,

    ENDIF => <
        endif
        end-if
    >,

    WHILE => <
        while
        whilst
    >,

    DO => <
        do
    >,

    ENDWHILE => <
        endwhile
        end-while
    >,

    FOR => <
        for
        foreach
        each
    >,

    TO => <
        to
    >,

    STEP => <
        step
    >,

    NEXT => <
        next
    >,

    REPEAT => <
        repeat
        loop
        retry
    >,

    UNTIL => <
        until
    >
);

sub build-index() {

    my %index;

    for %KEYWORD-GROUPS.kv
    -> $canonical, $words {

    %index{$canonical.lc}
        = $canonical;

    for $words.list -> $word {

        %index{$word.lc}
            = $canonical;
    }
}

    %index;
}

my %INDEX = build-index();

sub all-synonyms() {

    my @list;

    for %INDEX.keys -> $word {
        @list.push($word);
    }

    @list;
}

method !closest(Str $word) {

    my $key =
        $word.lc;

    # Exact synonym match

    if %INDEX{$key}:exists {

        return %INDEX{$key};
    }

    # Fuzzy match against all known synonyms

    my $best-word = '';
    my $best-distance = 999;

    for all-synonyms() -> $candidate {

        my $distance =
            levenshtein(
                $key,
                $candidate
            );

        if $distance < $best-distance {

            $best-distance =
                $distance;

            $best-word =
                $candidate;
        }
    }

    if $best-distance <= 2 {

        return %INDEX{$best-word};
    }

    return $word;
}

method normalize(Str $source --> Str) {

    my @out;

    for $source.lines -> $raw-line {

        my $line = $raw-line;

        if $line ~~ /^ (\s*) (\S+) (.*) $/ {

            my $indent =
                ~$0;

            my $first =
                ~$1;

            my $rest =
                ~$2;

            my $fixed =
                self!closest($first);

            $line =
                $indent
                ~ $fixed
                ~ $rest;
        }

        @out.push($line);
    }

    @out.join("\n");
}