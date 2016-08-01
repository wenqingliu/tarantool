--UPSERT https://github.com/tarantool/tarantool/issues/905
env = require('test_run')
test_run = env.new()
s = box.schema.create_space('tweedledum')
index = s:create_index('pk')

s:upsert({0, 0}, {{'+', 2, 2}})
s:select{0}
s:delete{0}
s:upsert({0, 0, 0}, {{'+', 2, 2}})
s:select{0}
s:delete{0}
s:upsert({0}, {{'+', 2, 2}})
s:select{0}
s:replace{0, 1, 2, 4}
s:upsert({0, 0, "you will not see it"}, {{'+', 2, 2}})
s:select{0}
s:replace{0, -0x4000000000000000ll}
s:upsert({0}, {{'+', 2, -0x4000000000000001ll}})  -- overflow
s:select{0}
s:replace{0, "thing"}
s:upsert({0, "nothing"}, {{'+', 2, 2}})
s:select{0}
s:delete{0}
s:upsert({0, "thing"}, {{'+', 2, 2}})
s:select{0}
s:replace{0, 1, 2}
s:upsert({0}, {{'!', 42, 42}})
s:select{0}
s:upsert({0}, {{'#', 42, 42}})
s:select{0}
s:upsert({0}, {{'=', 42, 42}})
s:select{0}
s:replace{0, 1.5}
s:upsert({0}, {{'|', 1, 255}})
s:select{0}
s:replace{0, 1.5}
s:replace{0, 'something to splice'}
s:upsert({0}, {{':', 2, 1, 4, 'no'}})
s:select{0}
s:upsert({0}, {{':', 2, 1, 2, 'every'}})
s:select{0}
s:upsert({0}, {{':', 2, -100, 2, 'every'}})
s:select{0}
s:drop()

--UPSERT https://github.com/tarantool/tarantool/issues/966
test_run:cmd("setopt delimiter ';'")
function anything_to_string(tab)
    if tab == nil then
        return 'nil'
    end
    local str = '['
    local first_route = true
    local t = 0
    for k,f in pairs(tab) do
        if not first_route then str = str .. ',' end
        first_route = false
        t = t + 1
        if k ~= t then
            str = str .. k .. '='
        end
        if type(f) == 'string' then
            str = str .. "'" .. f .. "'"
        elseif type (f) == 'number' then
            str = str .. tostring(f)
        elseif type (f) == 'table' or type (f) == 'cdata' then
            str = str .. anything_to_string(f)
        else
            str = str .. '?'
        end
    end
    str = str .. ']'
    return str
end;

function things_equal(var1, var2)
    local type1 = type(var1) == 'cdata' and 'table' or type(var1)
    local type2 = type(var2) == 'cdata' and 'table' or type(var2)
    if type1 ~= type2 then
        return false
    end
    if type1 ~= 'table' then
        return var1 == var2
    end
    for k,v in pairs(var1) do
        if not things_equal(v, var2[k]) then
            return false
        end
    end
    for k,v in pairs(var2) do
        if not things_equal(v, var1[k]) then
            return false
        end
    end
    return true
end;

function copy_thing(t)
    if type(t) ~= 'table' then
        return t
    end
    local res = {}
    for k,v in pairs(t) do
        res[copy_thing(k)] = copy_thing(v)
    end
    return res
end;

function test(key_tuple, ops, expect)
    box.space.s:upsert(key_tuple, ops)
    if (things_equal(box.space.s:select{}, expect)) then
        return 'upsert('.. anything_to_string(key_tuple) .. ', ' ..
                anything_to_string(ops) .. ', '  ..
                ') OK ' .. anything_to_string(box.space.s:select{})
    end
    return 'upsert('.. anything_to_string(key_tuple) .. ', ' ..
            anything_to_string(ops) .. ', ' ..
            ') FAILED, got ' .. anything_to_string(box.space.s:select{}) ..
            ' expected ' .. anything_to_string(expect)
end;
test_run:cmd("setopt delimiter ''");

engine = 'memtx'
s = box.schema.space.create('s', {engine = engine})
index1 = s:create_index('i1')
if engine == 'memtx' then index2 = s:create_index('i2', {parts = {2, 'STRING'}, unique = false}) end

t = {1, '1', 1, 'qwerty'}
s:insert(t)

-- all good operations, one op, equivalent to update
test(t, {{'+', 3, 5}}, {{1, '1', 6, 'qwerty'}})
test(t, {{'-', 3, 3}}, {{1, '1', 3, 'qwerty'}})
test(t, {{'&', 3, 5}}, {{1, '1', 1, 'qwerty'}})
test(t, {{'|', 3, 8}}, {{1, '1', 9, 'qwerty'}})
test(t, {{'^', 3, 12}}, {{1, '1', 5, 'qwerty'}})
test(t, {{':', 4, 2, 4, "uer"}}, {{1, '1', 5, 'query'}})
test(t, {{'!', 4, 'answer'}}, {{1, '1', 5, 'answer', 'query'}})
test(t, {{'#', 5, 1}}, {{1, '1', 5, 'answer'}})
test(t, {{'!', -1, 1}}, {{1, '1', 5, 'answer', 1}})
test(t, {{'!', -1, 2}}, {{1, '1', 5, 'answer', 1, 2}})
test(t, {{'!', -1, 3}}, {{1, '1', 5, 'answer', 1, 2 ,3}})
test(t, {{'#', 5, 100500}}, {{1, '1', 5, 'answer'}})
test(t, {{'=', 4, 'qwerty'}}, {{1, '1', 5, 'qwerty'}})

