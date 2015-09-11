/* 
 * Copyright (c) 2015 lalawue
 * 
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the MIT license. See LICENSE for details.
 */

#ifdef _WIN32
#include <windows.h>
#include <direct.h> 
#endif

int
charset_to_prog(
   const char *from, char *tmp, int tmplen, char *to, int tolen) {
#ifdef _WIN32
   int len = MultiByteToWideChar(CP_OEMCP, NULL, (LPCCH)from, -1, (LPWSTR)tmp, tmplen);
   return WideCharToMultiByte(CP_UTF8, NULL, (LPCWCH)tmp, len, to, tolen, NULL, NULL);
#else
   return 0;
#endif
}

/* to system local */
int
charset_to_sysm(
   const char *from, char *tmp, int tmplen, char *to, int tolen) {
#ifdef _WIN32
   int len = MultiByteToWideChar(CP_UTF8, NULL, (LPCCH)from, -1, (LPWSTR)tmp, tmplen);
   return WideCharToMultiByte(CP_OEMCP, NULL, (LPCWCH)tmp, len, to, tolen, NULL, NULL);
#else
   return 0;
#endif
}
