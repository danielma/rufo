BEGIN { 1; 2 }

puts 1 , <<-EOF1 , 2 , <<-EOF2 , 3
  hdoc1
  foo
EOF1
  hdoc2
  foo
EOF2

puts DATA.read

__END__

whatever is down here isn't parsed as actual ruby code

it's free form text that can be used in the file
