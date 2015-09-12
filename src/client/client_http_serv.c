/* 
 * Copyright (c) 2015 lalawue
 * 
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the MIT license. See LICENSE for details.
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

#include "m_mem.h"
#include "m_buf.h"
#include "m_list.h"
#include "m_debug.h"

#include "plat_type.h"
#include "plat_net.h"

#include "utils_str.h"
#include "utils_url.h"
#include "utils_misc.h"

#include "client_http_serv.h"

/* only support 1 file now
 */

#define _err(...) _mlog("http", D_ERROR, __VA_ARGS__)
#define _info(...) _mlog("http", D_INFO, __VA_ARGS__)

//#define HTTP_CLIENT_DEBUG_BOUNDARY

#define HTTP_CLIENT_BUF_SIZE (MNET_BUF_SIZE)
#define HTTP_CLIENT_BUF_GAP  (8192) /* 8192bytes for searching boundary */

enum {
   HTTP_PAGE_TEST,
   HTTP_PAGE_404,
   HTTP_PAGE_UPLOAD,
   HTTP_PAGE_DOWNLOAD,
   HTTP_PAGE_MOVED,
};

typedef struct {
   int error;                   /* 0 default */
   int method;                  /* GET/POST */

   str_t *path;                 /* GET path */
   str_t *boundary;             /* multipart/form-data boundary */
   int bn_count;                /* POST boundary count, 2 meets end */

   str_t *fname;                /* POST file name */

   str_t *content;              /* post content */
   int64_t total_length;        /* post/get content length */
   int64_t bytes_consumed;      /* post/get content recv/send */

   FILE *fp;
} http_info_t;

typedef struct {
   chann_t *tcp;
   buf_t *buf;
   http_info_t info;
   lst_node_t *node;
} http_client_t;

typedef struct {
   int running;
   chann_t *tcp;                /* for listen */
   buf_t *buf;
   lst_t *clients_lst;
   client_http_serv_cb cb;
   client_http_serv_config_t conf;
} http_serv_t;

static http_serv_t _g_hs;

static int  _http_process_proto(http_client_t *c);
static void _hinfo_destroy(http_info_t *info);
static void _http_send_file_data(http_client_t *c);

static inline http_serv_t* _hs(void) {
   return &_g_hs;
}

static inline http_client_t*
_http_client_create(chann_t *n) {
   http_serv_t *hs = _hs();
   http_client_t *c = (http_client_t*)mm_malloc(sizeof(*c));
   c->tcp = n;
   c->buf = buf_create(HTTP_CLIENT_BUF_SIZE * 2);
   c->node = lst_pushl(hs->clients_lst, c);
   _info("http client create %p, %d\n", c, lst_count(hs->clients_lst));
   return c;
}

/* check hs runing for chann's callback in _tcp_chann_cb */
static inline void
_http_client_destroy(http_client_t *c, int close_chann) {
   http_serv_t *hs = _hs();
   if (!hs->running) { return; }
   buf_destroy(c->buf);
   _hinfo_destroy(&c->info);
   lst_remove(hs->clients_lst, c->node);
   if (close_chann) {
      mnet_chann_close(c->tcp);
   }
   mm_free(c);
   _info("http client destroy %p, %d\n", c, lst_count(hs->clients_lst));
}

static void
_tcp_chann_cb(chann_event_t *e) {
   http_serv_t *hs = _hs();
   if (!hs->running) { return; }

   http_client_t *c = (http_client_t*)e->opaque;
   if (e->event == MNET_EVENT_RECV) {
      buf_t *b = c->buf;
      int ret = mnet_chann_recv(e->n, buf_addr(b,buf_ptw(b)), buf_available(b));
      if (ret > 0) {
         buf_forward_ptw(b, ret);
         int consume = _http_process_proto(c);
         if (consume > 0) {
            //http_info_t *info = &c->info;
            //_info("%lld/%lld, %d/%d\n", info->bytes_consumed, info->total_length, consume, buf_buffered(b));

            assert(consume <= buf_buffered(b));
            memmove(buf_addr(b,0), buf_addr(b,consume), buf_buffered(b)-consume);
            buf_forward_ptw(b, -consume);
         }
         //_info("buf buffered %d\n", buf_buffered(b));
      }
   }
   else if (e->event == MNET_EVENT_CLOSE) {
      //_err("close event\n");
      _http_client_destroy((http_client_t*)e->opaque, 0);
   }
   else if (e->event == MNET_EVENT_SEND) {
      _http_send_file_data((http_client_t*)e->opaque);
   }
}

