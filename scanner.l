%{
/*
 * Simple example lex input file
 *
 * Shawn Ostermann -- Sept 11, 2022
 *
 * Headstart version
 */

#include <string.h>
#include <ctype.h>
#include "parser.tab.h"
#include "bash.h"

/* some internal files generated by bison */
void yyerror(const char *s,...);
void yywarn(const char *s,...);
int yywrap(void) {return(1);}    // should be in library, but here it is for github

/* useful global variables */
extern int debug;

/* Everything up to the funny characters on the next line */
/* goes directly into the lex.yy.c file */
%}



/* The rest of this after the '%%' is lex rules */
%%

[ \t]+	        { }  /* Just ignore white space */

"\n" 	        { return(EOLN); } 

%{
/* this rule will get you "started" with the WORD token.  As you work on the project,
   you'll need to update it to support other characters too... */
%}

"$""{"?[a-zA-Z_0-9]+"}"? {
    yylval.string = expandLine(yytext);
    return(WORD);
}



[A-Za-z0-9_]+"="([~\.a-zA-Z_!#$'%@^*&()+:;,?\[\]{0-9/-]+|\"([^"]*)\"|\'([^']+)\') {
    yylval.string = strdup(yytext);
    //remove quotation marks if any
    int stringLength = strlen(yylval.string);
    int stringPosition = 0;
    int colonCount = 0;
    for (int i = 0; i < stringLength; i++) {
        if (yylval.string[i] == '"' || yylval.string[i] == '\'') {
            continue;
        }
        else {
            if (yylval.string[i] == ':') {
                colonCount++;
            }
            yylval.string[stringPosition] = yylval.string[i];
            stringPosition++;
        }
    }
    yylval.string[stringPosition] = '\0'; //null terminate
    if (colonCount >= 199) {
        printf("Path directory list too long\n");
        fflush(stdout);
    } else {
        if (putenv(expandLine(yylval.string)) != 0 ) {
            perror(yylval.string);
        }
    };
}

\"([^"])+\" {
    if (debug) {
        printf("Found Quoted String\n");
    }
    yytext = strdup(yytext + 1);
    yytext[strlen(yytext) - 1] = '\0';
    yylval.string = strdup(expandLine(yytext));
    return(WORD);
}

\"$ {
    if (debug) {
        printf("Found Unterminated String\n");
    }
    yyerror("unterminated string");
}

\'([^']+)\' {
    if (debug) {
        printf("Found Single Quoted String");
    }
    yytext = strdup(yytext + 1);
    yytext[strlen(yytext) - 1] = '\0';
    yylval.string = strdup(yytext);
    
    return(WORD);
}

\' {
    yyerror("unterminated string");
}

[~\.a-zA-Z_!#$'%@^*&()+:;,?\[\]{0-9/-]+ {
    /* a "WORD" - will need to be modified */
    if (debug)
        printf("scanner saw WORD '%s'\n", yytext);
    yylval.string = strdup(expandLine(yytext));  /* make a copy of the string */
    return(WORD);
}


%{
/* you need rules for the other reserved characters below */

/* you will also need a rule that returns "strings" as WORDS */
%}



"|" {
    if(debug) {
        printf("Pipe seen");
    }
    yylval.string = strdup(yytext);
    return(PIPE);
}



"<" {
    if(debug) {
        printf("Input file found");
    }
    yylval.string = strdup(yytext);
    return(INFILE);
}

">>" {
    yylval.string = strdup(yytext);
    return(OUTFILE_APPEND);
}

">" {
    if (debug) {
        printf("Output file found");
    }
    yylval.string = strdup(yytext);
    return(OUTFILE);
}

"2>>" {
    if (debug) {
        printf("err file found append");
    }
    yylval.string = strdup(yytext);
    return(ERRFILE_APPEND);
}

"2>" {
    if (debug) {
        printf("err file found");
    }
    yylval.string = strdup(yytext);
    return(ERRFILE);
}





.		{
    /* if we haven't matched anything yet, then it's illegal */
    fprintf(stdout, "scanner: Bad character '%c'\n", *yytext);
}


%%