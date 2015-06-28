/* 
 * Copyright (c) 2015 lalawue
 * 
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the MIT license. See LICENSE for details.
 */

#ifndef UTILS_MISC_H
#define UTILS_MISC_H

#define _MAX_OF(A, B) (((A)>(B)) ? (A) : (B))
#define _MIN_OF(A, B) (((A)<(B)) ? (A) : (B))

int   misc_check_file_ro(char *filename);
char* misc_read_file(char* fileName, unsigned long *len);
int   misc_write_file(char* fileName, char *buf, unsigned long len);

char* misc_truncate_str(char *str, int len, char ch);
char* misc_strdup(char *from);
char* misc_locate_chr(char *str, int *len, char ch);

unsigned long misc_get_file_size(char *path);

#endif
