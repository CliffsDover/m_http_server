
CC=gcc
CFLAGS= -g -Wall -std=c99

LUA_INCS=-I/usr/local/include
LUA_LIBS=-L/usr/local/lib

SRCS := $(shell find src -name "*.c")
DIRS := $(shell find src -type d)

INCS := $(foreach n, $(DIRS), -I$(n))

all: mk_dir http_serv.out lua_serv.out

http_serv.out: $(SRCS)
	$(CC) $(CFLAGS) $(INCS) -o out/$@ $^ -DTEST_CLIENT_HTTP_SERV

lua_serv.out: $(SRCS)
	$(CC) $(CFLAGS) $(INCS) $(LUA_INCS) $(LUA_LIBS) -llua -o out/$@ $^ -DTEST_LUA_HTTP_SERV

mk_dir:
	@mkdir -p out data/upload

clean:
	rm -rf out/*
