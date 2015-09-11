/* 
 * Copyright (c) 2015 lalawue
 * 
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the MIT license. See LICENSE for details.
 */

#ifndef CLIENT_HTTP_SERV_H
#define CLIENT_HTTP_SERV_H

#include <stdint.h>
#include "plat_dir.h"

enum {
   HTTP_METHOD_INVALID = 0,
   HTTP_METHOD_GET,
   HTTP_METHOD_POST,
};

enum {
   HTTP_CB_STATE_BEGIN,         /* method invoke */
   HTTP_CB_STATE_CONTINUE,      /* method continue */
   HTTP_CB_STATE_END,           /* method end */
};

/* for POST now */
typedef struct {
   void *opaque;                /* opaque from serv config */
   int client_id;

   int method;
   int state;

   char *path;                  /* file name for POST; path in GET */
   int path_len;

   char *buf;                   /* file data for POST; null in GET */
   int buf_len;

   int64_t total_length;        /* just for display or computing */
   int64_t bytes_consumed;
} client_http_serv_state_t;

typedef void (*client_http_serv_cb)(client_http_serv_state_t*);

typedef struct {
   int port;
   char ipaddr[64];
   char title[32];              /* title name */
   char dev_name[32];           /* device name in page*/
   char dpath[MDIR_MAX_PATH];   /* path to list/store */
   void *opaque;                /* opaque for serv state */
} client_http_serv_config_t;

int client_http_serv_open(client_http_serv_config_t*, client_http_serv_cb cb);
void client_http_serv_close(void);

#endif
