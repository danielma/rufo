#~# ORIGINAL

foo[ ]

#~# EXPECTED

foo[]

#~# ORIGINAL

foo[
 ]

#~# EXPECTED

foo[]

#~# ORIGINAL

foo[ 1 ]

#~# EXPECTED

foo[1]

#~# ORIGINAL

foo[ 1 , 2 , 3 ]

#~# EXPECTED

foo[1, 2, 3]

#~# ORIGINAL

foo[ 1 ,
 2 ,
 3 ]

#~# EXPECTED

foo[1, 2, 3]

#~# ORIGINAL

foo[
 1 ,
 2 ,
 3 ]

#~# EXPECTED

foo[1, 2, 3]

#~# ORIGINAL long list of parameters
#~# line_length: 10

foo[1, 2, 3, 4, 5]

#~# EXPECTED

foo[
  1,
  2,
  3,
  4,
  5,
]

#~# ORIGINAL

foo[ *x ]

#~# EXPECTED

foo[*x]

#~# ORIGINAL

foo[
 1,
]

#~# EXPECTED

foo[1]

#~# ORIGINAL

foo[
 1,
 2 , 3,
 4,
]

#~# EXPECTED

foo[1, 2, 3, 4]
