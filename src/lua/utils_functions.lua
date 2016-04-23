--
--
-- some functions from quick-cocos2d-x, some by lalawue

local cjson = require("cjson")

dbg = {}

function dbg.log(...)
   local arg = ...
   if arg then
      local str = '[Lua] ' .. string.format(...)
      print( str )
   else
      print("[Lua] empty params")
   end
end

function dbg.table( tbl )
   if tbl then
      table.walk(tbl, function(v,k) print(k,"[" .. v .."]") end)
   end
end


--
--
-- 
json = {}

function json.unpack( jsonStr )
   if jsonStr then
      return cjson.decode( jsonStr )
   end
   return {}
end

function json.pack(err_code, err_msg, itbl)
   local rtbl = {}
   rtbl.error_code = string.format("%d", err_code)
   rtbl.error_msg = " "
   if err_msg and type(err_msg)=="string" then
      rtbl.error_msg = err_msg
   end

   if itbl then
      for k, v in pairs(itbl) do
         rtbl[k] = v
      end
   end

   --dbg.table(rtbl)
   return cjson.encode(rtbl)
end


--
--
-- 
agent = {}

function agent.raw(err_code, err_msg, itbl)
end

function agent.readFile( filePath )
   local retData = nil
   if filePath then
      local fp = io.open(filePath, "r")
      if fp then
         retData = fp:read("*a")
         fp:close()
      end
   end
   return retData
end

function agent.writeFile( filePath, fileData )
   if filePath and fileData then
      local fp = io.open(filePath, "w")
      if fp then
         local ret, errMsg = fp:write( fileData )
         if ret == nil then
            dbg.log("Fail to write file: %s, [%s]", fileName, errMsg)
         end
         fp:flush()
         return true
      end
   end
   return false
end


--
--
-- 


--[[--

去除输入字符串头部的空白字符，返回结果

~~~ lua

local input = "  ABC"
print(string.ltrim(input))
-- 输出 ABC，输入字符串前面的两个空格被去掉了

~~~

空白字符包括：

-   空格
-   制表符 \t
-   换行符 \n
-   回到行首符 \r

@param string input 输入字符串

@return string 结果

@see string.rtrim, string.trim

]]
function string.ltrim(input)
    return string.gsub(input, "^[ \t\n\r]+", "")
end

--[[--

去除输入字符串尾部的空白字符，返回结果

~~~ lua

local input = "ABC  "
print(string.ltrim(input))
-- 输出 ABC，输入字符串最后的两个空格被去掉了

~~~

@param string input 输入字符串

@return string 结果

@see string.ltrim, string.trim

]]
function string.rtrim(input)
    return string.gsub(input, "[ \t\n\r]+$", "")
end

--[[--

去掉字符串首尾的空白字符，返回结果

@param string input 输入字符串

@return string 结果

@see string.ltrim, string.rtrim

]]
function string.trim(input)
    input = string.gsub(input, "^[ \t\n\r]+", "")
    return string.gsub(input, "[ \t\n\r]+$", "")
end


--[[--

用指定字符或字符串分割输入字符串，返回包含分割结果的数组

~~~ lua

local input = "Hello,World"
local res = string.split(input, ",")
-- res = {"Hello", "World"}

local input = "Hello-+-World-+-Quick"
local res = string.split(input, "-+-")
-- res = {"Hello", "World", "Quick"}

~~~

@param string input 输入字符串
@param string delimiter 分割标记字符或字符串

@return array 包含分割结果的数组

]]
function string.split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    -- for each divider found
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end





