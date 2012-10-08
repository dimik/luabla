-- Copyright (c) 2009 Marcus Irven
--  
-- Permission is hereby granted, free of charge, to any person
-- obtaining a copy of this software and associated documentation
-- files (the "Software"), to deal in the Software without
-- restriction, including without limitation the rights to use,
-- copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following
-- conditions:
--  
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--  
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
-- OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
-- HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
-- OTHER DEALINGS IN THE SOFTWARE.

--- Underscore is a set of utility functions for dealing with 
-- iterators, arrays, tables, and functions.

local Underscore = { funcs = {} }
local _ = Underscore.funcs

Underscore.__index = Underscore

function Underscore.__call(_, value)
	return Underscore:new(value)
end

function Underscore:new(value, chained)
	return setmetatable({ _val = value, chained = chained or false }, self)
end

function Underscore.iter(iterable)
    if _.isFunction(iterable) then
        local count = 1
        return coroutine.wrap(function ()
            for i in iterable do
                coroutine.yield(i, count)
                count = count + 1
            end
        end)
    elseif _.isTable(iterable) then
        return coroutine.wrap(function ()
            for i = 1, #iterable do
                coroutine.yield(iterable[i], i, iterable)
            end
        end)
    end
end

function _.range(start_i, end_i, step)
	if end_i == nil then
		end_i = start_i
		start_i = 1
	end
	step = step or 1
	local range_iter = coroutine.wrap(function() 
		for i=start_i, end_i, step do
			coroutine.yield(i)
		end
	end)
	return Underscore:new(range_iter)
end

--- Identity function. This function looks useless, but is used throughout Underscore as a default.
-- @name _.identity
-- @param value any object
-- @return value
-- @usage _.identity("foo")
-- => "foo"
function Underscore.identity(value)
	return value
end

-- chaining

function Underscore:chain()
	self.chained = true
	return self
end

function Underscore:value()
	return self._val
end

-- iter

function _.each(obj, func)
    if _.isFunction(obj) or _.isArray(obj) then
        for v, i, l in Underscore.iter(obj) do
            func(v, i, l)
        end
    elseif _.isTable(obj) then
        for k, v in pairs(obj) do
            func(v, k, obj)
        end
    end
    return obj
end

