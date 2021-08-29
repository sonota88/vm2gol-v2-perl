use strict;
require "./lib/utils.pm";

my @KEYWORDS = (
  "func", "set", "var", "call_set", "call", "return", "case", "while",
  "_cmt", "_debug"
);

sub is_kw {
    my ($str) = @_;

    return grep {$_ eq $str} @KEYWORDS;
}

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
            my $kind;
            if (is_kw($temp)) {
                $kind = "kw";
            } else {
                $kind = "ident";
            }
            puts_token($kind, $temp);
            $pos += length($temp);
        } else {
            die;
        }
    }
}

my $src = Utils::read_stdin_all();
tokenize($src);
