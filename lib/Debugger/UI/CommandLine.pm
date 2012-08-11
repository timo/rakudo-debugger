module Debug::UI::CommandLine;

use Term::ANSIColor;

# The source code of the files we've encountred while debugging.
my %sources;

# Represents a file that we're debugging.
my class SourceFile {
    has $.filename;
    has $.source;
    has @!lines;
    has @!line_offsets;
    
    method BUILD(:$!filename, :$!source) {
        # Store (abbreviated if needed) lines.
        @!lines = lines($!source).map(*.subst("\r", "")).map(-> $l {
            $l.chars > 79 ?? $l.substr(0, 76) ~ '...' !! $l
        });
        
        # Calculate line offsets.
        for $!source.match(/^^ \N+ $$/, :g) -> $m {
            @!line_offsets.push($m.from);
        }
    }
    
    method line_of($pos) {
        for @!line_offsets.kv -> $l, $p {
            return $l - 1 if $p >= $pos;
        }
    }
    
    method summary_around($from, $to) {
        my $from_line = self.line_of($from);
        my $to_line = self.line_of($to);
        if $to_line - $from_line > 5 {
            $to_line = $from_line + 4;
            return colored(join("\n", @!lines[$from_line..$to_line]), 'black on_yellow');
        }
        else {
            my $ctx_start = $from_line - 2;
            $ctx_start = 0 if $from_line < 0;
            my $ctx_end = $to_line + 2;
            $ctx_end = +@!lines - 1 if $ctx_end >= @!lines;
            return
                @!lines[$ctx_start..^$from_line].join("\n") ~ "\n" ~
                colored(@!lines[$from_line..$to_line].join("\n"), 'bold yellow') ~ "\n" ~
                @!lines[$to_line^..$ctx_end].join("\n");
        }
    }
}

# Install various hooks.
$*DEBUG_HOOKS.set_hook('new_file', -> $filename, $source {
    say colored('>>> LOADING ', 'magenta') ~ $filename;
    %sources{$filename} = SourceFile.new(:$filename, :$source);
});
$*DEBUG_HOOKS.set_hook('statement_expr', -> $filename, $from, $to {
    say %sources{$filename}.summary_around($from, $to);
    prompt("> ");
});