-- same check for negative posistion
test(t, {{'+', -2, 5}}, {{1, '1', 10, 'qwerty'}})
test(t, {{'-', -2, 3}}, {{1, '1', 7, 'qwerty'}})
test(t, {{'&', -2, 5}}, {{1, '1', 5, 'qwerty'}})
test(t, {{'|', -2, 8}}, {{1, '1', 13, 'qwerty'}})
test(t, {{'^', -2, 12}}, {{1, '1', 1, 'qwerty'}})
test(t, {{':', -1, 2, 4, "uer"}}, {{1, '1', 1, 'query'}})
test(t, {{'!', -2, 'answer'}}, {{1, '1', 1, 'answer', 'query'}})
test(t, {{'#', -1, 1}}, {{1, '1', 1, 'answer'}})
test(t, {{'=', -1, 'answer!'}}, {{1, '1', 1, 'answer!'}})

-- selective test for good multiple ops
test(t, {{'+', 3, 2}, {'!', 4, 42}}, {{1, '1', 3, 42, 'answer!'}})
test(t, {{'!', 1, 666}, {'#', 1, 1}, {'+', 3, 2}}, {{1, '1', 5, 42, 'answer!'}})
test(t, {{'!', 3, 43}, {'+', 4, 2}}, {{1, '1', 43, 7, 42, 'answer!'}})
test(t, {{'#', 3, 2}, {'=', 3, 1}, {'=', 4, '1'}}, {{1, '1', 1, '1'}})

-- all bad operations, one op, equivalent to update but error is supressed
test(t, {{'+', 4, 3}}, {{1, '1', 1, '1'}})
test(t, {{'-', 4, 3}}, {{1, '1', 1, '1'}})
test(t, {{'&', 4, 1}}, {{1, '1', 1, '1'}})
test(t, {{'|', 4, 1}}, {{1, '1', 1, '1'}})
test(t, {{'^', 4, 1}}, {{1, '1', 1, '1'}})
test(t, {{':', 3, 2, 4, "uer"}}, {{1, '1', 1, '1'}})
test(t, {{'!', 18, 'answer'}}, {{1, '1', 1, '1'}})
test(t, {{'#', 18, 1}}, {{1, '1', 1, '1'}})
test(t, {{'=', 18, 'qwerty'}}, {{1, '1', 1, '1'}})

-- selective test for good/bad multiple ops mix
test(t, {{'+', 3, 1}, {'+', 4, 1}}, {{1, '1', 2, '1'}})
test(t, {{'-', 4, 1}, {'-', 3, 1}}, {{1, '1', 1, '1'}})
test(t, {{'#', 18, 1}, {'|', 3, 14}, {'!', 18, '!'}}, {{1, '1', 15, '1'}})
test(t, {{'^', 42, 42}, {':', 1, 1, 1, ''}, {'^', 3, 8}}, {{1, '1', 7, '1'}})
test(t, {{'&', 3, 1}, {'&', 2, 1}, {'&', 4, 1}}, {{1, '1', 1, '1'}})

-- broken ops must raise an exception and discarded
'dump ' .. anything_to_string(box.space.s:select{})
test(t, {{'&', 'a', 3}, {'+', 3, 3}}, {{1, '1', 1, '1'}})
test(t, {{'+', 3, 3}, {'&', 3, 'a'}}, {{1, '1', 1, '1'}})
test(t, {{'+', 3}, {'&', 3, 'a'}}, {{1, '1', 1, '1'}})
test(t, {{':', 3, 3}}, {{1, '1', 1, '1'}})
test(t, {{':', 3, 3, 3}}, {{1, '1', 1, '1'}})
test(t, {{'?', 3, 3}}, {{1, '1', 1, '1'}})
'dump ' .. anything_to_string(box.space.s:select{})

-- ignoring ops for insert upsert
test({2, '2', 2, '2'}, {{}}, {{1, '1', 1, '1'}, {2, '2', 2, '2'}})
test({3, '3', 3, '3'}, {{'+', 3, 3}}, {{1, '1', 1, '1'}, {2, '2', 2, '2'}, {3, '3', 3, '3'}})

-- adding random ops
t[1] = 1
test(t, {{'+', 3, 3}, {'+', 4, 3}}, {{1, '1', 4, '1'}, {2, '2', 2, '2'}, {3, '3', 3, '3'}})
t[1] = 2
test(t, {{'-', 4, 1}}, {{1, '1', 4, '1'}, {2, '2', 2, '2'}, {3, '3', 3, '3'}})
t[1] = 3
test(t, {{':', 3, 3, 3, ''}, {'|', 3, 4}}, {{1, '1', 4, '1'}, {2, '2', 2, '2'}, {3, '3', 7, '3'}})

'dump ' .. anything_to_string(box.space.s:select{}) -- (1)
test_run:cmd("restart server default")

test_run:cmd("setopt delimiter ';'")
function anything_to_string(tab)
    if tab == nil then
        return 'nil'
    end
    local str = '['
    local first_route = true
    local t = 0
    for k,f in pairs(tab) do
        if not first_route then str = str .. ',' end
        first_route = false
        t = t + 1
        if k ~= t then
            str = str .. k .. '='
        end
        if type(f) == 'string' then
            str = str .. "'" .. f .. "'"
        elseif type (f) == 'number' then
            str = str .. tostring(f)
        elseif type (f) == 'table' or type (f) == 'cdata' then
            str = str .. anything_to_string(f)
        else
            str = str .. '?'
        end
    end
    str = str .. ']'
    return str
end;
test_run:cmd("setopt delimiter ''");

s = box.space.s
'dump ' .. anything_to_string(box.space.s:select{})-- compare with (1) visually!

box.space.s:drop()
