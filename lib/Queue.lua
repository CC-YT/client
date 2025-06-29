-- lib/Queue.lua
local Queue = {}
Queue.__index = Queue

function Queue.new()
    return setmetatable({ first = 1, last = 0, data = {} }, Queue)
end

function Queue:push(v)
    self.last = self.last + 1
    self.data[self.last] = v
end

function Queue:pop()
    if self.first > self.last then return nil end
    local v = self.data[self.first]
    self.data[self.first] = nil
    self.first = self.first + 1
    return v
end

function Queue:count()
    return self.last - self.first + 1
end

return Queue