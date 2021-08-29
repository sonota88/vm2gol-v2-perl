use strict;
use warnings;
use Data::Dumper;

require "./lib/utils.pm";
require "./lib/json.pm";
require "./lib/val.pm";

our $g_label_id = 0;

# --------------------------------

sub p_e {
    STDERR->print(Dumper @_);
}

sub puts_fn {
    my $msg = shift;
    # STDERR->print("    |-->> " . $msg . "()\n");
}

# --------------------------------

sub sval {
    my $str = shift;
    return Val::new("str", $str);
}

sub get_label_id {
    $g_label_id++;
    return $g_label_id;
}

sub head {
    my $list = shift;
    return $list->[0];
}

sub rest {
    my $list = shift;
    my $rest = [];

    for (my $i = 1; $i < Utils::arr_size($list); $i++) {
        push(@$rest, $list->[$i]);
    }

    return $rest;
}

sub str_arr_index {
    my $xs = shift;
    my $x = shift;

    my $i = 0;

    for my $it (@$xs) {
        if ($it eq $x) {
            return $i;
        }
        $i++;
    }

    return -1;
}

# --------------------------------

sub asm_prologue {
    printf("  push bp\n");
    printf("  cp sp bp\n");
}

sub asm_epilogue {
    print("  cp bp sp\n");
    print("  pop bp\n");
}

sub fn_arg_disp {
    my $names = shift;
    my $name = shift;

    my $i = str_arr_index($names, $name);
    if ($i < 0) {
        die "fn arg not found\n";
    }
    return $i + 2;
}

sub lvar_disp {
    my $names = shift;
    my $name = shift;

    my $i = str_arr_index($names, $name);
    if ($i < 0) {
        die "lvar not found\n";
    }
    return -($i + 1);
}

# --------------------------------

sub gen_expr_add {
    printf("  pop reg_b\n");
    printf("  pop reg_a\n");
    printf("  add_ab\n");
}

sub gen_expr_mult {
    printf("  pop reg_b\n");
    printf("  pop reg_a\n");
    printf("  mult_ab\n");
}

sub gen_expr_eq {
    my $label_id = get_label_id();

    my $then_label = "then_$label_id";
    my $end_label = "end_eq_$label_id";

    printf("  pop reg_b\n");
    printf("  pop reg_a\n");

    printf("  compare\n");
    printf("  jump_eq %s\n", $then_label);

    printf("  cp 0 reg_a\n");
    printf("  jump %s\n", $end_label);

    printf("label %s\n", $then_label);
    printf("  cp 1 reg_a\n");
    printf("label %s\n", $end_label);
}

sub gen_expr_neq {
    my $label_id = get_label_id();

    my $then_label = "then_$label_id";
    my $end_label = "end_neq_$label_id";

    printf("  pop reg_b\n");
    printf("  pop reg_a\n");

    printf("  compare\n");
    printf("  jump_eq %s\n", $then_label);

    printf("  cp 1 reg_a\n");
    printf("  jump %s\n", $end_label);

    printf("label %s\n", $then_label);
    printf("  cp 0 reg_a\n");
    printf("label %s\n", $end_label);
}

sub _gen_expr_binary {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $expr = shift;

    my $op   = head($expr);
    my $args = rest($expr);

    my $term_l = $args->[0];
    my $term_r = $args->[1];

    gen_expr($fn_arg_names, $lvar_names, $term_l);
    printf("  push reg_a\n");
    gen_expr($fn_arg_names, $lvar_names, $term_r);
    printf("  push reg_a\n");

    if (Val::str_eq($op, "+")) {
        gen_expr_add();
    } elsif (Val::str_eq($op, "*")) {
        gen_expr_mult();
    } elsif (Val::str_eq($op, "eq")) {
        gen_expr_eq();
    } elsif (Val::str_eq($op, "neq")) {
        gen_expr_neq();
    } else {
        die;
    }
}