static void
_tcp_listen_cb(chann_event_t *e) {
   if (e->event == MNET_EVENT_ACCEPT) {
      http_client_t *c = _http_client_create(e->r);
      mnet_chann_set_cb(e->r, _tcp_chann_cb, c);
   }
}

static int
_parse_header_method(str_t *head, http_info_t *info) {
   static char* method[2] = { "GET ", "POST " };

   for (int i=0; i<2; i++) {
      if (str_locate(head, method[i], 0) == 0) {
         str_t *lst = str_split(head, " ", 0);
         if (lst && str_next(lst)) {
            info->method = i + HTTP_METHOD_GET;
            info->path = str_dup(str_next(lst));
            return 1;
         }
      }
   }

   info->method = HTTP_METHOD_INVALID;
   return 0;
}

static int
_parse_header_in_post(str_t *head, http_info_t *info) {
   if (str_locate(head, "Content-Length:", 1) == 0) {
      str_t *f = str_find(head, "Content%-Length: +(%d+)", 0);
      if ( f ) {
         info->total_length = atoll(str_cstr(f));
         //_info("content length %lld\n", info->total_length);
         return 1;
      }
   }
   else if (str_locate(head, "Content-Type:", 1) == 0) {
      str_t *slst = str_split(head, "; ", 0);
      str_t *bn = str_find(str_next(slst), "boundary=([%-%w]+)", 0);
      if ( bn ) {
         info->boundary = str_dup(bn);
         //_info("boundary: [%s]\n", str_cstr(info->boundary));
         return 1;
      }
   }
   return 0;
}

static inline void
_post_content_update(http_info_t *info, char *buf, int len) {
   if (info->content) { str_destroy(info->content); }
   info->content = str_clone_cstr(buf, len);
   //_info("info update content %d\n", str_len(info->content));
}

static inline void
_post_content_destroy(http_info_t *info) {
   if (info->content) {
      str_destroy(info->content);
      info->content = NULL;
   }
}

static int
_hinfo_create(buf_t *b, http_info_t *info) {
   int consume = 0;
   str_t *shead = str_clone_cstr((const char*)buf_addr(b,0), buf_buffered(b));

   int header_eof = str_locate(shead, "\r\n\r\n", 0);
   if (header_eof<=0 || (header_eof+4)>str_len(shead)) {
      goto fail;
   }
   header_eof += 4;
   consume = header_eof;

   memset(info, 0, sizeof(*info));

   str_t *entries = str_split(str_sub(shead, 0, header_eof), "\r\n", 0);
   str_foreach(e, entries) {
      //str_debug(s, -1, 0);

      if (info->method == HTTP_METHOD_INVALID) {
         if (_parse_header_method(e, info) > 0) {
            continue;
         }
      }
      else if (info->method == HTTP_METHOD_POST) {
         if (_parse_header_in_post(e, info) > 0) {
            continue;
         }
      }
   }
   _info(">>> http info create %p, method:%d\n", info, info->method);

  fail:
   str_destroy(shead);
   return consume;
}

static inline void
_serv_state_update(
   client_http_serv_state_t *st, http_client_t *c, int state)
{
   http_info_t *info = &c->info;
   http_serv_t *hs = _hs();

   memset(st, 0, sizeof(*st));

   st->opaque = hs->conf.opaque;
   st->client_id = *((int*)c);

   st->method = info->method;
   st->state = state;

   if (st->method == HTTP_METHOD_GET) {
      st->path = str_cstr(info->path);
      st->path_len = str_len(info->path);
   }
   else {
      st->path = str_cstr(info->fname);
      st->path_len = str_len(info->fname);
   }

   if ( info->content ) {
      st->buf = str_cstr(info->content);
      st->buf_len = str_len(info->content);
   }

   st->total_length = info->total_length;
   st->bytes_consumed = info->bytes_consumed;
}

