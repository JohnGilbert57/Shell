/*
 * Headstart for Ostermann's shell project
 *
 * Shawn Ostermann -- Sept 11, 2022
 */
 
#include <string.h>
#include <iostream>
#include <regex>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/wait.h>

using namespace std;

// types and definitions live in "C land" and must be flagged
extern "C" {
#include "parser.tab.h"
#include "bash.h"


extern "C" void yyset_debug(int d);
}

// global debugging flag
int debug = 0;

char* expandLine(char* line) {
    regex envVar("\\$\\{?[a-zA-Z0-9_]+\\}?");
    regex removedEnvChars("\\$|\\{|\\}");
    string expandedString = line;
    smatch match;
    while (regex_search(expandedString, match, envVar)) {
        string foundEnvVar = match.str();
        foundEnvVar = regex_replace(foundEnvVar, removedEnvChars, "");
        regex foundEnvVarStringPattern("\\$\\{?" + foundEnvVar + "\\}?");
        char* replacementValue = getenv(foundEnvVar.c_str());
        if (replacementValue == NULL) {
            replacementValue = strdup("");
        }
        expandedString = regex_replace(expandedString, foundEnvVarStringPattern, replacementValue);
    }
    return strdup(&expandedString[0]);
}


void printPrompt() {
    char* ps1 = getenv("PS1");
    if (ps1 != NULL) {
        printf("%s", ps1);
        fflush(stdout);
    }
}

void dolineDebug(struct command *pcmd) {
    int argCount = 0;
    int pipeCount = 1;
    while (pcmd != NULL) {
        printf("Command name: '%s'\n", pcmd->command);
        while (pcmd->argv[argCount] != NULL) {
            printf("    argv[%d]: '%s'\n", argCount, pcmd->argv[argCount]);
            argCount++;
        }
        if (pcmd->infile == NULL) {
            printf("  stdin:  UNDIRECTED\n");
        } else if (strcmp(pcmd->infile, "|") == 0) {
            printf("  stdin:  PIPE%d\n", pipeCount);
            pipeCount++;
        } else {
            printf("  stdin:  '%s'\n", pcmd->infile);
        }
        if (pcmd->outfile == NULL) {
            printf("  stdout: UNDIRECTED"); 
        } else if (strcmp(pcmd->outfile, "|") == 0) {
            printf("  stdout: PIPE%d", pipeCount);
        } else {
            printf("  stdout: '%s'", pcmd->outfile);
        }
        (pcmd->output_append == '1') ? printf(" (append)\n") : printf("\n");
        (pcmd->errfile == NULL) ? printf("  stderr: UNDIRECTED") : printf("  stderr: '%s'", pcmd->errfile);
        (pcmd->error_append == '1') ? printf(" (append)\n") : printf("\n");
        argCount = 0;
        pcmd = pcmd->next;
    }
    printf("\n");
}

void doEcho (struct command *pcmd) {
    int argCount = 1;
    while (pcmd->argv[argCount] != NULL) {
        printf("%s", pcmd->argv[argCount]);
        if(pcmd->argv[argCount + 1] != NULL) {
            printf(" ");
        }
        argCount++;
    }
    printf("\n");
    fflush(stdout);
}


string findPath (char* commandName) {
    string currentPath = "";
    char* path = getenv("PATH");
    if (path == NULL) {
        return NULL;
    }
    int pathLen = strlen(path);
    for (int i = 0; i < pathLen; i++) {
        if(path[i] == ':') {
            currentPath = currentPath + '/' + commandName;
            if (access(currentPath.c_str(), X_OK) == 0) {
                return currentPath;
            }
            currentPath = "";
        } else {
            currentPath += path[i];
        }
    }
    return "";
}

void runCommand(string path, char** argv) {
    execv(path.c_str(), argv);
    perror(path.c_str());
    _exit(-1);
}

void openRedirectionFiles(struct command *pcmd) {
    if (pcmd->infile != NULL) {
        int inputFile = open(pcmd->infile, O_RDONLY);
        if(inputFile == -1) {
            perror(pcmd->infile);
            _exit(-1);
        }
        dup2(inputFile, STDIN_FILENO);
        close(inputFile);
    }
    if (pcmd->outfile != NULL) {
        if (strcmp(pcmd->outfile, "|") == 0) {
            printf("I don't implement pipes\n");
            fflush(stdout);
            _exit(-1);
        }
        int outputFile = pcmd->output_append == '1' ? open(pcmd->outfile, O_WRONLY | O_APPEND): open(pcmd->outfile, O_WRONLY | O_CREAT, 0644);
        if (outputFile == -1) {
            perror(pcmd->outfile);
            _exit(-1);
        }
        dup2(outputFile, STDOUT_FILENO);
        close(outputFile);
    }

    if (pcmd->errfile != NULL) {
        int errorFile = pcmd->error_append == '1' ? open(pcmd->errfile, O_WRONLY | O_APPEND) : open(pcmd->errfile, O_WRONLY | O_CREAT, 0644);
        if(errorFile == -1) {
            perror(pcmd->errfile);
            _exit(-1);
        }
        dup2(errorFile, STDERR_FILENO);
        close(errorFile);
    }
}


void doFork(struct command *pcmd) {
    if (fork() == 0) {
        // I am the child
        openRedirectionFiles(pcmd);
        if (pcmd->command[0] == '/' || pcmd->command[0] == '.') {
            runCommand(pcmd->command, pcmd->argv);
        }
        string path = findPath(pcmd->command);
        if (path != "") {
            runCommand(path, pcmd->argv);
        } else {
            printf("%s: command not found\n", pcmd->command);
            fflush(stdout);
            _exit(-1);
        }
    } else {
        // picking up the kids
        wait(NULL);
    }
}

void changeDirectory(char* path) {
    if (chdir(path) != 0) {
        printf("%s: No such file or directory\n", path);
    }
}

void doChangeDirectory(struct command *pcmd) {
    if (pcmd->argv[1] == NULL) {
        changeDirectory(getenv("HOME"));
    } else if (pcmd->argv[1] != NULL && pcmd->argv[2] != NULL) {
        printf("'cd' requires exactly one argument\n");
    } else {
        changeDirectory(pcmd->argv[1]);
    }
}

void doline (struct command *pcmd) {
    if (strcmp(pcmd->command, "echo") == 0) {
        doEcho(pcmd);
    } else if (strcmp(pcmd->command, "cd") == 0) {
        doChangeDirectory(pcmd);
    } else {
        doFork(pcmd);
    }
}

int main (int argc, char *argv[]) {
    if (debug)
        yydebug = 1;  /* turn on ugly YACC debugging */
    /* parse the input file */
    
    yyparse();
    exit(0);
}