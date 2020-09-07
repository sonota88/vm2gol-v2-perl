package Json;

use strict;
use warnings;
use Data::Dumper;

require "./lib/utils.pm";
require "./lib/val.pm";

sub puts_e {
    my ($msg) = @_;
    # STDERR->print($msg . "\n");
}

sub p_e {
    # STDERR->print(Dumper @_);
}

sub ival {
    my $str = shift;
    return Val::new("int", $str);
}

sub sval {
    my $str = shift;
    return Val::new("str", $str);
}

sub _parse {
    my ($json) = @_;
    puts_e("_parse");

    my $pos = 1;
    my $xs = [];
    my $xs_i = 0;

    while ($pos < length($json)) {
        my $rest = substr($json, $pos);
        if ($rest =~ /^\[/) {
            my ($nl, $size) = _parse($rest);
            $xs->[$xs_i] = $nl; $xs_i++;
            $pos += $size + 1;
        } elsif ($rest =~ /^\]/) {
            $pos++;
            last;
        } elsif ($rest =~ /^[ ,\n]/) {
            $pos++;
        } elsif ($rest =~ /^(-?[0-9]+)/) {
            my $str = $1;
            $xs->[$xs_i] = ival($str); $xs_i++;
            $pos += length($str) ;
        } elsif ($rest =~ /^"(.*?)"/) {
            my $str = $1;
            $xs->[$xs_i] = sval($str); $xs_i++;
            $pos += length($str) + 2;
        } else {
            die;
        }
    }

    return ($xs, $pos);
}

sub parse {
    my ($json) = @_;
    my ($xs, $size) = _parse($json);
    return $xs;
}

sub print_indent {
    my ($lv) = @_;
    my $i;
    for ($i=0; $i<$lv; $i++) {
        print("  ");
    }
}

sub _print_as_json {
    my ($tree, $lv) = @_;
    my $LF = "\n";

    print_indent($lv);
    print("[", $LF);

    my $i;
    my $el;
    for ($i = 0; $i < Utils::arr_size($tree); $i++) {
        $el = $tree->[$i];
        if (Utils::is_arr($el)) {
            _print_as_json($el, $lv + 1);
        } elsif (Val::is_int($el)) {
            my $s = $el->{"val"};
            print_indent($lv + 1);
            print($s);
        } elsif (Val::is_str($el)) {
            my $s = $el->{"val"};
            print_indent($lv + 1);
            print('"', $s, '"');
        } else {
            die;
        }
        if ($i < Utils::arr_size($tree) - 1) {
            print(",");
        }
        print($LF);
    }

    if (Utils::arr_size($tree) == 0) {
        print($LF);
    }

    print_indent($lv);
    print("]");
}

sub print_as_json {
    my (@tree) = @_;
    _print_as_json(@tree, 0);
    print("\n");
}

sub list_to_json_line {
    my $list = shift;

    my $json = "[";

    my $i = -1;
    for my $it (@$list) {
        $i++;
        if (1 <= $i) {
            $json = $json . ", ";
        }

        if (Val::kind_eq($it, "int")) {
            $json = $json . $it->{"val"};

        } elsif (Val::kind_eq($it, "str")) {
            $json = $json . '"' . $it->{"val"} . '"';
            
        } else {
            die;
        }
    }

    $json = $json . "]";

    return $json;
}

1;