/* description: update info in post method */
static int
_hinfo_update_in_post(http_client_t *c, buf_t *b, int spos) {
   int consume = 0;
   http_serv_t *hs = _hs();
   http_info_t *info = &c->info;

#ifdef HTTP_CLIENT_DEBUG_BOUNDARY
   if (info->fp == NULL) {
      info->fp = fopen("/Users/user/Desktop/cc.png", "wb");
   }
   _post_content_update(info, (char*)buf_addr(b,0), buf_buffered(b));
#else
   str_t *sinput = str_clone_cstr((char*)buf_addr(b,spos), buf_buffered(b)-spos);
   str_t *sbn = info->boundary;
   str_t *shead = sinput;

   while (info->bn_count < 2) {
      if (info->bn_count <= 0) {
         int bn_pos = str_bsearch(shead, sbn);
         if (bn_pos < 0) {
            goto func_end;
         }

         int boundEnd = str_locate(shead, "\r\n\r\n", 0);
         if (boundEnd<0 || (boundEnd+4)>str_len(sinput)) {
            goto func_end;
         }
         boundEnd += 4;
         consume = boundEnd;
         info->bytes_consumed += boundEnd;

         str_t *fn = str_find(shead, "filename=\"([^\"]+)\"", 0);
         if ( fn ) {
            //_info("POST fname "); str_debug(fn, -1, 0);
            info->fname = str_dup(fn);
            if ( hs->cb ) {
               client_http_serv_state_t st;
               _serv_state_update(&st, c, HTTP_CB_STATE_BEGIN);
               hs->cb(&st);
            }
            //info->fp = fopen("/Users/user/Desktop/cc.png", "wb"); // save for debug
         } else {
            _err("fail to find name\n");
         }

         _post_content_update(info, str_cstr(shead) + boundEnd, str_len(shead) - boundEnd);

         shead = info->content;
         info->bn_count++;
         _info("POST 1 boundary, content left %d\n", str_len(info->content));
      }
      else if (info->bn_count == 1) {
         int64_t left = (info->total_length - info->bytes_consumed);
         
         if ((left - str_len(shead)) > HTTP_CLIENT_BUF_GAP) {
            _post_content_update(info, str_cstr(shead), str_len(shead));
         }
         else if (left <= (int64_t)str_len(shead)) {
            int bn_pos = str_bsearch(shead, sbn);
            if (bn_pos < 0) {
               goto func_end;
            }
            bn_pos -= 4;        /* '\r\n--' */

            /* consume the rest of file content */
            consume += str_len(shead) - bn_pos;
            info->bytes_consumed += str_len(shead) - bn_pos;

            _post_content_update(info, str_cstr(shead), bn_pos);
            info->bn_count++;
            _info("POST 2 boundary, content left %d, %d\n", str_len(info->content), bn_pos);
         }

         break;
      }
   }

  func_end:
   str_destroy(sinput);
#endif
   return consume;
}

static int
_hinfo_update_in_get(http_client_t *c, char *path) {
   http_info_t *info = &c->info;
   if (info->fp == NULL) {
      info->fp = fopen(path, "rb");
      if (info->fp && (fseek(info->fp, 0, SEEK_END)>=0)) {
         info->total_length = ftell(info->fp);
         rewind(info->fp);
         _info("GET total length [%lld]\n", info->total_length);
         return 1;
      }
   }
   return info->fp != NULL;
}

void
_hinfo_destroy(http_info_t *info) {
   if ( info ) {
      if (info->path) { str_destroy(info->path); }
      if (info->boundary) { str_destroy(info->boundary); }
      if (info->fname) { str_destroy(info->fname); }
      if (info->content) { str_destroy(info->content); }
      if (info->fp) { fclose(info->fp); }
      memset(info, 0, sizeof(*info));
      _info("<<< http info destroy %p\n", info);
   }
}

