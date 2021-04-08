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

sub to_fn_arg_ref {
    my $names = shift;
    my $name = shift;

    my $i = str_arr_index($names, $name);
    if ($i < 0) {
        die "fn arg not found\n";
    }
    return "[bp+" . ($i + 2) . "]";
}

sub to_lvar_ref {
    my $names = shift;
    my $name = shift;

    my $i = str_arr_index($names, $name);
    if ($i < 0) {
        die "lvar not found\n";
    }
    return "[bp-" . ($i + 1) . "]";
}

sub to_asm_str {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $val = shift;

    if (Utils::is_arr($val)) {
        return undef;
    } elsif (Val::kind_eq($val, "int")) {
        return $val->{"val"};
    } elsif (Val::kind_eq($val, "str")) {
        my $str = $val->{"val"};
        if (0 <= str_arr_index($fn_arg_names, $str)) {
            return to_fn_arg_ref($fn_arg_names, $str);
        } elsif (0 <= str_arr_index($lvar_names, $str)) {
            return to_lvar_ref($lvar_names, $str);
        } else {
            return undef;
        }
    } else {
        return undef;
    }
}

sub codegen_var {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmt_rest = shift;

    print("  sub_sp 1\n");

    if (Utils::arr_size($stmt_rest) == 2) {
        codegen_set($fn_arg_names, $lvar_names, $stmt_rest);
    }
}

sub codegen_expr_push {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $val = shift;

    my $push_arg;

    $push_arg = to_asm_str($fn_arg_names, $lvar_names, $val);
    unless (defined($push_arg)) {
        if (Utils::is_arr($val)) {
            codegen_expr($fn_arg_names, $lvar_names, $val);
            $push_arg = "reg_a";
        } else {
            p_e("codegen_expr_push", $val);
            die;
        }
    }

    printf("  push %s\n", $push_arg);
}

sub codegen_expr_add {
    printf("  pop reg_b\n");
    printf("  pop reg_a\n");
    printf("  add_ab\n");
}

sub codegen_expr_mult {
    printf("  pop reg_b\n");
    printf("  pop reg_a\n");
    printf("  mult_ab\n");
}

sub codegen_expr_eq {
    my $label_id = get_label_id();

    my $then_label = "then_$label_id";
    my $end_label = "end_eq_$label_id";

    printf("  pop reg_b\n");
    printf("  pop reg_a\n");

    printf("  compare\n");
    printf("  jump_eq %s\n", $then_label);

    printf("  set_reg_a 0\n");
    printf("  jump %s\n", $end_label);

    printf("label %s\n", $then_label);
    printf("  set_reg_a 1\n");
    printf("label %s\n", $end_label);
}

sub codegen_expr_neq {
    my $label_id = get_label_id();

    my $then_label = "then_$label_id";
    my $end_label = "end_neq_$label_id";

    printf("  pop reg_b\n");
    printf("  pop reg_a\n");

    printf("  compare\n");
    printf("  jump_eq %s\n", $then_label);

    printf("  set_reg_a 1\n");
    printf("  jump %s\n", $end_label);

    printf("label %s\n", $then_label);
    printf("  set_reg_a 0\n");
    printf("label %s\n", $end_label);
}

sub codegen_expr {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $expr = shift;

    my $op   = head($expr);
    my $args = rest($expr);

    my $term_l = $args->[0];
    my $term_r = $args->[1];

    codegen_expr_push($fn_arg_names, $lvar_names, $term_l);
    codegen_expr_push($fn_arg_names, $lvar_names, $term_r);

    if (Val::str_eq($op, "+")) {
        codegen_expr_add();
    } elsif (Val::str_eq($op, "*")) {
        codegen_expr_mult();
    } elsif (Val::str_eq($op, "eq")) {
        codegen_expr_eq();
    } elsif (Val::str_eq($op, "neq")) {
        codegen_expr_neq();
    } else {
        die;
    }
}

sub codegen_call_push_fn_arg {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $fn_arg = shift;

    my $push_arg;

    $push_arg = to_asm_str($fn_arg_names, $lvar_names, $fn_arg);
    unless (defined($push_arg)) {
        p_e("codegen_call_push_fn_arg", $fn_arg);
        die;
    }

    printf("  push %s\n", $push_arg);
}

