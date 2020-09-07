package Token;

sub new {
    my ($kind, $str) = @_;

    return {
        "kind" => $kind,
        "str" => $str,
    };
}

sub kind_eq {
    my $self = shift;
    my $kind = shift;

    return $self->{"kind"} eq $kind;
}

sub str_eq {
    my $self = shift;
    my $str = shift;

    return $self->{"str"} eq $str;
}

sub is {
    my $self = shift;
    my $kind = shift;
    my $str = shift;

    return kind_eq($self, $kind) && str_eq($self, $str);
}

1;
