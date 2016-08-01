space = box.schema.space.create("test")
-- gh-1534: deprecate 'num' data type for unsigned integers
_ = space:create_index('primary', { parts = {1, 'num'}})
-- gh-942: Support string aliases for STR
_ = space:create_index('secondary', { parts = {2, 'str'}})
_ = space:create_index('spatial', { type = 'rtree', parts = {3, 'number[]'}})
space.index.primary.parts[1].type == 'UNSIGNED'
space.index.secondary.parts[1].type == 'STRING'
space.index.spatial.parts[1].type == 'NUMBER[]'
space:drop()
