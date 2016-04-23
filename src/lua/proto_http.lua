--
-- by lalawue, 2016/03/25

local HTTP = class("HTTP")

HTTP_HEADER_CONTENT_TYPE   = "Content-Type"
HTTP_HEADER_CONTENT_LENGTH = "Content-Length"
HTTP_HEADER_SET_COOKIE     = "Set-Cookie"


function HTTP:ctor()
   self.header = {}
   self.hinfo = {}
end


local function proto_parse_path( hinfo )
   local s, e = string.find(hinfo.Path, "?")
   if s and e then
      
      local path = string.sub(hinfo.Path, 1, e-1)
      hinfo.Paths = string.split(path, "/")

      
      local args = string.sub(hinfo.Path, e+1)
      local atbl = string.split(args, "&")
      local tbl = {}
      for i, val in ipairs(atbl) do
         local t = string.split(val, "=")
         local k = string.urldecode(t[1])
         tbl[k] = string.urldecode(t[2])
      end
      hinfo.Args = tbl

      -- dbg.table( tbl )
   else
      -- dbg.log("%s", hinfo.Path)
      
      local s, e = string.find(hinfo.Path, "/")
      if s and e and string.len(hinfo.Path)>1 then
         hinfo.Paths = string.split(hinfo.Path, "/")
      else
         hinfo.Paths = { [1]="/" }
      end
      hinfo.Args = {}
   end
   -- dbg.table( hinfo.Paths )
end


local function proto_parse_cookie( hinfo )
   local cpath = hinfo.Cookie
   -- dbg.log("cookie: <%s>", cpath)
   if cpath then
      local tbl = {}
      for _, kval in pairs(string.split(cpath, ";")) do
         kval = string.ltrim(kval)
         -- dbg.log("kval <%s>", kval)
         local k, v = string.match(kval, "(%w+)=(%w+)")
         if k and v then
            tbl[k] = v
         end
         -- dbg.log("v1 %s, v2 %s", v1, v2)
      end
      dbg.table(tbl)
      hinfo.Cookie = tbl
   else
      -- dbg.log("no cookies")
   end
end


local function proto_parse_domain( hinfo )
   local domain = hinfo.Host
   local port = "80"
   
   local s, e = string.find(domain, ":")
   if s and e then
      port = string.sub(domain, e+1)
      domain = string.sub(domain, 1, e-1)
   end
   hinfo.Domain = domain
   hinfo.Port = port
   -- dbg.log("host [%s:%s]", domain, port)
end


--
-- Method, Path, Paths, Args, Domain, Port
-- 
-- return status, header [body]
-- -1 - not html data
--  0 - full data in .Body
-- >0 - need more data
function HTTP:parse( rawData )
   local retCode = 0
   local htbl = string.split(rawData, "\r\n")


   -- 0, not html data
   local s, e = string.find(rawData, "\r\n\r\n")
   if htbl==nil or #htbl<=0 or (s or e)==nil then
      return -1, nil
   end


   self.header = htbl;
   local hinfo = self.hinfo


   local method = table.remove(htbl, 1)
   local tbl = string.split(method, " ")
   hinfo.Method = tbl[1]
   hinfo.Path = string.len(tbl[2])>1 and string.sub(tbl[2], 2) or "/"


   -- header table
   for i, entry in ipairs(htbl) do
      if string.len(entry) > 0 then
         local tbl = string.split(entry, ": ")
         hinfo[tbl[1]] = tbl[2]
      end
   end
   -- dbg.table(hinfo)
   

   proto_parse_path( hinfo )
   proto_parse_cookie( hinfo )
   proto_parse_domain( hinfo )


   -- <0, not need more data
   local len = hinfo[HTTP_HEADER_CONTENT_LENGTH]
   --print("---", len, e, string.len(rawData))
   if len and (e+len)>string.len(rawData) then
      --return ((e+len) - string.len(rawData)), hinfo
      retCode = (e+len) - string.len(rawData)
   end

   if retCode == 0 then
      hinfo.Body = string.sub(rawData, e)
   end

   return retCode, hinfo
end


-- return HTTP raw data
function HTTP:construct( code, header, bodyData )
   local outData = "HTTP/1.1"
   if code == 200 then
      outData = outData .. " 200 OK\r\n"
   end

   if bodyData then
      header[HTTP_HEADER_CONTENT_LENGTH] = string.len(bodyData)
   end
   
   for k, v in pairs(header) do
      outData = outData .. string.format("%s: %s\r\n", k, v)
   end
   outData = outData .. "\r\n"
   
   if bodyData then
      outData = outData .. bodyData
   end

   return outData
end

return HTTP
