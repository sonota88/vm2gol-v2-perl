package Val;

sub new {
    my ($kind, $val) = @_;

    return {
        "kind" => $kind, # "int" | "str"
        "val" => $val,
    };
}

sub is_int {
    my $self = shift;

    return $self->{"kind"} eq "int";
}

sub is_str {
    my $self = shift;

    return $self->{"kind"} eq "str";
}

sub kind_eq {
    my $self = shift;
    my $kind = shift;

    return $self->{"kind"} eq $kind;
}

sub str_eq {
    my $self = shift;
    my $str = shift;

    return $self->{"val"} eq $str;
}

1;
