#~# ORIGINAL heredoc

<<-EOF
  foo
  bar
EOF

#~# EXPECTED

<<-EOF
  foo
  bar
EOF

#~# ORIGINAL heredoc_multiline

foo 1 , <<-EOF , 2
  foo
  bar
EOF

#~# EXPECTED

foo 1, <<-EOF, 2
  foo
  bar
EOF

#~# ORIGINAL heredoc_multiline_2

foo 1 , <<-EOF1 , 2 , <<-EOF2 , 3
  hdoc1
  foo
EOF1
  hdoc2
  foo
EOF2

#~# EXPECTED

foo 1, <<-EOF1, 2, <<-EOF2, 3
  hdoc1
  foo
EOF1
  hdoc2
  foo
EOF2

#~# ORIGINAL heredoc_multiline_3

foo 1 , <<-EOF1 , 2 , <<-EOF2
  foo
  bar
EOF1
  baz
EOF2

#~# EXPECTED

foo 1, <<-EOF1, 2, <<-EOF2
  foo
  bar
EOF1
  baz
EOF2

#~# ORIGINAL heredoc_inside_method_call

foo(1 , <<-EOF , 2 )
  foo
  bar
EOF

#~# EXPECTED

foo(1, <<-EOF, 2)
  foo
  bar
EOF

#~# ORIGINAL heredoc_with_method_called

<<-EOF.foo
  bar
EOF

#~# EXPECTED

<<-EOF.foo
  bar
EOF

#~# ORIGINAL heredoc_assigned_to_variable

x = <<-EOF.foo
  bar
EOF

#~# EXPECTED

x = <<-EOF.foo
  bar
EOF

#~# ORIGINAL heredoc_assigned_to_multiple_variables

x, y = <<-EOF.foo, 2
  bar
EOF

#~# EXPECTED

x, y = <<-EOF.foo, 2
  bar
EOF

#~# ORIGINAL heredoc_as_method_argument

call <<-EOF.foo, y
  bar
EOF

#~# EXPECTED

call <<-EOF.foo, y
  bar
EOF

#~# ORIGINAL heredoc_with_trailing_comment

<<-EOF
  foo
EOF

# comment

#~# EXPECTED

<<-EOF
  foo
EOF

# comment

#~# ORIGINAL heredoc as method argument should avoid break
#~# line_length: 1

foo(<<-EOF)
  bar
EOF

#~# EXPECTED

foo(<<-EOF)
  bar
EOF

#~# ORIGINAL heredoc_with_bizarre_syntax

foo <<-EOF.bar if 1
  x
EOF

#~# EXPECTED

foo <<-EOF.bar if 1
  x
EOF

#~# ORIGINAL heredoc_with_percent

<<-EOF % 1
  bar
EOF

#~# EXPECTED

<<-EOF % 1
  bar
EOF

#~# ORIGINAL heredoc with operator and short line length
#~# line_length: 1

<<-EOF % 1
  bar
EOF

#~# EXPECTED

<<-EOF % 1
  bar
EOF

#~# ORIGINAL heredoc_as_hash_value

{1 => <<EOF,
text
EOF
 2 => 3}

#~# EXPECTED

{ 1 => <<EOF,
text
EOF
   2 => 3 }

#~# ORIGINAL heredoc as hash value with line length
#~# line_length: 1

{1 => <<EOF,
text
EOF
 2 => 3}

#~# EXPECTED

{ 1 => <<EOF,
text
EOF
   2 => 3 }

#~# ORIGINAL assign variable to heredoc

x = <<EOF . strip_heredoc
  this is my
  value
EOF

#~# EXPECTED

x = <<EOF.strip_heredoc
  this is my
  value
EOF
