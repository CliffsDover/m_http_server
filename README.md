
# About

Simple HTTP Server support browser download/upload files (HTTP GET/POST), include iOS demo, 
cross platform and very suitable for embedded env, components comes frome m_mem/m_buf/m_list/m_plat repos.

iOS demo is under ios dir, open the xcode project and run the example.

Under MacOSX, just

```
# make
# ./http_serv.out ~/Desktop
```

then open your browser and address 'http://127.0.0.1:1234' to visit your Desktop normal files (files was filtered in plat_dir.c).

internal UTF-8 charset.