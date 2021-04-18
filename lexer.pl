use strict;
require "./lib/utils.pm";

sub puts_token {
    my ($kind, $str) = @_;
    printf("%s:%s\n", $kind, $str);
}

sub tokenize {
    my ($src) = @_;
    my $pos = 0;
    my $rest = "";
    my $temp = "";

    while ($pos < length($src)) {
        $rest = substr($src, $pos);

        if ($rest =~ /^([ \n]+)/) {
            $temp = $1;
            $pos += length($temp);
        } elsif ($rest =~ /^(\/\/.*)/) {
            $temp = $1;
            $pos += length($temp);
        } elsif ($rest =~ /^"(.*)"/) {
            $temp = $1;
            puts_token("str", $temp);
            $pos += length($temp) + 2;
        } elsif ($rest =~ /^(func|set|var|call_set|call|return|case|while|_cmt)[^a-z_]/) {
            $temp = $1;
            puts_token("kw", $temp);
            $pos += length($temp);
        } elsif ($rest =~ /^(-?[0-9]+)/) {
            $temp = $1;
            puts_token("int", $temp);
            $pos += length($temp);
        } elsif ($rest =~ /^(==|!=|[(){}=;+*,])/) {
            $temp = $1;
            puts_token("sym", $temp);
            $pos += length($temp);
        } elsif ($rest =~ /^([a-z_][a-z0-9_]*)/) {
            $temp = $1;
            puts_token("ident", $temp);
            $pos += length($temp);
        } else {
            die;
        }
    }
}

my $src = Utils::read_stdin_all();
tokenize($src);
