#!/bin/bash
#
# students must NOT change this file in any way!!!
PATH=/bin:/usr/bin
TEST=$0

#
# make sure the umask is at the default
umask 0022

# I need this routine
cat > tmp.stat << 'END'
#!/bin/sh
PATH=/bin:/usr/bin
for FILE in $*; do
        /bin/echo "`ls -l $FILE | colrm 11` `wc $FILE | awk '{printf(\"%6s %6s %6s %s\n\", $1, $2, $3, $4);}'`"
done       
END
chmod a+rx tmp.stat

# this is the input lines to use
cat > $0.input << 'END'
echo STARTING

echo "Pipe test"

echo "if you don't implement pipes, then you need good messages saying so!"

echo "Quick directory test!"
cat < test.8 | egrep '[a-z]{5,99}' | tr a-z A-Z | grep -i secret | grep DENIED | sort | uniq

rm -f tmp.e1 tmp.e2 tmp.e3
echo "This should run, but generate errors in the stderr log files"
cat /badfile1 2>tmp.e1 | cat /badfile2 2>tmp.e2 | cat /badfile3 2>tmp.e3
./tmp.stat tmp.e1 tmp.e2 tmp.e3
head tmp.e1 tmp.e2 tmp.e3

echo "And this should generate 3 syntax errors"
cat /badfile1 <tmp.i1 | cat /badfile2 <tmp.i2 | cat /badfile3 <tmp.i3

echo "And this tests to make sure that you don't run ANY of the piped commands if redir is bad"
/bin/echo "test" | tr a-z A-Z < nosuchfile | /bin/echo "I DON'T WORK CORRECTLY"

END

# this is the correct output
# this is the output they should create
cat > $TEST.correct << 'END'
Pipe test
if you don't implement pipes, then you need good messages saying so!
Quick directory test!
TMP.SECRET: PERMISSION DENIED
This should run, but generate errors in the stderr log files
-rw-r--r--      1      7     42 tmp.e1
-rw-r--r--      1      7     42 tmp.e2
-rw-r--r--      1      7     42 tmp.e3
==> tmp.e1 <==
cat: /badfile1: No such file or directory
==> tmp.e2 <==
cat: /badfile2: No such file or directory
==> tmp.e3 <==
cat: /badfile3: No such file or directory
And this should generate 3 syntax errors
Error on line 17: illegal redirection
Error on line 17: illegal redirection
And this tests to make sure that you don't run ANY of the piped commands if redir is bad
Error on line 20: illegal redirection
END

# don't change anything else
echo "export PS1=''; umask 0022; ./bash < $0.input; exit" | script -q > /dev/null 2>&1
sed 's/\r//g' typescript | grep STARTING -A 100000 | grep -v STARTING | awk '/exit/{exit} {print}' | grep  -v '^Script done' | egrep -v '^$' > $TEST.myoutput


if cmp -s $TEST.correct $TEST.myoutput; then
    echo "PASSES"; exit 0
else
    echo "FAILS"; 
    echo '==== output differences: < means the CORRECT output, > means YOUR output'
    diff $TEST.correct $TEST.myoutput
    exit 99
fi
