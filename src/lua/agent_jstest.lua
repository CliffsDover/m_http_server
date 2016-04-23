--
-- by lalawue, 2016/03/31

local JSTest = class("JSTest")

function JSTest:ctor()
end

function JSTest:processData( cinfo )
   local hinfo = cinfo.hinfo
   local proto = cinfo.proto

   local cmd = string.lower( hinfo.Paths[ #hinfo.Paths ] )
   cmd = string.gsub(cmd, "%.", "_")
   cmd = string.gsub(cmd, "%-", "_")
   dbg.log("jstest cmd [%s]", cmd);

   -- for k, v in pairs(self.class) do
   --    print(k, v)
   -- end

   if type(self.class[cmd]) == "function" then
      local f = self.class[cmd]
      -- dbg.log("f %s", f)

      local rheader = {}
      rheader[HTTP_HEADER_CONTENT_TYPE] = "text/html"
      
      local rdata = f(self, proto, hinfo, rheader)
      return ServStatus_SendFullData, rdata
   end
   
   return ServStatus_NotInterest, string.format("JSTest no such function: %s", cmd)
end

function JSTest:index_do(proto, hinfo, rheader)
   -- dbg.table( hinfo.Args )
   local filePath = string.format("data/%s",hinfo.Args.file)
   local rdata = agent.readFile( filePath )
   if rdata == nil then
      rdata = '<html><body>try another function please</body></html>'
   end
   return proto:construct(200, rheader, rdata)
end

return JSTest

