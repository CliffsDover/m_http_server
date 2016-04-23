/* 
 * Copyright (c) 2015 lalawue
 * 
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the MIT license. See LICENSE for details.
 */

#ifdef TEST_LUA_HTTP_SERV

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <unistd.h>

#include "m_mem.h"
#include "m_buf.h"
#include "m_list.h"
#include "m_debug.h"

#include "plat_net.h"

#include "utils_str.h"
#include "utils_url.h"
#include "utils_misc.h"

#include "lua_http_serv.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

/* only support 1 file now
 */

#define _err(...) _mlog("http", D_ERROR, __VA_ARGS__)
#define _info(...) _mlog("http", D_INFO, __VA_ARGS__)

typedef struct {
   lst_t *client_lst;
   chann_t *tcp_listen;
   lua_State *L;
   buf_t *buf_in;
   int in_len;
} ServState;

typedef struct {
   buf_t *buf_in;
   lua_State *L;
   int data_left;
   lst_node_t *node;
   ServState *serv;
} client_t;

static client_t*
_client_create(chann_t *n, ServState *serv) {
   client_t *c = mm_malloc(sizeof(*c));
   c->buf_in = buf_create( (MNET_BUF_SIZE>>1) );
   c->serv = serv;
   c->L = serv->L;
   c->node = lst_pushl(serv->client_lst, c);
   return c;
}

static void
_client_destroy(client_t *c) {
   ServState *serv = c->serv;
   lst_remove(serv->client_lst, c->node);
   buf_destroy(c->buf_in);
   mm_free(c);
}

static char*
_client_addr(char *cid, chann_t *n) {
   sprintf(cid, "%s:%d", mnet_chann_addr(n), mnet_chann_port(n));   
   return cid;
}

static void
_client_chann_cb(chann_event_t *e) {
   client_t *c = (client_t*)e->opaque;
   lua_State *L = c->L;
   
   switch (e->event) {
      case MNET_EVENT_RECV: {
         int wanted_len = 0;
         buf_t *b = c->buf_in;

         buf_reset(b);         
         if (c->data_left > 0) {
            wanted_len = _MIN_OF(buf_available(b), c->data_left);
         }
         else {
            wanted_len = buf_available(b);
         }

         int ret = mnet_chann_recv(e->n, buf_addr(b,0), wanted_len);
         if (ret <= 0) {
            mnet_chann_close(e->n);
            return;
         }
         
         lua_getglobal(L, "LuaServ_Client_InputData");
         if (lua_isfunction(L, -1)) {

            char cid[64] = {0};
            _client_addr(cid, e->n);
               
            lua_pushstring(L, cid);
            lua_pushlstring(L, (char*)buf_addr(b,0), ret);
               
            if (lua_pcall(L, 2, 2, 0) != 0) {
               //_info("fail to call lua function: client input data\n");
               luaL_error(L, "fail to call lua function: client input data");
            }
            else {
               int rtype = lua_tointeger(L, -2);
               /* _info("rtype %d\n", rtype); */


               /* lua server error */
               if (rtype == 0) {
                  size_t len = 0;
                  const char *data = lua_tolstring(L, -1, &len);
                  _info("Lua Error: [%s]\n", data);
               }

               /* need more data */
               if (rtype == 1) {
                  c->data_left = lua_tointeger(L, -1);
                  //_info("Lua need more data %d\n", c->data_left);
               }

               /* output chunked data */
               if (rtype == 2) {
                  mnet_chann_active_event(e->n, MNET_EVENT_SEND, 1);
               }

               /* raw data */
               if (rtype==2 || rtype==3) {
                  size_t len = 0;
                  const char *data = lua_tolstring(L, -1, &len);
                  if (data && len>0) {
                     //_info("%s\n", data);
                     if (mnet_chann_send(e->n, (char*)data, len) < 0) {
                        _err("fail to send data %d\n", ret);
                     }
                  }
                  c->data_left = 0;
               }

               lua_pop(L, 2);                  
            }
         }
         else {
            _info("lua not function: client input data\n");
         }
         break;
      }
      case MNET_EVENT_SEND: {
         lua_getglobal(L, "LuaServ_Client_OutputData");
         if (lua_isfunction(L, -1)) {
            char cid[64] = {0};
            _client_addr(cid, e->n);

            lua_pushstring(L, cid);
            if (lua_pcall(L, 1, 2, 0) == 0) {
               int rtype = lua_tointeger(L, -2);

               if (rtype == 0) {
                  mnet_chann_active_event(e->n, MNET_EVENT_SEND, 0);
               }

               if (rtype == 1) {
                  size_t len = 0;
                  const char *data = lua_tolstring(L, -1, &len);                  
                  if (mnet_chann_send(e->n, (char*)data, len) < 0) {
                     _err("fail to send data ...\n");
                  }
               }

               lua_pop(L, 2);
            }
            else {
            }
         }
         else {
            _info("lua not function: client close\n");
            lua_pop(L, 1);            
         }
         break;
      }
      case MNET_EVENT_CLOSE: {
         lua_getglobal(L, "LuaServ_Client_Close");
         if (lua_isfunction(L, -1)) {

            char cid[64] = {0};
            _client_addr(cid, e->n);
               
            lua_pushstring(L, cid);
            if (lua_pcall(L, 1, 0, 0) != 0) {
               _info("fail to call lua function: client close\n");
            }
         }
         else {
            _info("lua not function: client close\n");
            lua_pop(L, 1);            
         }
         _client_destroy(c);
         break;         
      }
      default: {
         break;
      }
   }
}

