#~# ORIGINAL

if 1
2
end

#~# EXPECTED

if 1
  2
end

#~# ORIGINAL

if 1

2

end

#~# EXPECTED

if 1
  2
end

#~# ORIGINAL

if 1

end

#~# EXPECTED

if 1
end

#~# ORIGINAL

if 1;end

#~# EXPECTED

if 1
end

#~# ORIGINAL

if 1 # hello
end

#~# EXPECTED

if 1 # hello
end

#~# ORIGINAL

if 1 # hello

end

#~# EXPECTED

if 1 # hello
end

#~# ORIGINAL

if 1 # hello
1
end

#~# EXPECTED

if 1 # hello
  1
end

#~# ORIGINAL

if 1;# hello
1
end

#~# EXPECTED

if 1 # hello
  1
end

#~# ORIGINAL

if 1 # hello
 # bye
end

#~# EXPECTED

if 1 # hello
  # bye
end

#~# ORIGINAL

if true
#always run this code
end

#~# EXPECTED

if true
  # always run this code
end

#~# ORIGINAL

if 1; 2; else; end

#~# EXPECTED

if 1
  2
end

#~# ORIGINAL

if 1; 2; else; 3; end

#~# EXPECTED

if 1
  2
else
  3
end

#~# ORIGINAL

if 1; 2; else # comment
 3; end

#~# EXPECTED

if 1
  2
else # comment
  3
end

#~# ORIGINAL

begin
if 1
2
else
3
end
end

#~# EXPECTED

begin
  if 1
    2
  else
    3
  end
end

#~# ORIGINAL

if 1 then 2 else 3 end

#~# EXPECTED

if 1
  2
else
  3
end

#~# ORIGINAL

if 1 
 2 
 elsif 3 
 4 
 end

#~# EXPECTED

if 1
  2
elsif 3
  4
end

#~# ORIGINAL

if 1; 2;
elsif 12 # when 12
  1*5
end

#~# EXPECTED

if 1
  2
elsif 12 # when 12
  1 * 5
end

#~# ORIGINAL

if 1
then 2
end

#~# EXPECTED

if 1
  2
end