sub codegen_call {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmt_rest = shift;

    my $fn_name = head($stmt_rest)->{"val"};
    my $fn_args = rest($stmt_rest);

    for my $fn_arg (reverse(@$fn_args)) {
        codegen_call_push_fn_arg($fn_arg_names, $lvar_names, $fn_arg);
    }

    codegen_vm_comment("call  $fn_name");
    printf("  call %s\n", $fn_name);

    printf("  add_sp %d\n", Utils::arr_size($fn_args));
}

sub codegen_call_set {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmt_rest = shift;

    # p_e("codegen_call_set", $stmt_rest);

    my $lvar_name = head($stmt_rest)->{"val"};
    my $fn_temp   = $stmt_rest->[1];

    my $fn_name = head($fn_temp)->{"val"};
    my $fn_args = rest($fn_temp);

    for my $fn_arg (reverse(@$fn_args)) {
        codegen_call_push_fn_arg($fn_arg_names, $lvar_names, $fn_arg);
    }

    codegen_vm_comment("call_set  " . $fn_name);
    printf("  call %s\n", $fn_name);
    printf("  add_sp %d\n", Utils::arr_size($fn_args));

    my $ref = to_lvar_ref($lvar_names, $lvar_name);
    printf("  cp reg_a %s\n", $ref);
}

sub codegen_set {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $rest = shift;

    puts_fn("codegen_set");

    my $dest = $rest->[0];
    my $expr = $rest->[1];

    my $src_val;

    $src_val = to_asm_str($fn_arg_names, $lvar_names, $expr);
    unless (defined($src_val)) {
        if (Utils::is_arr($expr)) {
            codegen_expr($fn_arg_names, $lvar_names, $expr);
            $src_val = "reg_a";
        } elsif (Val::kind_eq($expr, "str")) {
            my $str = $expr->{"val"};
            if ($str =~ /^vram\[(.+?)\]/) {
                my $vram_arg = $1;
                if ($vram_arg =~ /^[0-9]+$/) {
                    printf("  get_vram %s reg_a\n", $vram_arg);
                } else {
                    my $vram_ref = to_asm_str($fn_arg_names, $lvar_names, sval($vram_arg));
                    if (defined($vram_ref)) {
                        printf("  get_vram %s reg_a\n", $vram_ref);
                    } else {
                        die;
                    }
                }
                $src_val = "reg_a";
            } else {
                
                die;
            }
        } else {
            p_e("codegen_set", $expr);
            die;
        }
    }

    my $dest_str = $dest->{"val"};

    if ($dest_str =~ /^vram\[(.+?)\]/) {
        my $vram_arg = $1;

        if ($vram_arg =~ /^[0-9]+$/) {
            printf("  set_vram %s %s\n", $vram_arg, $src_val);
        } else {
            my $vram_ref = to_asm_str($fn_arg_names, $lvar_names, sval($vram_arg));
            if (defined($vram_ref)) {
                printf("  set_vram %s %s\n", $vram_ref, $src_val);
            } else {
                die;
            }
        }
    } elsif (0 <= str_arr_index($lvar_names, $dest_str)) {
        my $ref = to_lvar_ref($lvar_names, $dest_str);
        printf("  cp %s %s\n", $src_val, $ref);
    } else {
        die;
    }
}

sub codegen_return {
    my $lvar_names = shift;
    my $stmt_rest = shift;

    my $retval = head($stmt_rest);

    if (Val::kind_eq($retval, "int")) {
        printf("  set_reg_a %s\n", $retval->{"val"});
    } elsif (Val::kind_eq($retval, "str")) {

        my $str = $retval->{"val"};

        if ($str =~ /^vram\[(.+?)\]/) {
            my $vram_arg = $1;

            if ($vram_arg =~ /^[0-9]+$/) {
                die;
            } else {
                my $vram_ref = to_asm_str([], $lvar_names, sval($vram_arg));
                if (defined($vram_ref)) {
                    printf("  get_vram %s reg_a\n", $vram_ref);
                } else {
                    die;
                }
            }
        } elsif (0 <= str_arr_index($lvar_names, $str)) {
            my $ref = to_lvar_ref($lvar_names, $str);
            printf("  cp %s reg_a\n", $ref);
        } else {
            die;
        }

    } else {
        die;
    }
}

sub codegen_vm_comment {
    my $cmt = shift;

    $cmt =~ s/ /~/g;

    printf("  _cmt %s\n", $cmt);
}

