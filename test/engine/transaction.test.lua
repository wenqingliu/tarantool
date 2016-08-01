test_run = require('test_run')
inspector = test_run.new()
engine = inspector:get_cfg('engine')

-- basic transaction tests
space = box.schema.space.create('test', { engine = engine })
index = space:create_index('primary', { type = 'tree', parts = {1, 'UNSIGNED'} })

-- begin/rollback
inspector:cmd("setopt delimiter ';'")
box.begin()
for key = 1, 10 do space:insert({key}) end
box.rollback();
inspector:cmd("setopt delimiter ''");

t = {}
for key = 1, 10 do assert(#space:select({key}) == 0) end
t

-- begin/commit insert
inspector:cmd("setopt delimiter ';'")
box.begin()
for key = 1, 10 do space:insert({key}) end
box.commit();
inspector:cmd("setopt delimiter ''");

t = {}
for key = 1, 10 do table.insert(t, space:select({key})[1]) end
t

-- begin/commit delete
inspector:cmd("setopt delimiter ';'")
box.begin()
for key = 1, 10 do space:delete({key}) end
box.commit();
inspector:cmd("setopt delimiter ''");

t = {}
for key = 1, 10 do assert(#space:select({key}) == 0) end
t
space:drop()


-- multi-space transactions
a = box.schema.space.create('test', { engine = engine })
index = a:create_index('primary', { type = 'tree', parts = {1, 'UNSIGNED'} })
b = box.schema.space.create('test_tmp', { engine = engine })
index = b:create_index('primary', { type = 'tree', parts = {1, 'UNSIGNED'} })

-- begin/rollback
inspector:cmd("setopt delimiter ';'")
box.begin()
for key = 1, 10 do a:insert({key}) end
for key = 1, 10 do b:insert({key}) end
box.rollback();
inspector:cmd("setopt delimiter ''");

t = {}
for key = 1, 10 do assert(#a:select({key}) == 0) end
t
for key = 1, 10 do assert(#b:select({key}) == 0) end
t

-- begin/commit insert
inspector:cmd("setopt delimiter ';'")
box.begin()
for key = 1, 10 do a:insert({key}) end
for key = 1, 10 do b:insert({key}) end
box.commit();
inspector:cmd("setopt delimiter ''");

t = {}
for key = 1, 10 do table.insert(t, a:select({key})[1]) end
t
t = {}
for key = 1, 10 do table.insert(t, b:select({key})[1]) end
t

-- begin/commit delete
inspector:cmd("setopt delimiter ';'")
box.begin()
for key = 1, 10 do a:delete({key}) end
for key = 1, 10 do b:delete({key}) end
box.commit();
inspector:cmd("setopt delimiter ''");

t = {}
for key = 1, 10 do assert(#a:select({key}) == 0) end
t
for key = 1, 10 do assert(#b:select({key}) == 0) end
t
a:drop()
b:drop()

-- ensure findByKey works in empty transaction context
space = box.schema.space.create('test', { engine = engine })
index = space:create_index('primary', { type = 'tree', parts = {1, 'UNSIGNED'} })

inspector:cmd("setopt delimiter ';'")
box.begin()
space:get({0})
box.rollback();
inspector:cmd("setopt delimiter ''");
space:drop()
