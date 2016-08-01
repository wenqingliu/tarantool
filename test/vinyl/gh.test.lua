env = require('test_run')
test_run = env.new()

-- gh-283: hang after three creates and drops
s = box.schema.space.create('space0', {engine='vinyl'})
i = s:create_index('space0', {type = 'tree', parts = {1, 'STRING'}})
s:insert{'a', 'b', 'c'}
s:drop()

s = box.schema.space.create('space0', {engine='vinyl'})
i = s:create_index('space0', {type = 'tree', parts = {1, 'STRING'}})
s:insert{'a', 'b', 'c'}
t = s.index[0]:select({}, {iterator = box.index.ALL})
t
s:drop()

s = box.schema.space.create('space0', {engine='vinyl'})
i = s:create_index('space0', {type = 'tree', parts = {1, 'STRING'}})
s:insert{'a', 'b', 'c'}
t = s.index[0]:select({}, {iterator = box.index.ALL})
t
s:drop()


-- gh-280: crash if insert without index
s = box.schema.space.create('test', {engine='vinyl'})
s:insert{'a'}
s:drop()


-- gh-436: No error when creating temporary vinyl space
s = box.schema.space.create('tester',{engine='vinyl', temporary=true})


-- gh-432: ignored limit
s = box.schema.space.create('tester',{engine='vinyl'})
i = s:create_index('vinyl_index', {})
for v=1, 100 do s:insert({v}) end
t = s:select({''},{iterator='GT', limit =1})
t
t = s:select({},{iterator='GT', limit =1})
t
s:drop()

s = box.schema.space.create('tester', {engine='vinyl'})
i = s:create_index('vinyl_index', {type = 'tree', parts = {1, 'STRING'}})
for v=1, 100 do s:insert({tostring(v)}) end
t = s:select({''},{iterator='GT', limit =1})
t
t = s:select({},{iterator='GT', limit =1})
t
s:drop()


-- gh-681: support or produce error on space::alter
s = box.schema.space.create('M', {engine='vinyl'})
i = s:create_index('primary',{})
s:insert{5}
s.index.primary:alter({parts={1,'UNSIGNED'}})
s:drop()


-- gh-1008: assertion if insert of wrong type
s = box.schema.space.create('t', {engine='vinyl'})
i = s:create_index('primary',{parts={1, 'STRING'}})
box.space.t:insert{1,'A'}
s:drop()


-- gh-1009: search for empty string fails
s = box.schema.space.create('t', {engine='vinyl'})
i = s:create_index('primary',{parts={1, 'STRING'}})
s:insert{''}
#i:select{''}
i:get{''}
s:drop()


-- gh-1407: upsert generate garbage data
email_space_id = 'email'
email_space = box.schema.space.create(email_space_id, { engine = 'vinyl', if_not_exists = true })
i = email_space:create_index('primary', { parts = {1, 'STRING'} })

time = 1234
email = "test@domain.com"
email_hash_index = "asdfasdfs"
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:upsert({email, email_hash_index, time}, {{'!', -1, email_hash_index}, {'!', -1, time}})
box.space.email:select{email}
box.space.email:drop()

--gh-1540: vinyl: invalid results from LE/LT iterators
s = box.schema.space.create('test', { engine = 'vinyl' })
i = box.space.test:create_index('primary', { parts = { 1, 'UNSIGNED', 2, 'UNSIGNED' } })
for i =1,2 do for j=1,9 do box.space.test:replace({i, j}) end end
box.space.test:select({1, 999999}, {iterator = 'LE'})
box.space.test:drop()

s1 = box.schema.create_space('s1',{engine='vinyl'})
i1 = s1:create_index('primary',{parts={1,'UNSIGNED',2,'UNSIGNED'}})
s2 = box.schema.create_space('s2',{engine='memtx'})
i2 = s2:create_index('primary',{parts={1,'UNSIGNED',2,'UNSIGNED'}})
for i = 1,3 do for j = 1,5 do s1:insert{i, j} s2:insert{i, j} end end
itrs = {'GE', 'GT', 'LE', 'LT'}
good = true
test_run:cmd("setopt delimiter ';'")
function my_equal(a, b)
    if type(a) ~= type(b) then
        return false
    elseif type(a) ~= 'table' and not box.tuple.is(a) then
        return a == b
    end
    for k,v in pairs(a) do if not my_equal(b[k], v) then return false end end
    for k,v in pairs(b) do if not my_equal(a[k], v) then return false end end
    return true
end;
for i = 0,4 do
    for j = 0,6 do
        for k = 1,4 do
            opts = {iterator=itrs[k]}
            if not my_equal(s1:select({i, j}, opts), s2:select({i, j}, opts)) then
                good = false
            end
        end
    end
end;
test_run:cmd("setopt delimiter ''");
good
s1:drop()
s2:drop()

--
-- gh-1608: tuple disappears after invalid upsert
--
s = box.schema.create_space('test', {engine = 'vinyl'})
_ = s:create_index('test', {type = 'tree', parts = {1, 'UNSIGNED', 2, 'STRING'}})
s:put({1, 'test', 3, 4})
s:select()
s:upsert({1, 'test', 'failed'}, {{'=', 3, 33}, {'=', 4, nil}})
s:select()
s:drop()