sub gen_expr {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $expr = shift;

    if (Utils::is_arr($expr)) {
        _gen_expr_binary($fn_arg_names, $lvar_names, $expr);
    } elsif (Val::kind_eq($expr, "int")) {
        my $n = $expr->{"val"};
        printf("  cp %d reg_a\n", $n);
    } elsif (Val::kind_eq($expr, "str")) {
        my $str = $expr->{"val"};
        if (0 <= str_arr_index($fn_arg_names, $str)) {
            my $disp = fn_arg_disp($fn_arg_names, $str);
            printf("  cp [bp:%d] reg_a\n", $disp);
        } elsif (0 <= str_arr_index($lvar_names, $str)) {
            my $disp = lvar_disp($lvar_names, $str);
            printf("  cp [bp:%d] reg_a\n", $disp);
        } else {
            die;
        }
    } else {
        die;
    }
}

sub gen_call {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmt_rest = shift;

    my $fn_name = head($stmt_rest)->{"val"};
    my $fn_args = rest($stmt_rest);

    for my $fn_arg (reverse(@$fn_args)) {
        gen_expr($fn_arg_names, $lvar_names, $fn_arg);
        printf("  push reg_a\n");
    }

    gen_vm_comment("call  $fn_name");
    printf("  call %s\n", $fn_name);

    printf("  add_sp %d\n", Utils::arr_size($fn_args));
}

sub gen_call_set {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmt_rest = shift;

    # p_e("gen_call_set", $stmt_rest);

    my $lvar_name = head($stmt_rest)->{"val"};
    my $funcall   = $stmt_rest->[1];

    gen_call($fn_arg_names, $lvar_names, $funcall);

    my $disp = lvar_disp($lvar_names, $lvar_name);
    printf("  cp reg_a [bp:%d]\n", $disp);
}

sub gen_set {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $rest = shift;

    puts_fn("gen_set");

    my $dest = $rest->[0];
    my $expr = $rest->[1];

    gen_expr($fn_arg_names, $lvar_names, $expr);
    my $src_val = "reg_a";

    my $dest_str = $dest->{"val"};

    if (0 <= str_arr_index($lvar_names, $dest_str)) {
        my $disp = lvar_disp($lvar_names, $dest_str);
        printf("  cp %s [bp:%d]\n", $src_val, $disp);
    } else {
        die;
    }
}

sub gen_return {
    my $lvar_names = shift;
    my $stmt_rest = shift;

    my $retval = head($stmt_rest);

    gen_expr([], $lvar_names, $retval);
}

sub gen_while {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmt_rest = shift;

    puts_fn("gen_while");

    my $cond_expr = head($stmt_rest);
    my $body = $stmt_rest->[1];

    my $label_id = get_label_id();
    my $label_begin = "while_$label_id";
    my $label_end = "end_while_$label_id";
    my $label_true = "true_$label_id";

    printf("\n");

    printf("label %s\n", $label_begin);

    gen_expr($fn_arg_names, $lvar_names, $cond_expr);

    printf("  cp 0 reg_b\n");
    printf("  compare\n");

    printf("  jump_eq %s\n", $label_end);

    gen_stmts($fn_arg_names, $lvar_names, $body);

    printf("  jump %s\n", $label_begin);

    printf("label %s\n", $label_end);
    printf("\n");
}

sub gen_case {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $when_clauses = shift;

    puts_fn("gen_case");

    my $label_id = get_label_id();
    my $when_idx = -1;

    my $label_end = "end_case_${label_id}";
    my $label_when_head = "when_${label_id}";
    my $label_end_when_head = "end_when_${label_id}";

    printf("\n");
    printf("  # -->> case_%d\n", $label_id);

    for my $when_clause (@$when_clauses) {
        $when_idx++;

        my $cond = head($when_clause);
        my $rest = rest($when_clause);

        printf(
            "  # when_%d_%d: %s\n",
            $label_id, $when_idx, Json::list_to_json_line($cond)
            );

            printf("  # -->> expr\n");
            gen_expr($fn_arg_names, $lvar_names, $cond);
            printf("  # <<-- expr\n");

            printf("  cp 0 reg_b\n");

            printf("  compare\n");
            printf("  jump_eq %s_%d\n", $label_end_when_head, $when_idx);

            gen_stmts($fn_arg_names, $lvar_names, $rest);

            printf("  jump %s\n", $label_end);
            printf("label %s_%d\n", $label_end_when_head, $when_idx);
    }

    printf("label end_case_%d\n", $label_id);
    printf("  # <<-- case_%d\n", $label_id);
    printf("\n");
}

