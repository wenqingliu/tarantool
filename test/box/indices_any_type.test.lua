
-- Tests for HASH index type

s3 = box.schema.space.create('my_space4')
i3_1 = s3:create_index('my_space4_idx1', {type='HASH', parts={1, 'SCALAR', 2, 'INT', 3, 'NUMBER'}, unique=true})
i3_2 = s3:create_index('my_space4_idx2', {type='HASH', parts={4, 'STR', 5, 'SCALAR'}, unique=true})
s3:insert({100.5, 30, 95, "str1", 5})
s3:insert({"abc#$23", 1000, -21.542, "namesurname", 99})
s3:insert({true, -459, 4000, "foobar", "36.6"})
s3:select{}

i3_1:select({100.5})
i3_1:select({true, -459})
i3_1:select({"abc#$23", 1000, -21.542})

i3_2:select({"str1", 5})
i3_2:select({"str"})
i3_2:select({"str", 5})
i3_2:select({"foobar", "36.6"})

s3:drop()

-- Tests for NULL

mp = require('msgpack')

s4 = box.schema.space.create('my_space5')
i4_1 = s4:create_index('my_space5_idx1', {type='HASH', parts={1, 'SCALAR', 2, 'INT', 3, 'NUMBER'}, unique=true})
i4_2 = s4:create_index('my_space5_idx2', {type='TREE', parts={4, 'SCALAR'}, unique=true})
s4:insert({mp.NULL, 1, 1, 1})
s4:insert({2, mp.NULL, 2, 2}) -- all nulls must fail
s4:insert({3, 3, mp.NULL, 3})
s4:insert({4, 4, 4, mp.NULL})

s4:drop()
