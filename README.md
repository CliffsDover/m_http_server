
# About

Cross platform HTTP Server support browser download/upload files, include iOS/MacOSX/Linux/Windows demo.



# iOS demo

iOS demo is under ios directory, open the xcode project and run the example.



# MacOSX demo

Just make, and provide computer's ip address, port and directory

```
# make
# ./http_serv.out 192.168.1.101 1234 /tmp
```

Then open your browser and address 'http://192.168.1.101:1234' to visit.


# Linux Demo

Like under MacOSX, make and run, make sure the directory your can read/write.



# Windows demo

Windows demo was under win directory, open the .sln solution, set directory in argv input parameter, 
run the example, then open your browser and address 'http://127.0.0.1:1234' to visit.



# Note

Files was filtered in plat_dir.c, internal UTF-8 charset.
