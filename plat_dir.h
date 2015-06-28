/* 
 * Copyright (c) 2015 lalawue
 * 
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the MIT license. See LICENSE for details.
 */

#ifndef PLAT_DIR_H
#define PLAT_DIR_H

#include <stdint.h>
#include "m_list.h"

#define MDIR_MAX_PATH 2048

#define MDIR_FILE       1
#define MDIR_DIRECOTRY  2
#define MDIR_UNKNOW     3

typedef struct s_dir_entry {
   int ftype;
   uint64_t fsize;
   int namlen;
   char *name;
} mdir_entry_t;

typedef struct s_mdir mdir_t;

mdir_t* mdir_open(const char *dir_path);
void mdir_close(mdir_t *d);

/* lst will be free when mdir close */
lst_t* mdir_list(mdir_t *d, int count);

int mdir_stat(const char *fpath, uint64_t *fsize, int *ftype);

char* mdir_getcwd(char *path_out, int out_len);
char* mdir_path_slash(char *path);

#endif
