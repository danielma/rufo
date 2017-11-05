#~# ORIGINAL

-> { } 

#~# EXPECTED

-> { }

#~# ORIGINAL

->{} 

#~# EXPECTED

-> { }

#~# ORIGINAL

->{   1   } 

#~# EXPECTED

-> { 1 }

#~# ORIGINAL

->{   1 ; 2  } 

#~# EXPECTED

lambda do
  1
  2
end

#~# ORIGINAL

->{   1 
 2  } 

#~# EXPECTED

lambda do
  1
  2
end

#~# ORIGINAL

-> do  1 
 2  end 

#~# EXPECTED

lambda do
  1
  2
end

#~# ORIGINAL

-> do 1 end

#~# EXPECTED

-> { 1 }

#~# ORIGINAL

->do  1 
 2  end 

#~# EXPECTED

lambda do
  1
  2
end

#~# ORIGINAL

->( x ){ } 

#~# EXPECTED

->(x) { }

#~# ORIGINAL lambda with one statement

lambda do; 1;    end

#~# EXPECTED

lambda do
  1
end

#~# ORIGINAL lambda to lambda

lambda do
  1#i think
  # this is good
  2
end

#~# EXPECTED

lambda do
  1 # i think
  # this is good
  2
end

#~# ORIGINAL lambda with arguments

lambda do |args|
  args
end

#~# EXPECTED

lambda do |args|
  args
end

#~# ORIGINAL

lambda do |args|
  args
ok
end

#~# EXPECTED

lambda do |args|
  args
  ok
end

#~# ORIGINAL

lambda do
end

#~# EXPECTED

lambda { }

#~# ORIGINAL

lambda do
  
end
lambda do
         
end

#~# EXPECTED

lambda { }
lambda { }

#~# ORIGINAL

x = ->                           (    ok  = 7  )          {
  1

  2
  3
  ok
}

#~# EXPECTED

x = lambda do |ok = 7|
  1

  2
  3
  ok
end
