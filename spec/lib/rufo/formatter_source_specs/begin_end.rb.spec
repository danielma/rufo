#~# ORIGINAL begin;end

begin;end

#~# EXPECTED

begin
end

#~# ORIGINAL begin end space before end

begin
 end

#~# EXPECTED

begin
end

#~# ORIGINAL single line begin..end

begin 1 end

#~# EXPECTED

begin
  1
end

#~# ORIGINAL single line begin..end with semicolon

begin; 1; end

#~# EXPECTED

begin
  1
end

#~# ORIGINAL single line begin..end with multiple semicolons

begin; 1; 2; end

#~# EXPECTED

begin
  1
  2
end

#~# ORIGINAL multiline begin..end with semicolons

begin; 1
 2; end

#~# EXPECTED

begin
  1
  2
end

#~# ORIGINAL multiline begin..end space before end

begin
 1
 end

#~# EXPECTED

begin
  1
end

#~# ORIGINAL multiline begin..end space before end 2

begin
 1
 2
 end

#~# EXPECTED

begin
  1
  2
end

#~# ORIGINAL nested begin..end

begin
 begin
 1
 end
 2
 end

#~# EXPECTED

begin
  begin
    1
  end
  2
end

#~# ORIGINAL begin comment end

begin # hello
 end

#~# EXPECTED

begin # hello
end

#~# ORIGINAL begin comment end with semicolon

begin;# hello
 end

#~# EXPECTED

begin # hello
end

#~# ORIGINAL begin..end with comment in body

begin
 1  # a
end

#~# EXPECTED

begin
  1 # a
end

#~# ORIGINAL begin..end with multiple comments in body

begin
 1  # a
 # b
 3 # c
 end

#~# EXPECTED

begin
  1 # a
  # b
  3 # c
end

#~# ORIGINAL begin..end basic

begin
end

# foo

#~# EXPECTED

begin
end

# foo

#~# ORIGINAL nested begin single line

begin
  begin 1 end
end

#~# EXPECTED

begin
  begin
    1
  end
end

#~# ORIGINAL begin def..end end single line def

begin
  def foo(x) 1 end
end

#~# EXPECTED

begin
  def foo(x)
    1
  end
end

#~# ORIGINAL begin if..then..end end

begin
  if 1 then 2 end
end

#~# EXPECTED

begin
  if 1
    2
  end
end

#~# ORIGINAL begin do_block end

begin
  foo do 1 end
end

#~# EXPECTED

begin
  foo do
    1
  end
end

#~# ORIGINAL begin for..in end

begin
  for x in y do 1 end
end

#~# EXPECTED

begin
  for x in y
    1
  end
end

#~# ORIGINAL begin comment block end

begin
  # foo

  1
end

#~# EXPECTED

begin
  # foo

  1
end
