/* 
 * Copyright (c) 2015 lalawue
 * 
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the MIT license. See LICENSE for details.
 */

/* code from 'http://blog.csdn.net/langeldep/article/details/6264058',
 * no license mentioned
 */

#ifndef UTILS_URL_H
#define UTILS_URL_H

#ifdef __cplusplus
extern "C" {
#endif

   int url_decode(char *str, int len);
   char *url_encode(char const *s, int len, int *new_length);

#ifdef __cplusplus
}
#endif

#endif
