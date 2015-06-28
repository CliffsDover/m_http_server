
CC=gcc
CFLAGS= -g -Wall
SRC=plat_net.c plat_dir.c m_mem.c m_buf.c m_list.c m_debug.c utils_str.c utils_misc.c utils_url.c client_http_serv.c

all: http_serv.out

http_serv.out: $(SRC)
	$(CC) $(CFLAGS) -o $@ $^ -DTEST_CLIENT_HTTP_SERV

clean:
	rm -rf *.out *.dSYM
