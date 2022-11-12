#!/bin/sh

while read a b ; do
    res=`echo $a | ./3.27`
    if [ x"$res" != x"$b" ] ; then
        echo TEST $a FAILED: expected "$b", got "$res"
    fi
done <<END
    2+20*6%10 2
    2^3+20*3 68
    (2+3)^2 25
    -(1-2) 1
    -(-1) 1
    (-5)^2 25
    (-5)^3 -125
    2*(1+9) 20
    2*(11-1)/(-2) -10
    100000*382/111^2 3100
END
