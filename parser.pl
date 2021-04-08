use strict;
use warnings;

use Data::Dumper;
require "./lib/utils.pm";
require "./lib/json.pm";
require "./lib/token.pm";
require "./lib/val.pm";

# --------------------------------

our $tokens = [];
our $pos = 0;

# --------------------------------

sub puts_e {
    my ($msg) = @_;
    STDERR->print($msg . "\n");
}

sub p_e {
    STDERR->print(Dumper @_);
}

sub puts_fn {
    my $msg = shift;
    # STDERR->print("    |-->> " . $msg . "()\n");
}

# --------------------------------

sub ival {
    my $str = shift;
    return Val::new("int", $str);
}

sub sval {
    my $str = shift;
    return Val::new("str", $str);
}

sub is_end {
    if (Utils::arr_size($tokens) <= $pos) {
        return 1;
    } else {
        return 0;
    }
}

sub peek {
    my $offset = shift;
    return $tokens->[$pos + $offset];
}

sub assert_value {
    my $kind = shift;
    my $str = shift;

    my $t = peek(0);

    unless (Token::kind_eq($t, $kind)) {
        puts_e("pos ($pos)");
        puts_e("expected ($kind) ($str)");
        puts_e("actual   (" . $t->{"kind"} . ") (" . $t->{"str"} . ")");
        die "Unexpected kind";
    }

    unless (Token::str_eq($t, $str)) {
        die "Unexpected str";
    }
}

sub consume_kw {
    my $str = shift;

    assert_value("kw", $str);
    $pos++;
}

sub consume_sym {
    my $str = shift;

    assert_value("sym", $str);
    $pos++;
}

# --------------------------------

sub parse_arg {
    # puts_fn("parse_arg");

    my $t = peek(0);

    if (Token::kind_eq($t, "int")) {
        $pos++;
        return ival($t->{"str"});
    } elsif (Token::kind_eq($t, "ident")) {
        $pos++;
        return sval($t->{"str"});
    } else {
        die;
    }
}

sub parse_args_first {
    # puts_fn("parse_args_first");

    my $t = peek(0);

    if (Token::is($t, "sym", ")")) {
        return 0;
    }

    return parse_arg();
}

sub parse_args_rest {
    # puts_fn("parse_args_rest");

    my $t = peek(0);

    if (Token::is($t, "sym", ")")) {
        return 0;
    }

    consume_sym(",");

    return parse_arg();
}

sub parse_args {
    puts_fn("parse_args");

    my $args = [];

    my $first_arg = parse_args_first();
    unless ($first_arg) {
        return $args;
    }
    push(@$args, $first_arg);

    while (1) {
        my $rest_arg = parse_args_rest();
        unless ($rest_arg) {
            last;
        }
        push(@$args, $rest_arg);
    }

    return $args;
}

sub parse_func {
    puts_fn("parse_func");

    consume_kw("func");

    my $t = peek(0);
    $pos++;
    my $fn_name = $t->{"str"};

    consume_sym("(");
    my $args = parse_args();
    consume_sym(")");

    consume_sym("{");

    my $stmts = [];
    while (! Token::is(peek(0), "sym", "}")) {
        if (Token::is(peek(0), "kw", "var")) {
            push(@$stmts, parse_var());
        } else {
            push(@$stmts, parse_stmt());
        }
    }

    consume_sym("}");

    my $main_func = [
        sval("func"),
        sval($fn_name),
        $args,
        $stmts
        ];

    return $main_func;
}

sub parse_var_declare {
    # puts_fn("parse_var_declare");

    my $t = peek(0);
    $pos++;
    my $var_name = $t->{"str"};

    consume_sym(";");

    return [
        sval("var"),
        sval($var_name)
        ];
}

sub parse_var_init {
    # puts_fn("parse_var_init");

    my $t = peek(0);
    $pos++;
    my $var_name = $t->{"str"};

    consume_sym("=");

    my $expr = parse_expr();

    consume_sym(";");

    return [
        sval("var"),
        sval($var_name),
        $expr
        ];
}

sub parse_var {
    puts_fn("parse_var");

    consume_kw("var");

    my $t = peek(1);

    if (Token::is($t, "sym", ";")) {
        return parse_var_declare();
    } else {
        return parse_var_init();
    }
}

sub parse_expr_right {
    my $expr_l = shift;

    # puts_fn("parse_expr_right");

    my $t = peek(0);

    if (
         Token::is($t, "sym", ";")
      || Token::is($t, "sym", ")")
    ) {
        return $expr_l;
    }

    my $expr_r;
    my $expr_els;
    if (Token::is($t, "sym", "+")) {
        consume_sym("+");
        $expr_r = parse_expr();
        $expr_els = [sval("+"), $expr_l, $expr_r];

    } elsif (Token::is($t, "sym", "*")) {
        consume_sym("*");
        $expr_r = parse_expr();
        $expr_els = [sval("*"), $expr_l, $expr_r];

    } elsif (Token::is($t, "sym", "==")) {
        consume_sym("==");
        $expr_r = parse_expr();
        $expr_els = [sval("eq"), $expr_l, $expr_r];

    } elsif (Token::is($t, "sym", "!=")) {
        consume_sym("!=");
        $expr_r = parse_expr();
        $expr_els = [sval("neq"), $expr_l, $expr_r];

    } else {
        p_e("282", $expr_els);
        die;
    }

    return $expr_els;
}