function _.map(list, func)
	local mapped = {}
	for v, i, l in Underscore.iter(list) do
		mapped[#mapped+1] = func(v, i, l)
	end	
	return mapped
end

function _.reduce(list, memo, func)	
	for v, i, l in Underscore.iter(list) do
		memo = func(memo, v, i, l)
	end	
	return memo
end

function _.detect(list, func)
	for v, i, l in Underscore.iter(list) do
		if func(v, i, l) then return v end
	end	
	return nil	
end

function _.select(list, func)
	local selected = {}
	for v, i, l in Underscore.iter(list) do
		if func(v, i, l) then selected[#selected+1] = v end
	end
	return selected
end

function _.reject(list, func)
	local selected = {}
	for v, i, l in Underscore.iter(list) do
		if not func(v, i, l) then selected[#selected+1] = v end
	end
	return selected
end

function _.all(list, func)
	func = func or Underscore.identity
	
	-- TODO what should happen with an empty list?
	for v, i, l in Underscore.iter(list) do
		if not func(v, i, l) then return false end
	end
	return true
end

function _.any(list, func)
	func = func or Underscore.identity

	-- TODO what should happen with an empty list?	
	for v, i, l in Underscore.iter(list) do
		if func(v, i, l) then return true end
	end	
	return false
end

function _.include(list, value)
	for i in Underscore.iter(list) do
		if i == value then return true end
	end	
	return false
end

function _.invoke(list, function_name, ...)
	local args = {...}
	_.each(list, function(i) i[function_name](i, unpack(args)) end)
	return list
end

function _.pluck(list, propertyName)
	return _.map(list, function(i) return i[propertyName] end)
end

function _.min(list, func)
	func = func or Underscore.identity
	
	return _.reduce(list, { item = nil, value = nil }, function(min, item) 
		if min.item == nil then
			min.item = item
			min.value = func(item)
		else
			local value = func(item)
			if value < min.value then
				min.item = item
				min.value = value
			end
		end
		return min
	end).item
end

function _.max(list, func)
	func = func or Underscore.identity
	
	return _.reduce(list, { item = nil, value = nil }, function(max, item) 
		if max.item == nil then
			max.item = item
			max.value = func(item)
		else
			local value = func(item)
			if value > max.value then
				max.item = item
				max.value = value
			end
		end
		return max
	end).item
end

function _.isArray(obj)
    if _.isTable(obj) then
        return #obj > 0 and next(obj, #obj) == nil or _.isEmpty(obj)
    else
        return false
    end
end

function _.toArray(obj)
    local array = {}
    if _.isArray(obj) then
        return obj
    elseif _.isFunction(obj) then
        for i in Underscore.iter(obj) do
            array[#array+1] = i
        end
    elseif _.isTable(obj) then
        return _.values(obj)
    end
    return array
end

function _.reverse(list)
	local reversed = {}
	for i in Underscore.iter(list) do
		table.insert(reversed, 1, i)
	end	
	return reversed
end

function _.sort(iter, comparison_func)
	local array = iter
	if _.isFunction(iter) then
		array = _.toArray(iter)
	end
	table.sort(array, comparison_func)
	return array
end

-- arrays

function _.first(array, n)
	if n == nil then
		return array[1]
	else
		local first = {}
		n = math.min(n,#array)
		for i=1,n do
			first[i] = array[i]
		end
		return first
	end
end

function _.last(array)
    return array[#array]
end

function _.rest(array, index)
	index = index or 2
	local rest = {}
	for i=index,#array do
		rest[#rest+1] = array[i]
	end
	return rest
end

function _.slice(array, start_index, length)
	local sliced_array = {}
	
	start_index = math.max(start_index, 1)
	local end_index = math.min(start_index+length-1, #array)
	for i=start_index, end_index do
		sliced_array[#sliced_array+1] = array[i]
	end
	return sliced_array
end

function _.flatten(array)
	local all = {}
	
	for ele in Underscore.iter(array) do
		if _.isTable(ele) then
			local flattened_element = _.flatten(ele)
			_.each(flattened_element, function(e) all[#all+1] = e end)
		else
			all[#all+1] = ele
		end
	end
	return all
end

function _.push(array, item)
	table.insert(array, item)
	return array
end

function _.pop(array)
	return table.remove(array)
end

function _.shift(array)
	return table.remove(array, 1)
end

function _.unshift(array, item)
	table.insert(array, 1, item)
	return array
end

function _.join(array, separator)
	return table.concat(array, separator)
end

function _.uniq(array)
    local unique = {}
    _.each(array, function(i)
        unique[i] = true
    end)
    return _.keys(unique)
end

function _.zip(...)
    local args = {...}
    local length = #_.max(args, function (list) return #list end)
    local result = {}

    for i = 1, length do
        result[i] = _.pluck(args, i)
    end

    return result
end

function _.indexOf(array, value, from)
    local index
    from = from or 1
    if from < 0 then
        from = from + #array + 1
    end
    for i = from, #array do
        if array[i] == value then
            index = i
            break
        end
    end
    return index
end

-- objects

function _.isTable(obj)
    return type(obj) == 'table'
end

function _.keys(obj)
	local keys = {}
	for k,v in pairs(obj) do
		keys[#keys+1] = k
	end
	return keys
end

function _.values(obj)
	local values = {}
	for k,v in pairs(obj) do
		values[#values+1] = v
	end
	return values
end

function _.extend(destination, source)
	for k,v in pairs(source) do
		destination[k] = v
	end	
	return destination
end

function _.isEmpty(obj)
	return next(obj) == nil
end

-- Originally based on penlight's deepcompare() -- http://luaforge.net/projects/penlight/
function _.isEqual(o1, o2, ignore_mt)
	local ty1 = type(o1)
	local ty2 = type(o2)
	if ty1 ~= ty2 then return false end
	
	-- non-table types can be directly compared
	if ty1 ~= 'table' then return o1 == o2 end
	
	-- as well as tables which have the metamethod __eq
	local mt = getmetatable(o1)
	if not ignore_mt and mt and mt.__eq then return o1 == o2 end
	
	local isEqual = _.isEqual
	
	for k1,v1 in pairs(o1) do
		local v2 = o2[k1]
		if v2 == nil or not isEqual(v1,v2, ignore_mt) then return false end
	end
	for k2,v2 in pairs(o2) do
		local v1 = o1[k2]
		if v1 == nil then return false end
	end
	return true
end

-- functions

function _.isFunction(obj)
    return type(obj) == 'function'
end

function _.compose(...)
	local function call_funcs(funcs, ...)
		if #funcs > 1 then
			return funcs[1](call_funcs(_.rest(funcs), ...))
		else
			return funcs[1](...)
		end
	end
	
	local funcs = {...}
	return function(...)
		return call_funcs(funcs, ...)
	end
end

function _.wrap(func, wrapper)
	return function(...)
		return wrapper(func, ...)
	end
end

function _.curry(func, argument)
	return function(...)
		return func(argument, ...)
	end
end

function Underscore.functions() 
	return Underscore.keys(Underscore.funcs)
end

-- add aliases
Underscore.methods = Underscore.functions

_.for_each = _.each
_.collect = _.map
_.inject = _.reduce
_.foldl = _.reduce
_.filter = _.select
_.every = _.all
_.some = _.any
_.head = _.first
_.tail = _.rest
_.to_array = _.toArray
_.is_empty = _.isEmpty
_.is_table = _.isTable
_.is_equal = _.isEqual

local function wrap_functions_for_oo_support()
	local function value_and_chained(value_or_self)
		local chained = false
		if getmetatable(value_or_self) == Underscore then 
			chained = value_or_self.chained
			value_or_self = value_or_self._val 
		end
		return value_or_self, chained
	end

	local function value_or_wrap(value, chained)
		if chained then value = Underscore:new(value, true) end
		return value
	end

	for fn, func in pairs(Underscore.funcs) do
		Underscore[fn] = function(obj_or_self, ...)
			local obj, chained = value_and_chained(obj_or_self)	
			return value_or_wrap(func(obj, ...), chained)		
		end	 
	end
end

wrap_functions_for_oo_support()

return Underscore:new()
