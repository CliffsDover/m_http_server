-- 
-- by lalawue, 2016/04/09

-- 
-- key module
-- 
-- client and its http request management
-- 
-- cid 1st info for GET, last info for POST
-- 

local cmgnt = {
   ["cids"] = {}
   --[[
      cid {
          infos {
              [1] = {
                  proto,
                  hinfo,
                  dataleft,     -- POST, GET
                  fp,           -- GET
                  head          -- not used now
              }
          }
      }
   --]]
}

function cmgnt.newinfo( cid )
   if not cmgnt.cids[cid] then
      cmgnt.cids[cid] = {}
   end

   local c = cmgnt.cids[cid]
   if c.infos then
      c.infos[ #c.infos + 1] = {
         ["id"] = #c.infos + 1,
         ["cid"] = cid
      }
      dbg.log("old info %d, %s", #c.infos, cid)
   else
      c.infos = {
         [1] = {
            ["id"] = 1,
            ["cid"] = cid
         }
      }
      dbg.log("new info %s", cid)
   end
   return c.infos[ #c.infos ]
end

function cmgnt.firstinfo( cid )
   local c = cmgnt.cids[cid]
   if c then
      if #c.infos > 0 then
         -- dbg.log("firstinfo")
         return c.infos[ 1 ]
      end
   end
   return nil
end

function cmgnt.lastinfo( cid )
   local c = cmgnt.cids[cid]
   if c then
      if #c.infos > 0 then
         -- dbg.log("lastinfo %s", cid)
         return c.infos[ #c.infos ]
      end
   end
   return nil
end

function cmgnt.infocount( cid )
   local c = cmgnt.cids[cid]
   if c then
      return #c.infos
   end
   return -1
end

-- only remove 1st info
function cmgnt.rminfo( cid, pos )
   local c = cmgnt.cids[cid]
   if c and pos then
      if #c.infos > 0 then
         if pos == "first" then
            -- dbg.log("rminfo 1 %s", cid)
            table.remove(c.infos, 1)
         elseif pos == "last" then
            -- dbg.log("rminfo last, %s", cid)
            table.remove(c.infos, #c.infos)
         end
      end

      if #c.infos <= 0 then
         cmgnt.cids[cid] = nil
      end
   end
end

return cmgnt
