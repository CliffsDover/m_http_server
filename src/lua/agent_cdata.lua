-- 
-- by lalawue, 2016/04/03

local CData = class("CData")

function CData:ctor()
end

function CData:processData( cinfo )
   local hinfo = cinfo.hinfo
   local proto = cinfo.proto
   
   local cmd = string.lower( hinfo.Paths[ #hinfo.Paths ] )
   cmd = string.gsub(cmd, "%.", "_")
   cmd = string.gsub(cmd, "%-", "_")
   dbg.log("cdata cmd [%s]", cmd)

   if type(self.class[cmd]) == "function" then
      local f = self.class[cmd]

      local rheader = {}
      rheader[HTTP_HEADER_CONTENT_TYPE] = "text/html"

      local rtype, rdata = f(self, cinfo, hinfo, proto, rheader)
      return rtype, rdata
   end
end

function CData:get_file_do(cinfo, hinfo, proto, rheader)

   local fileName = hinfo.Args.file
   dbg.log("get file: %s", fileName)
   if fileName then
      local fp = io.open(string.format("data/%s",fileName), "rb")
      if fp == nil then
         dbg.log("Fail to open file: %s", fileName)
      else
         local fileSize = fp:seek("end", 0)
         fp:seek("set", 0)
         dbg.log("fileSize %d", fileSize)

         if fileSize then
            cinfo.dataleft = fileSize
            cinfo.fp = fp

            rheader[HTTP_HEADER_CONTENT_TYPE]   = "application/octet-stream"
            rheader[HTTP_HEADER_CONTENT_LENGTH] = fileSize
            return ServStatus_SendChunkedData, proto:construct(200, rheader, nil)
            -- return ServStatus_SendFullData,  proto:construct(200, rheader, nil)
         end
      end
   end
   return ServStatus_SendFullData, proto:construct(200, rheader, "File not exist or empty !")   
end

function CData:post_file_do(cinfo, hinfo, proto, rheader)

   local fileName = hinfo.Args.file
   dbg.log("post file: %s, %d", fileName, string.len(hinfo.Body))

   if fileName then
      local filePath = string.format("data/upload/%s", fileName)
      local ret = agent.writeFile(filePath, hinfo.Body)
      if ret then
         local rdata = string.format("File upload success: %s\n", fileName)
         return ServStatus_SendFullData, proto:construct(200, rheader, rdata)
      end
      dbg.log("Fail to save file: %s", fileName)
   end
   return ServStatus_SendFullData, proto:construct(200, rheader, "File upload fail")
end

return CData