sub codegen_while {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmt_rest = shift;

    puts_fn("codegen_while");

    my $cond_expr = head($stmt_rest);
    my $body = $stmt_rest->[1];

    my $label_id = get_label_id();
    my $label_begin = "while_$label_id";
    my $label_end = "end_while_$label_id";
    my $label_true = "true_$label_id";

    printf("\n");

    printf("label %s\n", $label_begin);

    codegen_expr($fn_arg_names, $lvar_names, $cond_expr);

    printf("  set_reg_b 1\n");
    printf("  compare\n");

    printf("  jump_eq %s\n", $label_true);
    printf("  jump %s\n", $label_end);
    printf("label %s\n", $label_true);

    codegen_stmts($fn_arg_names, $lvar_names, $body);

    printf("  jump %s\n", $label_begin);

    printf("label %s\n", $label_end);
    printf("\n");
}

sub codegen_case {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $when_blocks = shift;

    puts_fn("codegen_case");

    my $label_id = get_label_id();
    my $when_idx = -1;

    my $label_end = "end_case_${label_id}";
    my $label_when_head = "when_${label_id}";
    my $label_end_when_head = "end_when_${label_id}";

    printf("\n");
    printf("  # -->> case_%d\n", $label_id);

    for my $when_block (@$when_blocks) {
        $when_idx++;

        my $cond = head($when_block);
        my $rest = rest($when_block);

        my $cond_head = head($cond);
        my $cond_rest = rest($cond);

        printf(
            "  # when_%d_%d: %s\n",
            $label_id, $when_idx, Json::list_to_json_line($cond)
            );

        if (Val::str_eq($cond_head, "eq")) {
            printf("  # -->> expr\n");
            codegen_expr($fn_arg_names, $lvar_names, $cond);
            printf("  # <<-- expr\n");

            printf("  set_reg_b 1\n");

            printf("  compare\n");
            printf("  jump_eq %s_%d\n", $label_when_head, $when_idx);
            printf("  jump %s_%d\n", $label_end_when_head, $when_idx);

            printf("label %s_%d\n", $label_when_head, $when_idx);

            codegen_stmts($fn_arg_names, $lvar_names, $rest);

            printf("  jump %s\n", $label_end);
            printf("label %s_%d\n", $label_end_when_head, $when_idx);
        } else {
            die;
        }
    }

    printf("label end_case_%d\n", $label_id);
    printf("  # <<-- case_%d\n", $label_id);
    printf("\n");
}

sub codegen_stmt {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmt = shift;

    my $stmt_head = head($stmt);
    my $stmt_rest = rest($stmt);

    if    (Val::str_eq($stmt_head, "set"     )) { codegen_set(       $fn_arg_names, $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "call"    )) { codegen_call(      $fn_arg_names, $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "call_set")) { codegen_call_set(  $fn_arg_names, $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "return"  )) { codegen_return(                   $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "while"   )) { codegen_while(     $fn_arg_names, $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "case"    )) { codegen_case(      $fn_arg_names, $lvar_names, $stmt_rest); }
    elsif (Val::str_eq($stmt_head, "_cmt"    )) { codegen_vm_comment($stmt_rest->[0]->{"val"}); }
    else {
        die;
    }
}

sub codegen_stmts {
    my $fn_arg_names = shift;
    my $lvar_names = shift;
    my $stmts = shift;

    for my $stmt (@$stmts) {
        codegen_stmt($fn_arg_names, $lvar_names, $stmt);
    }
}

sub codegen_func_def {
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
    print("  push bp\n");
    print("  cp sp bp\n");
    print("\n");

    my $lvar_names = [];

    print("  # 関数の処理本体\n");
    for my $stmt (@$body) {
        my $stmt_rest = rest($stmt);

        if (Val::str_eq(head($stmt), "var")) {
            my $var_name = head($stmt_rest)->{"val"};
            push(@$lvar_names, $var_name);
            codegen_var($fn_arg_names, $lvar_names, $stmt_rest);
        } else {
            codegen_stmt($fn_arg_names, $lvar_names, $stmt);
        }
    }

    print("\n");
    print("  cp bp sp\n");
    print("  pop bp\n");
    print("  ret\n");
}

sub codegen_top_stmts {
    my $top_stmts = shift;

    puts_fn("codegen_top_stmts");

    for my $it (@$top_stmts) {
        my $stmt_head = head($it);
        my $stmt_rest = rest($it);

        if (Val::str_eq($stmt_head, "func") ) {
            codegen_func_def($stmt_rest);
        } else {
            die "not_yet_impl";
        }
    }
}

# --------------------------------

my $src = Utils::read_stdin_all();

my $tree = Json::parse($src);

print("  call main\n");
print("  exit\n");

my $top_stmts = rest($tree);

codegen_top_stmts($top_stmts);