sub parse_expr {
    # puts_fn("parse_expr");

    my $tl = peek(0);
    my $expr_l;

    if (Token::is($tl, "sym", "(")) {
        consume_sym("(");
        $expr_l = parse_expr();
        consume_sym(")");
        return parse_expr_right($expr_l);
    }

    if (Token::kind_eq($tl, "int")) {
        $pos++;
        my $n = $tl->{"str"};
        $expr_l = ival($n);
        return parse_expr_right($expr_l);

    } elsif (Token::kind_eq($tl, "ident")) {
        $pos++;
        my $s = $tl->{"str"};
        $expr_l = sval($s);
        return parse_expr_right($expr_l);

    } else {
        die;
    }
}

sub parse_set {
    puts_fn("parse_set");

    consume_kw("set");

    my $t = peek(0);
    $pos++;
    my $var_name = $t->{"str"};

    consume_sym("=");
    my $expr = parse_expr();
    consume_sym(";");

    return [
        sval("set"),
        sval($var_name),
        $expr
        ];
}

sub parse_funcall {
    # puts_fn("parse_funcall");

    my $t = peek(0);
    $pos++;
    my $fn_name = $t->{"str"};

    consume_sym("(");
    my $args = parse_args();
    consume_sym(")");

    my $list = [
        sval($fn_name),
        ];
    for my $it (@$args) {
        push(@$list, $it);
    }

    return $list;
}

sub parse_call {
    puts_fn("parse_call");

    consume_kw("call");

    my $funcall = parse_funcall();

    consume_sym(";");

    my $list = [
        sval("call"),
        ];
    for my $it (@$funcall) {
        push(@$list, $it);
    }

    return $list;
}

sub parse_call_set {
    puts_fn("parse_call_set");

    consume_kw("call_set");

    my $t = peek(0);
    $pos++;
    my $var_name = $t->{"str"};

    consume_sym("=");

    my $funcall = parse_funcall();

    consume_sym(";");

    return [
        sval("call_set"),
        sval($var_name),
        $funcall
        ];
}

sub parse_return {
    puts_fn("parse_return");

    consume_kw("return");

    my $expr = parse_expr();

    consume_sym(";");

    return [
        sval("return"),
        $expr
        ];
}

sub parse_while {
    puts_fn("parse_while");

    consume_kw("while");

    consume_sym("(");
    my $expr = parse_expr();
    consume_sym(")");

    consume_sym("{");
    my $stmts = parse_stmts();
    consume_sym("}");

    return [
        sval("while"),
        $expr,
        $stmts
        ];
}

sub parse_when_clause {
    # puts_fn("parse_when_clause");

    my $t = peek(0);
    if (Token::is($t, "sym", "}")) {
        return 0;
    }

    consume_sym("(");
    my $expr = parse_expr();
    consume_sym(")");

    consume_sym("{");
    my $stmts = parse_stmts();
    consume_sym("}");

    my $list = [$expr];
    for my $stmt (@$stmts) {
        push(@$list, $stmt);
    }

    return $list;
}

sub parse_case {
    puts_fn("parse_case");

    consume_kw("case");

    consume_sym("{");

    my $when_clauses = [];

    while (1) {
        my $when_clause = parse_when_clause();
        unless ($when_clause) {
            last;
        }
        push(@$when_clauses, $when_clause);
    }

    consume_sym("}");

    my $list = [sval("case")];
    for my $when_clause (@$when_clauses) {
        push(@$list, $when_clause);
    }

    return $list;
}

sub parse_vm_comment {
    puts_fn("parse_vm_comment");

    consume_kw("_cmt");
    consume_sym("(");

    my $t = peek(0);
    $pos++;
    my $cmt = $t->{"str"};

    consume_sym(")");
    consume_sym(";");

    return [
        sval("_cmt"),
        sval($cmt)
        ];
}

sub parse_stmt {
    my $t = peek(0);

    if (Token::is($t, "sym", "}")) {
        return -1;
    }

    if    (Token::str_eq($t, "func"    )) { return parse_func();       }
    elsif (Token::str_eq($t, "set"     )) { return parse_set();        }
    elsif (Token::str_eq($t, "call"    )) { return parse_call();       }
    elsif (Token::str_eq($t, "call_set")) { return parse_call_set();   }
    elsif (Token::str_eq($t, "return"  )) { return parse_return();     }
    elsif (Token::str_eq($t, "while"   )) { return parse_while();      }
    elsif (Token::str_eq($t, "case"    )) { return parse_case();       }
    elsif (Token::str_eq($t, "_cmt"    )) { return parse_vm_comment(); }
    else {
        if (Token::kind_eq($t, "ident")) {
            return parse_call_set();
        } else {
            p_e("parse_stmt", $t);
            die "not_yet_impl";
        }
    }
}

sub parse_stmts {
    my $stmts = [];

    while (! is_end()) {
        my $stmt = parse_stmt();
        if ($stmt == -1) {
            last;
        }

        push(@$stmts, $stmt);
    }

    return $stmts;
}

sub parse_top_stmt {
    if (Token::is(peek(0), "kw", "func")) {
        return parse_func();
    } else {
        die "unexpected token"
    }
}

sub parse_top_stmts {
    my $stmts = [];

    while (! is_end()) {
        push(@$stmts, parse_top_stmt());
    }

    return $stmts;
}

sub parse {
    my $top_stmts = [
        sval("stmts")
        ];

    my $stmts = parse_top_stmts();

    for my $stmt (@$stmts) {
        push(@$top_stmts, $stmt);
    }

    return $top_stmts;
}

# --------------------------------

my $ti = 0;

while (my $line = <STDIN>) {
    # print($line);
    $line =~ /^(.+?):(.+)$/;
    $tokens->[$ti] = Token::new($1, $2);
    $ti++;
}

# p_e($tokens);

my $tree = parse();

Json::print_as_json($tree);