static void
_serv_listen_cb(chann_event_t *e) {
   if (e->event == MNET_EVENT_ACCEPT) {
      ServState *serv = (ServState*)e->opaque;
      client_t *c = _client_create(e->r, serv);
      if ( c ) {
         mnet_chann_set_cb(e->r, _client_chann_cb, c);
      }
   }
}

static ServState*
_serv_open(char *ipaddr, int port) {
   if (ipaddr && port>1024) {
      
      ServState *serv = mm_malloc(sizeof(ServState));
      
      chann_t *c = mnet_chann_open(CHANN_TYPE_STREAM);
      mnet_chann_set_cb(c, _serv_listen_cb, serv);
      
      if ( mnet_chann_listen_ex(c, ipaddr, port, 32) ) {

         serv->in_len = MNET_BUF_SIZE/2;
         serv->buf_in = buf_create(serv->in_len);
         serv->tcp_listen = c;
         serv->client_lst = lst_create();

         serv->L = luaL_newstate();
         luaL_openlibs(serv->L);
         int ret = luaL_loadfile(serv->L, "src/lua/main_server.lua") || lua_pcall(serv->L, 0, 0, 0);
         if (ret == LUA_OK) {
            _info("serv opened, load lua file OK.\n");
            return serv;
         }
         else {
            luaL_error(serv->L, "fail to load lua file");
            //_err("fail to load lua file\n");
         }
      }
      mnet_chann_close(c);
   }
   return NULL;
}

static void
_serv_close(ServState *serv) {
   buf_destroy(serv->buf_in);
   mnet_fini();
}

int main(int argc, char *argv[]) {

   debug_open("stdout");
   debug_set_option(D_OPT_TIME);

   if (argc != 3) {
      _err("%s [IP] [PORT]\n", argv[0]);
      debug_close();
      return 0;
   }

   char *ipaddr = argv[1];
   int port = atoi(argv[2]);

   _info("\n");
   _info("listen on http://%s:%d\n", ipaddr, port);
   _info("\n");

   mnet_init();

   ServState *serv = _serv_open(ipaddr, port);

   if (serv) {
      for (;;) {
         usleep(1);
         mnet_check(1);
      }
   }

   _serv_close(serv);

   debug_close();
   return 0;
}

#endif // TEST_LUA_HTTP_SERV
