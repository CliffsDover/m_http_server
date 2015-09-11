/* 
 * Copyright (c) 2015 lalawue
 * 
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the MIT license. See LICENSE for details.
 */

#ifndef MNET_H
#define MNET_H

#define MNET_BUF_SIZE (256*1024) /* 256kb */

enum {
   CHANN_TYPE_STREAM = 1,
   CHANN_TYPE_DGRAM,
   CHANN_TYPE_BROADCAST,
};

enum {
   CHANN_STATE_CLOSED,
   CHANN_STATE_CLOSING,
   CHANN_STATE_CONNECTING,
   CHANN_STATE_CONNECTED,
   CHANN_STATE_LISTENING,
};

enum {
   MNET_EVENT_RECV = 1,
   MNET_EVENT_ACCEPT,
   MNET_EVENT_CLOSE,
   MNET_EVENT_CONNECT,
   MNET_EVENT_DISCONNECT,
};

typedef struct s_mchann chann_t;
typedef struct {
   int event;
   chann_t *n;
   chann_t *r;
   void *ud;
} chann_event_t;

typedef void (*chann_cb)(chann_event_t*);

/* support limited connections */
int mnet_init(void);
void mnet_fini(void);

int mnet_check(int microseconds);

/* channels */
chann_t* mnet_chann_open(int type);
void mnet_chann_close(chann_t *n);

int mnet_chann_state(chann_t *n);

int mnet_chann_connect(chann_t *n, const char *host, int port);
#define mnet_chann_to(n,h,p) mnet_chann_connect(n,h,p) /* for UDP */

int mnet_chann_listen_ex(chann_t *n, const char *host, int port, int backlog);
#define mnet_chann_listen(n, p) mnet_chann_listen_ex(n, NULL, p, 5)

void mnet_chann_set_cb(chann_t *n, chann_cb cb, void *ud);

int mnet_chann_recv(chann_t *n, void *buf, int len);
int mnet_chann_send(chann_t *n, void *buf, int len);

int mnet_chann_cached(chann_t*n);
char* mnet_chann_addr(chann_t *n);

int64_t mnet_chann_bytes(chann_t *n, int be_send);

#endif
