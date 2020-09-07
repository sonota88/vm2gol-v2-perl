package Utils;

sub read_stdin_all {
    my $src = "";

    # while ($_ = <STDIN>) {
    while (<STDIN>) {
        $src = "${src}$_";
    }

    return $src;
}

sub arr_size {
    my ($arg) = @_;
    my @arr = @$arg;
    my $size = @arr;
    return $size;
}

sub is_arr {
    my $arg = shift;

    return ref($arg) eq "ARRAY";
}

1;
