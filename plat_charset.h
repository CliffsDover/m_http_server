/* 
 * Copyright (c) 2015 lalawue
 * 
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the MIT license. See LICENSE for details.
 */

#ifndef PLAT_CHARSET_H
#define PLAT_CHARSET_H

 /* to utf-8 */
int charset_to_prog(
   const char *from, char *tmp, int tmplen, char *to, int tolen);

/* to system local, in Win CP936, is GBK/GB2312 */
int charset_to_sysm(
   const char *from, char *tmp, int tmplen, char *to, int tolen);

#endif