static inline buf_t*
_http_page_header(http_client_t *c) {
   http_serv_t *hs = _hs();
   buf_t *b = buf_create(512);
   buf_fmt(b, "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2 Final//EN\">");
   buf_fmt(b, "<html><header><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">");
   buf_fmt(b, "<title>%s</title>", hs->conf.title);
   buf_fmt(b, "<meta name=\"viewport\" content=\"width=device-width, user-scalable=no\">");
   buf_fmt(b, "</header><body><h1>Files come from '%s'</h1><p>Shared files from '%s':</p>",
           hs->conf.dev_name, hs->conf.dev_name);
   buf_fmt(b, "<table border=\"0\" width=\"100%%\"><tr>");
   buf_fmt(b, "<td>Name</td><td align=\"right\" width=\"30%%\">Size</td></tr>");
   buf_fmt(b, "<tr><td colspan=\"2\"><hr></hr></td></tr>");
   return b;
}

static inline buf_t*
_http_page_footer(http_client_t *c) {
   buf_t *b = buf_create(512);
   buf_fmt(b, "<tr><td colspan=\"2\"><hr></hr></td></tr>");
   buf_fmt(b, "<tr><td colspan=\"2\">");
   buf_fmt(b, "<form method=\"post\" enctype=\"multipart/form-data\">");
   buf_fmt(b, "<label>Upload File:  <input type=\"file\" name=\"file\" />");
   buf_fmt(b, "</label><label><input type=\"submit\" name=\"button\" />");
   buf_fmt(b, "</label></form></td></tr><tr><td colspan=\"2\">");
   buf_fmt(b, "<hr></hr></td></tr></table>");
   buf_fmt(b, "<address>Embeded HTTP Server</address></body></html>");
   return b;
}

static inline buf_t*
_http_page_body(http_client_t *c) {
   http_serv_t *hs = _hs();
   buf_t *b = buf_create(384*1024);

   mdir_t *md = mdir_open(hs->conf.dpath);
   if (md == NULL) { goto fail; };

   lst_t *lst = mdir_list(md, 1024);
   if (lst == NULL) { goto fail; };

   char tmp[MDIR_MAX_PATH];
   lst_foreach(it, lst) {
      mdir_entry_t *e = (mdir_entry_t*)lst_iter_data(it);
      if (e->ftype == MDIR_FILE) {
         strncpy(tmp, e->name, e->namlen);
         tmp[e->namlen] = 0;
         {
            int len = 0;
            char *link = url_encode(tmp, e->namlen, &len);
            buf_fmt(b, "<tr><td><a href=\"%s\">%s</a></td>", link, tmp);
            buf_fmt(b, "<td align=\"right\">%.2f MB</td></tr>", e->fsize/(double)(1<<20));
            mm_free(link);
         }
      }
   }

  fail:
   mdir_close(md);
   return b;
}

void
_http_send_file_data(http_client_t *c) {
   http_info_t *info = &c->info;

   if (info->bytes_consumed < info->total_length) {
      int64_t bytes_left = (info->total_length - info->bytes_consumed);
      buf_t *b = buf_create(HTTP_CLIENT_BUF_SIZE);
      int min_len = (int)_MIN_OF(bytes_left, buf_available(b));
      int readed = (int)fread(buf_addr(b,buf_ptw(b)), 1, min_len, info->fp);
      buf_forward_ptw(b, readed);
      info->bytes_consumed += readed;
      mnet_chann_send(c->tcp, buf_addr(b,0), buf_buffered(b));
      buf_destroy(b);
      _info("GET send file data %lld/%lld\n", info->bytes_consumed, info->total_length);
   } else {
      _info("GET cancel send event, stop sending data\n");
      mnet_chann_active_event(c->tcp, MNET_EVENT_SEND, 0);
      _hinfo_destroy(info);
   }
}

static void
_http_page_send(http_client_t *c, int ptype) {
   buf_t *page = NULL;
   if (ptype == HTTP_PAGE_TEST) {
      page = buf_create(1024);
      buf_fmt(page, "HTTP/1.1 200 OK\r\n");
      buf_fmt(page, "Content-Length: 62\r\n\r\n");
      buf_fmt(page, "<html><title>Test</title><body><h1>It works</h1></body></html>");
   }
   else if (ptype == HTTP_PAGE_404) {
      page = buf_create(1024);
      buf_fmt(page, "HTTP/1.1 404 Not Found\r\n");
      buf_fmt(page, "Content-Length: 0\r\n\r\n");
   }
   else if (ptype == HTTP_PAGE_UPLOAD) {
      buf_t *header = _http_page_header(c);
      buf_t *body = _http_page_body(c);
      buf_t *footer = _http_page_footer(c);
      if (header && body && footer) {
         int hlen = buf_buffered(header);
         int blen = buf_buffered(body);
         int flen = buf_buffered(footer);
         page = buf_create(64 + hlen + blen + flen);
         buf_fmt(page, "HTTP/1.1 200 OK\r\n");
         buf_fmt(page, "Content-Length: %u\r\n\r\n", hlen + blen + flen);
         buf_fmt(page, "%s", buf_addr(header,0));
         buf_fmt(page, "%s", buf_addr(body,0));
         buf_fmt(page, "%s", buf_addr(footer,0));
      }

      if (header) { buf_destroy(header); }
      if (  body) { buf_destroy(body); }
      if (footer) { buf_destroy(footer); }
   }
   else if (ptype == HTTP_PAGE_DOWNLOAD) {
      http_info_t *info = &c->info;
      if (info->bytes_consumed <= 0) {
         buf_t *b = buf_create(MNET_BUF_SIZE);
         buf_fmt(b, "HTTP/1.1 200 OK\r\n");
         buf_fmt(b, "Content-Type: application/octet-stream\r\n");
         buf_fmt(b, "Content-Length: %u\r\n\r\n", info->total_length);
         mnet_chann_send(c->tcp, buf_addr(b,0), buf_buffered(b));
         buf_destroy(b);
      }
      if (info->bytes_consumed < info->total_length) {
         _info("GET active send event, begin sending data\n");
         mnet_chann_active_event(c->tcp, MNET_EVENT_SEND, 1); /* active send event */
         //_http_send_file_data(c);
      }
   }
   else if (ptype == HTTP_PAGE_MOVED) {
      http_serv_t *hs = _hs();
      page = buf_create(1024);
      buf_fmt(page, "HTTP/1.1 301 Moved Permanently\r\n");
      buf_fmt(page, "Content-Type: text/html\r\n");
      buf_fmt(page, "Content-Length: 57\r\n");
      buf_fmt(page, "Connection: keep-alive\r\n");
      buf_fmt(page, "Location: http://%s:%d/\r\n\r\n", hs->conf.ipaddr, hs->conf.port);
      buf_fmt(page, "<html><body><h1>301 Moved Permanently</h1></body></html>");
   }
   /* else if (ptype == 101) { */
   /*    page = buf_create(1024); */
   /*    buf_fmt(page, "HTTP/1.1 200 OK\r\n"); */
   /*    buf_fmt(page, "Content-Length: 0\r\n\r\n"); */
   /* } */

   if (  page ) {
      //_info("page send: (%d)\n[%s]\n", buf_buffered(page), (char*)buf_addr(page,0));
      mnet_chann_send(c->tcp, buf_addr(page,0), buf_buffered(page));
      buf_destroy(page);
   }
}

static int
_http_consume_content(http_client_t *c) {
   int consume = 0;
   http_serv_t *hs = _hs();
   http_info_t *info = &c->info;

   str_t *s = info->content;
   if (str_len(s) > 0) {
      consume = str_len(s);

#if 0
      if (info->fp) {
#ifdef HTTP_CLIENT_DEBUG_BOUNDARY
         if (info->bytes_consumed < 1024) {
            fwrite(str_cstr(s), 1, consume, info->fp);
         }
         else if ((info->total_length - info->bytes_consumed) <= HTTP_CLIENT_BUF_SIZE) {
            fwrite(str_cstr(s), 1, consume, info->fp);
         }
#else
         fwrite(str_cstr(s), 1, consume, info->fp);
#endif
         fflush(info->fp);
      }
#endif
      info->bytes_consumed += str_len(s);
      if ( hs->cb ) {
         client_http_serv_state_t st;
         _serv_state_update(&st, c, HTTP_CB_STATE_CONTINUE);
         hs->cb(&st);
      }
      _post_content_destroy(info);

      /* _info("write data to file [total:%f]\n", */
      /*       (float)(info->bytes_consumed/(float)info->total_length)); */
   }
   return consume;
}

/* description: return bytes consumed
 */
int
_http_process_proto(http_client_t *c) {
   int consume = 0;
   buf_t *b = c->buf;
   http_serv_t *hs = _hs();
   http_info_t *info = &c->info;

   /* if (info->bytes_consumed <= 0) { */
   /*    _info("req get data %d:\n[[%s]]\n---\n", buf_buffered(b), buf_addr(b,0)); */
   /* } */

   if (info->method == HTTP_METHOD_INVALID) {
      consume = _hinfo_create(b, info);
      if (consume > 0) {
         if (info->method == HTTP_METHOD_GET) {
            char fpath[MDIR_MAX_PATH] = {0};
            int min_len = _MIN_OF(MDIR_MAX_PATH, str_len(info->path));
            strncpy(fpath, str_cstr(info->path), min_len);
            url_decode(fpath, min_len);
            _info("GET [%s], addr %s\n", fpath, mnet_chann_addr(c->tcp));

            if ( hs->cb ) {
               client_http_serv_state_t st;
               _serv_state_update(&st, c, HTTP_CB_STATE_BEGIN);
               hs->cb(&st);
            }

            if (str_len(info->path) <= 0) {
               info->error = 1;
               _http_page_send(c, HTTP_PAGE_404);
            }
            else if (str_cmp(info->path, "/", 0) == 0) {
               _http_page_send(c, HTTP_PAGE_UPLOAD);
            }
            else {
               char path[MDIR_MAX_PATH] = {0};
               int pos = 0;
               pos += snprintf(&path[pos], MDIR_MAX_PATH - pos, "%s/", hs->conf.dpath);
               pos += snprintf(&path[pos], MDIR_MAX_PATH - pos, "%s", fpath);

               if ( misc_check_file_ro(path) ) {
                  if ( _hinfo_update_in_get(c, path) ) {
                     _http_page_send(c, HTTP_PAGE_DOWNLOAD);
                  }
               } else {
                  _http_page_send(c, HTTP_PAGE_404);
               }
            }
         }
         else if (info->method == HTTP_METHOD_POST) {
            char path[MDIR_MAX_PATH] = {0};
            strncpy(path, str_cstr(info->path), str_len(info->path));
            url_decode(path, str_len(info->path));

            _info("POST [%s], addr %s\n", path, mnet_chann_addr(c->tcp));

            consume += _hinfo_update_in_post(c, b, consume);
            if (info->bn_count >= 2) {
               if (info->content && str_len(info->content)>0) {
                  consume += _http_consume_content(c);
               } else {
                  _err("content invalid !\n");
               }
            }
            //_http_page_send(c, HTTP_PAGE_MOVED);
         }
      }
   }
   else if (info->method == HTTP_METHOD_POST) {
      consume += _hinfo_update_in_post(c, b, consume);
      if (info->content && str_len(info->content)>0) {
         consume += _http_consume_content(c);
      } else {
         _err("content invalid !\n");
      }
   }

   if (info->error || (info->bytes_consumed >= info->total_length)) {
      if ( hs->cb ) {
         client_http_serv_state_t st;
         _serv_state_update(&st, c, HTTP_CB_STATE_END);
         hs->cb(&st);
      }
      if (info->method == HTTP_METHOD_POST) {
         _http_page_send(c, HTTP_PAGE_MOVED);
      }
      _hinfo_destroy(info);
   }

   //_info("consume %d\n", consume);
   return consume;
}

int client_http_serv_open(
   client_http_serv_config_t *conf,
   client_http_serv_cb cb)
{
   http_serv_t *hs = _hs();
   if (!hs->running && conf) {
      hs->conf = *conf;
      hs->cb = cb;
      hs->clients_lst = lst_create();

      _info("client open dir [%s]\n", conf->dpath);

      hs->buf = buf_create(2048);
      hs->tcp = mnet_chann_open(CHANN_TYPE_STREAM);

      mnet_chann_set_cb(hs->tcp, _tcp_listen_cb, hs);
      mnet_chann_listen(hs->tcp, conf->port);

      hs->running = 1;
   }
   return hs->running;
}

void client_http_serv_close(void) {
   http_serv_t *hs = _hs();
   if ( hs->running ) {
      while (lst_count(hs->clients_lst) > 0) {
         _http_client_destroy((http_client_t*)lst_first(hs->clients_lst), 1);
      }
      lst_destroy(hs->clients_lst);
      mnet_chann_close(hs->tcp);
      buf_destroy(hs->buf);
      hs->running = 0;
   }
}

#ifdef TEST_CLIENT_HTTP_SERV

typedef struct {
   FILE *fp;
} cb_data_t;

static void
_main_http_serv_cb(client_http_serv_state_t *st) {
   http_serv_t *hs = _hs();
   cb_data_t *d = (cb_data_t*)st->opaque;
   if (st->method == HTTP_METHOD_GET) {
      return;
   }
   switch (st->state) {
      case HTTP_CB_STATE_BEGIN: {
         client_http_serv_config_t *conf = &hs->conf;
         char path[MDIR_MAX_PATH] = {0};
         int n = sprintf(path, "%s/", conf->dpath);
         strncpy(&path[n], st->path, st->path_len);
         d->fp = fopen(path, "wb");
         _info("POST begin [%s]\n", path);
         break;
      }
      case HTTP_CB_STATE_CONTINUE: {
         _info("POST continue %lld/%lld\n", st->bytes_consumed, st->total_length);
         if (d->fp && st->buf_len>0) {
            fwrite(st->buf, 1, st->buf_len, d->fp);
         }
         break;
      }
      case HTTP_CB_STATE_END: {
         _info("POST end %lld/%lld\n", st->bytes_consumed, st->total_length);
         if (d->fp) {
            fclose(d->fp);
            d->fp = NULL;
         }
         break;
      }
   }
}

int main(int argc, char *argv[]) {

   debug_open("stdout");
   debug_set_option(D_OPT_TIME);

   if (argc != 4) {
      _err("%s [IP] [PORT] [DIR_PATH_TO_BROWSE]\n", argv[0]);
      debug_close();
      return 0;
   }

   char *ipaddr = argv[1];
   int port = atoi(argv[2]);
   char *dpath = argv[3];

   _info("\n");
   _info("listen on http://%s:%d\n", ipaddr, port);
   _info("\n");

   mnet_init();

   cb_data_t cbdata = { NULL };
   client_http_serv_config_t conf = {
      port, "", "Lalawue's MacOSX", "iMac", "", &cbdata,
   };
   strcpy(conf.ipaddr, ipaddr);
   strcpy(conf.dpath, dpath);


   if (client_http_serv_open(&conf, _main_http_serv_cb) > 0) {

      for (;;) {
         mnet_check(1);
      }

      client_http_serv_close();
   }

   debug_close();
   return 0;
}
/*
  gcc -g -Wall -I../model/ -I../plat/ -I../utils ../plat/plat_net.c ../plat/plat_dir.c ../model/m_mem.c ../model/m_buf.c ../model/m_list.c ../model/m_debug.c ../utils/utils_str.c ../utils/utils_misc.c ../utils/utils_url.c client_http_serv.c -DTEST_CLIENT_HTTP_SERV
*/
#endif