--[[--

创建一个类

~~~ lua

-- 定义名为 Shape 的基础类
local Shape = class("Shape")

-- ctor() 是类的构造函数，在调用 Shape.new() 创建 Shape 对象实例时会自动执行
function Shape:ctor(shapeName)
    self.shapeName = shapeName
    printf("Shape:ctor(%s)", self.shapeName)
end

-- 为 Shape 定义个名为 draw() 的方法
function Shape:draw()
    printf("draw %s", self.shapeName)
end

--

-- Circle 是 Shape 的继承类
local Circle = class("Circle", Shape)

function Circle:ctor()
    -- 如果继承类覆盖了 ctor() 构造函数，那么必须手动调用父类构造函数
    -- 类名.super 可以访问指定类的父类
    Circle.super.ctor(self, "circle")
    self.radius = 100
end

function Circle:setRadius(radius)
    self.radius = radius
end

-- 覆盖父类的同名方法
function Circle:draw()
    printf("draw %s, raidus = %0.2f", self.shapeName, self.raidus)
end

--

local Rectangle = class("Rectangle", Shape)

function Rectangle:ctor()
    Rectangle.super.ctor(self, "rectangle")
end

--

local circle = Circle.new()             -- 输出: Shape:ctor(circle)
circle:setRaidus(200)
circle:draw()                           -- 输出: draw circle, radius = 200.00

local rectangle = Rectangle.new()       -- 输出: Shape:ctor(rectangle)
rectangle:draw()                        -- 输出: draw rectangle

~~~

### 高级用法

class() 除了定义纯 Lua 类之外，还可以从 C++ 对象继承类。

比如需要创建一个工具栏，并在添加按钮时自动排列已有的按钮，那么我们可以使用如下的代码：

~~~ lua

-- 从 CCNode 对象派生 Toolbar 类，该类具有 CCNode 的所有属性和行为
local Toolbar = class("Toolbar", function()
    return display.newNode() -- 返回一个 CCNode 对象
end)

-- 构造函数
function Toolbar:ctor()
    self.buttons = {} -- 用一个 table 来记录所有的按钮
end

-- 添加一个按钮，并且自动设置按钮位置
function Toolbar:addButton(button)
    -- 将按钮对象加入 table
    self.buttons[#self.buttons + 1] = button

    -- 添加按钮对象到 CCNode 中，以便显示该按钮
    -- 因为 Toolbar 是从 CCNode 继承的，所以可以使用 addChild() 方法
    self:addChild(button)

    -- 按照按钮数量，调整所有按钮的位置
    local x = 0
    for _, button in ipairs(self.buttons) do
        button:setPosition(x, 0)
        -- 依次排列按钮，每个按钮之间间隔 10 点
        x = x + button:getContentSize().width + 10
    end
end

~~~

class() 的这种用法让我们可以在 C++ 对象基础上任意扩展行为。

既然是继承，自然就可以覆盖 C++ 对象的方法：

~~~ lua

function Toolbar:setPosition(x, y)
    -- 由于在 Toolbar 继承类中覆盖了 CCNode 对象的 setPosition() 方法
    -- 所以我们要用以下形式才能调用到 CCNode 原本的 setPosition() 方法
    getmetatable(self).setPosition(self, x, y)

    printf("x = %0.2f, y = %0.2f", x, y)
end

~~~

**注意:** Lua 继承类覆盖的方法并不能从 C++ 调用到。也就是说通过 C++ 代码调用这个 CCNode 对象的 setPosition() 方法时，并不会执行我们在 Lua 中定义的 Toolbar:setPosition() 方法。

@param string classname 类名
@param [mixed super] 父类或者创建对象实例的函数

@return table

]]
function class(classname, super)
    local superType = type(super)
    local cls

    if superType ~= "function" and superType ~= "table" then
        superType = nil
        super = nil
    end

    if superType == "function" or (super and super.__ctype == 1) then
        -- inherited from native C++ Object
        cls = {}

        if superType == "table" then
            -- copy fields from super
            for k,v in pairs(super) do cls[k] = v end
            cls.__create = super.__create
            cls.super    = super
        else
            cls.__create = super
            cls.ctor = function() end
        end

        cls.__cname = classname
        cls.__ctype = 1

        function cls.new(...)
            local instance = cls.__create(...)
            -- copy fields from class to native object
            for k,v in pairs(cls) do instance[k] = v end
            instance.class = cls
            instance:ctor(...)
            return instance
        end

    else
        -- inherited from Lua Object
        if super then
            cls = {}
            setmetatable(cls, {__index = super})
            cls.super = super
        else
            cls = {ctor = function() end}
        end

        cls.__cname = classname
        cls.__ctype = 2 -- lua
        cls.__index = cls

        function cls.new(...)
            local instance = setmetatable({}, cls)
            instance.class = cls
            instance:ctor(...)
            return instance
        end
    end

    return cls
end





--[[--

深度克隆一个值

~~~ lua

-- 下面的代码，t2 是 t1 的引用，修改 t2 的属性时，t1 的内容也会发生变化
local t1 = {a = 1, b = 2}
local t2 = t1
t2.b = 3    -- t1 = {a = 1, b = 3} <-- t1.b 发生变化

-- clone() 返回 t1 的副本，修改 t2 不会影响 t1
local t1 = {a = 1, b = 2}
local t2 = clone(t1)
t2.b = 3    -- t1 = {a = 1, b = 2} <-- t1.b 不受影响

~~~

@param mixed object 要克隆的值

@return mixed

]]
function clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs(object) do
            new_table[_copy(key)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end



--[[--

对表格中每一个值执行一次指定的函数，但不改变表格内容

~~~ lua

local t = {name = "dualface", comp = "chukong"}
table.walk(t, function(v, k)
    -- 输出每一个值
    print(v)
end)

~~~

fn 参数指定的函数具有两个参数，没有返回值。原型如下：

~~~ lua

function map_function(value, key)

end

~~~

@param table t 表格
@param function fn 函数

]]
function table.walk(t, fn)
    for k,v in pairs(t) do
        fn(v, k)
    end
end





--[[--

将 URL 中的特殊字符还原，并返回结果

~~~ lua

local input = "hello%20world"
print(string.urldecode(input))
-- 输出
-- hello world

~~~

@param string input 输入字符串

@return string 转换后的结果

@see string.urlencode

]]
function string.urldecode(input)
    input = string.gsub (input, "+", " ")
    input = string.gsub (input, "%%(%x%x)", function(h) return string.char(checknumber(h,16)) end)
    input = string.gsub (input, "\r\n", "\n")
    return input
end





--[[--

将 URL 中的特殊字符还原，并返回结果

~~~ lua

local input = "hello%20world"
print(string.urldecode(input))
-- 输出
-- hello world

~~~

@param string input 输入字符串

@return string 转换后的结果

@see string.urlencode

]]
function string.urldecode(input)
    input = string.gsub (input, "+", " ")
    input = string.gsub (input, "%%(%x%x)", function(h) return string.char(checknumber(h,16)) end)
    input = string.gsub (input, "\r\n", "\n")
    return input
end





--[[--

检查并尝试转换为数值，如果无法转换则返回 0

@param mixed value 要检查的值
@param [integer base] 进制，默认为十进制

@return number

]]
function checknumber(value, base)
    return tonumber(value, base) or 0
end


