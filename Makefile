
CC=gcc
CFLAGS= -g -Wall -std=c99

SRCS := $(shell find src -name "*.c")
DIRS := $(shell find src -type d)

INCS := $(foreach n, $(DIRS), -I$(n))

all: http_serv.out

http_serv.out: $(SRCS)
	$(CC) $(CFLAGS) $(INCS) -o $@ $^ -DTEST_CLIENT_HTTP_SERV

clean:
	rm -rf *.out *.dSYM
