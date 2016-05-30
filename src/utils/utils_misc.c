/* 
 * Copyright (c) 2015 lalawue
 * 
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the MIT license. See LICENSE for details.
 */

#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "m_mem.h"
#include "m_debug.h"
#include "utils_misc.h"

#define _err(...) _mlog("utils", D_ERROR, __VA_ARGS__)

unsigned long misc_get_file_size(char *path) {
   unsigned long fsize = 0;
   FILE *fp = fopen(path, "rb");
   if ( fp ) {
      if (fseek(fp, 0, SEEK_END) == 0) {
         fsize = ftell(fp);
         fclose(fp);
      }
      else {
         goto err_get_fsize;
      }
   }
   else {
     err_get_fsize:
      _err("fail to get file size '%s'\n", path);
   }
   return fsize;
}

int misc_check_file_ro(char *filename) {
   if ( filename ) {
      FILE *fp = fopen(filename, "rb");
      if ( fp ) {
         fclose(fp);
         return 1;
      }
   }
   return 0;
}

char* misc_read_file(char* fileName, unsigned long *len) {
   char *data = NULL;
   if (fileName && len) {
      FILE *fp = fopen(fileName, "rb");
      if (fp == NULL) { return NULL; }
      fseek(fp, 0, SEEK_END);
      *len = ftell(fp);
      data = (char*)mm_malloc(*len+1);
      assert(data);
      memset(data, 0, *len+1);
      rewind(fp);
      fread(data, 1, (unsigned long)*len, fp);
      fclose(fp);
   }
   return data;
}

int misc_write_file(char* fileName, char *buf, unsigned long len) {
   int ret = 0;
   if (fileName && buf && len > 0) {
      FILE *fp = fopen(fileName, "wb");
      if ( fp ) {
         ret = (int)fwrite(buf, 1, len, fp);
         fclose(fp);
         return ret;
      }
   }
   return ret;
}

char* misc_truncate_str(char *str, int len, char ch) {
   if ( str ) {
      while (str[len]!=ch && (--len > 0));
      if (str[len] == ch) str[len] = 0;
   }
   return str;
}

char* misc_strdup(char *from) {
   char *to = NULL;
   if ( from ) {
      unsigned len = (unsigned)strlen(from);
      to = (char*)mm_malloc(len + 1);
      strcpy(to, from);
   }
   return to;
}

char*
misc_locate_chr(char *str, int *len, char ch) {
   if ( str ) {
      int i = *len - 1;
      while (i>=0 && str[i]!=ch) { i--; }
      if (i < 0) { return str; }
      *len = *len - (++i);
      return &str[i];
   }
   return NULL;
}
