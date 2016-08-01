n_records = 10000
n_iterations = 10000
n_neighbors = 10
env = require('test_run')
test_run = env.new()

file = io.open("rtree_benchmark.res", "w")

s = box.schema.space.create('rtreebench')
_ = s:create_index('primary')
_ = s:create_index('spatial', { type = 'rtree', unique = false, parts = {2, 'NUMBER[]'}})

file:write(" *** 2D *** \n")
rect_width = 180 / math.pow(n_records, 1 / 2)

start = os.time()

test_run:cmd("setopt delimiter ';'")
for i = 1, n_records do
   s:insert{i,{180*math.random(),180*math.random()}}
end;

file:write(string.format("Elapsed time for inserting %d records: %d\n", n_records, os.time() - start));

start = os.time();
n = 0;
for i = 1, n_iterations do
   x = (180 - rect_width) * math.random()
   y = (180 - rect_width) * math.random()
   for k,v in s.index.spatial:pairs({x,y,x+rect_width,y+rect_width}, {iterator = 'LE'}) do
       n = n + 1
   end
end;
file:write(string.format("Elapsed time for %d belongs searches selecting %d records: %d\n", n_iterations, n, os.time() - start));

start = os.time();
n = 0
for i = 1, n_iterations do
   x = 180 * math.random()
   y = 180 * math.random()
   for k,v in pairs(s.index.spatial:select({x,y }, {limit = n_neighbors, iterator = 'NEIGHBOR'})) do
      n = n + 1
   end
end;
file:write(string.format("Elapsed time for %d nearest %d neighbors searches selecting %d records: %d\n", n_iterations, n_neighbors, n, os.time() - start));

start = os.time();
for i = 1, n_records do
    s:delete{i}
end;
file:write(string.format("Elapsed time for deleting  %d records: %d\n", n_records, os.time() - start));

s:drop();

dimension = 8;

s = box.schema.space.create('rtreebench');
_ = s:create_index('primary');
_ = s:create_index('spatial', { type = 'rtree', unique = false, parts = {2, 'NUMBER[]'}, dimension = dimension});

file:write(" *** 8D *** \n")
rect_width = 180 / math.pow(n_records, 1 / dimension)

start = os.time();

for i = 1, n_records do
   local record = {}
   for j = 1, dimension do
      table.insert(record, 180*math.random())
   end
   s:insert{i,record}
end;

file:write(string.format("Elapsed time for inserting %d records: %d\n", n_records, os.time() - start));

start = os.time();
n = 0;
for i = 1, n_iterations do
   local rect = {}
   for j = 1, dimension do
      table.insert(rect, (180 - rect_width) * math.random())
   end
   for j = 1, dimension do
      table.insert(rect, rect[j] + rect_width)
   end
   for k,v in s.index.spatial:pairs(rect, {iterator = 'LE'}) do
       n = n + 1
   end
end;
file:write(string.format("Elapsed time for %d belongs searches selecting %d records: %d\n", n_iterations, n, os.time() - start));

start = os.time();
n = 0
for i = 1, 0 do
   local rect = {}
   for j = 1, dimension do
      table.insert(rect, 180*math.random())
   end
   for k,v in pairs(s.index.spatial:select(rect, {limit = n_neighbors, iterator = 'NEIGHBOR'})) do
      n = n + 1
   end
end;
file:write(string.format("Elapsed time for %d nearest %d neighbors searches selecting %d records: %d\n", n_iterations, n_neighbors, n, os.time() - start));

start = os.time();
for i = 1, n_records do
    s:delete{i}
end;
file:write(string.format("Elapsed time for deleting  %d records: %d\n", n_records, os.time() - start));

s:drop();

file:close();

test_run:cmd("setopt delimiter ''");


