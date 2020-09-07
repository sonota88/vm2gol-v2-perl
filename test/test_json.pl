use strict;
use warnings;

require "./lib/utils.pm";
require "./lib/json.pm";

my $json = Utils::read_stdin_all();
my $tree = Json::parse($json);

Json::print_as_json($tree, 0);
