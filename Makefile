#
# Shell2 lex/yacc Makefile
# Shawn Ostermann - Sept 27, 2022
#
CFLAGS   = -Wall -Werror -O2
CXXFLAGS = -Wall -Werror -O2
CC = gcc
CXX = g++

PROGRAM = bash
ALLCFILES  = ${wildcard *.c}
CFILES  = ${filter-out parser.tab.c lex.yy.c ,${ALLCFILES}}
CCFILES = ${wildcard *.cc}
HFILES = bash.h 


##################################################
#
# You shouldn't need to change anything else
#
##################################################


# all of the .o files that the program needs that are user-created
OBJECTS = ${CFILES:.c=.o} ${CCFILES:.cc=.o}



# How to make the whole program
${PROGRAM} : ${OBJECTS} parser.tab.h parser.tab.o lex.yy.o
	${CXX} ${CFLAGS} ${OBJECTS} lex.yy.o parser.tab.o -o ${PROGRAM} 


# 
# Turn the parser.y file into parser.tab.c using "bison"
# 

parser.tab.c : parser.y ${HFILES}
	bison -dvt ${YFLAGS} parser.y
parser.tab.o: parser.tab.c
	${CC} ${CFLAGS} -c parser.tab.c
parser.tab.h: parser.tab.c


# 
#  Turn the scanner.l file into lex.yy.c using "lex"
# 
lex.yy.c : scanner.l parser.tab.h ${HFILES}
	flex ${LFLAGS} scanner.l
lex.yy.o: lex.yy.c
	${CC} ${CFLAGS} -Wno-unused-function -g -c lex.yy.c

#
# File dependencies
#
${OBJECTS}: ${HFILES} parser.tab.h

test: bash
	-chmod a+rx ./test.?
	-for TEST in ./test.?; do echo "$$TEST: "; $$TEST; done
	
clean: cleanbuild cleantest

cleantest:
	/bin/rm -f *.o lex.yy.c y.output parser.tab.c ${PROGRAM} parser.h parser.output *.tab.c *.tab.h core 

cleanbuild:
	/bin/rm -f test.*.myoutput test.*.correct test.*.input test.*.unixoutput tmp.* typescript
	/bin/rm -rf tmpdir.dir
	
