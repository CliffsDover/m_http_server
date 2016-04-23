--
-- by lalawue, 2016/03/25


-- 
-- Global Variable
-- 
package.path = string.format("%s;./src/lua/?.lua;", package.path)

require("utils_functions")
cmgnt = require("client_mgnt")

ServStatus_Invalid = -1
ServStatus_NotInterest = 0
ServStatus_NeedMoreData = 1
ServStatus_SendChunkedData = 2
ServStatus_SendFullData = 3


-- 
-- Local Variable
--
local ProtoHTTP = require("proto_http")

-- agents
-- 
local JSTest = require("agent_jstest")
local CData = require("agent_cdata")

local function _html_error_page( msg )
   local html = string.format("<html><p>%s</p></html>", msg)
   string.format(
      "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: %d\r\n\r\n%s",
      string.len(html), html)
end


local function _client_inputdata(cid, rawData)
   -- print(cid)
   -- print(rawData)
   -- print( client_tbl )
   -- print("---- exit Lua")

   local proto = nil
   local ret, hinfo = 0 ,nil

   local cinfo = cmgnt.lastinfo( cid )
   if not cinfo or cinfo.hinfo.Method=="GET" then

      proto = ProtoHTTP.new()
      ret, hinfo = proto:parse( rawData )

      cinfo = cmgnt.newinfo( cid )
      cinfo.hinfo = hinfo
      cinfo.proto = proto

      if ret>0 and hinfo.Method == "POST" then
         cinfo.dataleft = ret
      end

   else

      -- dbg.log("post ")

      cinfo.dataleft = cinfo.dataleft - string.len(rawData)
      if cinfo.payload then
         cinfo.payload = cinfo.payload .. rawData
      else
         cinfo.payload = rawData
      end

      if cinfo.dataleft > 0 then
         -- dbg.log("data left %d", cinfo.dataleft)
         return ServStatus_NeedMoreData, cinfo.dataleft
      else
         proto = cinfo.proto

         ret = 0
         hinfo = cinfo.hinfo
         hinfo.Body = cinfo.payload

         dbg.log("upload data complete %d", string.len(cinfo.payload))

         cmgnt.rminfo( cid, "last" )
      end

   end

   
   if ret < 0 then
      return ServStatus_NotInterest, "LuaServ not interesting"
   end

   
   if hinfo.Method=="POST" then
      if cinfo.dataleft and cinfo.dataleft>0 then
         return ServStatus_NeedMoreData, cinfo.dataleft
      end
   end


   if #hinfo.Paths < 1 then
      return ServStatus_NotInterest, "Not support: only top domain"
   end

   
   local subPath = hinfo.Paths[1]
   --dbg.log("subPath %d, %s", #hinfo.Paths, subPath)

   if subPath == "/" then
      return ServStatus_SendFullData, _html_error_page("Error path !!!")
   end

   local rtype, rdata = ServStatus_SendFullData, _html_error_page("error path")


   if subPath == "jstest" then
      local jt = JSTest.new()
      rtype, rdata = jt:processData( cinfo )
   end

   if subPath == "cdata" then
      local ca = CData.new()
      rtype, rdata = ca:processData( cinfo )
   end

   if rtype == ServStatus_SendFullData then
      cmgnt.rminfo(cid, "first")
   end

   return rtype, rdata
end

local function _lua_error_traceback(errmsg)
   local text = debug.traceback(tostring(errmsg), 8)
   print("======== TRACEBACK ========")
   print(text, "LUA ERROR")
   print("======== TRACEBACK ========")
end



--
-- Public Interface
-- 

-- Get raw data from Client
-- 
-- Return
-- 0 - not html data, LuaServ not interest
-- 1 - html header ok, LuaServ return data length needed
-- 2 - html header ok, LuaServ return http header, call OutputData next
-- 3 - html header ok, LuaServ return full data
function LuaServ_Client_InputData(cid, rawData)
   -- print("---- inside Lua")

   local ret, rtype, rdata = xpcall(
      _client_inputdata,
      _lua_error_traceback,
      cid, rawData)
   
   if ret then
      return rtype, rdata
   end
   
   return ServStatus_SendFullData, _html_error_page("lua internal error")
end


-- Output huge data to clients
-- 
-- return 
-- 0 - unset send event
-- 1 - send data
function LuaServ_Client_OutputData(cid)
   -- dbg.log("enter client output data")
   while cmgnt.infocount(cid) > 0 do

      local cinfo = cmgnt.firstinfo( cid )
      if cinfo.head then
         local rdata = cinfo.head
         cinfo.head = nil
         dbg.log("send header %d", cinfo.id)
         return 1, rdata
      end

      local rdata = cinfo.fp:read( 64*1024 )
      if rdata then
         cinfo.dataleft = cinfo.dataleft - string.len(rdata)
         -- dbg.log("file size left %d", cinfo.dataleft)
         return 1, rdata
      else
         -- dbg.log("close file, %d", cinfo.dataleft)
         cinfo.fp:close()
         
         cmgnt.rminfo( cid, "first" )
         
         if cmgnt.infocount(cid) > 0 then
            return 1, ""
         end
      end
   end
   -- dbg.log("---- cancel send event")
   return 0, "No more data"
end



-- clean internal client data
-- 
function LuaServ_Client_Close(cid)
   while cmgnt.infocount(cid) > 0 do
      cmgnt.rminfo(cid, "last")
   end
   -- dbg.log("clean client %s", cid)
end