sub gen_vm_comment {
    my $cmt = shift;

    $cmt =~ s/ /~/g;

    printf("  _cmt %s\n", $cmt);
}

sub gen_debug {
    printf("  _debug\n");
}

sub gen_stmt {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmt = shift;

    my $stmt_head = head($stmt);
    my $stmt_rest = rest($stmt);

    if    (Val::str_eq($stmt_head, "set"     )) { gen_set(       $fn_arg_names, $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "call"    )) { gen_call(      $fn_arg_names, $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "call_set")) { gen_call_set(  $fn_arg_names, $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "return"  )) { gen_return(                   $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "while"   )) { gen_while(     $fn_arg_names, $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "case"    )) { gen_case(      $fn_arg_names, $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "_cmt"    )) { gen_vm_comment($stmt_rest->[0]->{"val"}); }
    elsif (Val::str_eq($stmt_head, "_debug"  )) { gen_debug(); }
    else {
        die;
    }
}

sub gen_stmts {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmts = shift;

    for my $stmt (@$stmts) {
        gen_stmt($fn_arg_names, $lvar_names, $stmt);
    }
}

sub gen_var {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmt_rest = shift;

    print("  sub_sp 1\n");

    if (Utils::arr_size($stmt_rest) == 2) {
        gen_set($fn_arg_names, $lvar_names, $stmt_rest);
    }
}

sub gen_func_def {
    my $rest = shift;

    my $fn_name = $rest->[0]->{"val"};
    my $fn_arg_vals = $rest->[1];
    my $body = $rest->[2];

    my $fn_arg_names = [];
    for my $val (@$fn_arg_vals) {
        push(@$fn_arg_names, $val->{"val"});
    }

    print("\n");
    printf("label %s\n", $fn_name);
    asm_prologue();
    print("\n");

    my $lvar_names = [];

    print("  # 関数の処理本体\n");
    for my $stmt (@$body) {
        my $stmt_rest = rest($stmt);

        if (Val::str_eq(head($stmt), "var")) {
            my $var_name = head($stmt_rest)->{"val"};
            push(@$lvar_names, $var_name);
            gen_var($fn_arg_names, $lvar_names, $stmt_rest);
        } else {
            gen_stmt($fn_arg_names, $lvar_names, $stmt);
        }
    }

    print("\n");
    asm_epilogue();
    print("  ret\n");
}

sub gen_top_stmts {
    my $top_stmts = shift;

    puts_fn("gen_top_stmts");

    for my $it (@$top_stmts) {
        my $stmt_head = head($it);
        my $stmt_rest = rest($it);

        if (Val::str_eq($stmt_head, "func") ) {
            gen_func_def($stmt_rest);
        } else {
            die "not_yet_impl";
        }
    }
}

sub gen_builtin_set_vram {
    print("\n");
    print("label set_vram\n");
    asm_prologue();

    print("  set_vram [bp:2] [bp:3]\n"); # vram_addr value

    asm_epilogue();
    print("  ret\n");
}

sub gen_builtin_get_vram {
    print("\n");
    print("label get_vram\n");
    asm_prologue();

    print("  get_vram [bp:2] reg_a\n"); # vram_addr dest

    asm_epilogue();
    print("  ret\n");
}

sub codegen {
    my $tree = shift;

    my $top_stmts = rest($tree);

    print("  call main\n");
    print("  exit\n");

    gen_top_stmts($top_stmts);

    print("#>builtins");
    gen_builtin_set_vram();
    gen_builtin_get_vram();
    print("#<builtins");
}

# --------------------------------

my $src = Utils::read_stdin_all();

my $tree = Json::parse($src);

codegen($tree);
