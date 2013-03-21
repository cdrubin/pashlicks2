
-- convenience function for returning a nunber indexed table of the elements sorted by key
function pashlicks.sort_array( original, key )
  local sorted_keys = {}
  local lookup = {}
  for _, item in pairs( original ) do
    table.insert( sorted_keys, item[key] )
    lookup[ item[key] ] = item
  end

  table.sort( sorted_keys )

  local sorted = {}
  for _, name in ipairs( sorted_keys ) do
    table.insert( sorted, lookup[name] )
  end

  return sorted
end


function pashlicks.breadcrumbs( tree, to )

  assert( type( tree ) == 'table', 'tree parameter should be site.tree' ) --'\ntree: '..pashlicks.inspect( tree ) )
  assert( type( to ) == 'string', 'to parameter should be path into the tree' ) --'\ntree: '..pashlicks.inspect( tree ) )

  local crumbs = {}
  local parts = to:split( '/' )

  local sofar = ''
  local tree = tree
  for _, part in ipairs( parts ) do

    if sofar == '' then
      sofar = part
    else
      sofar = sofar..'/'..part
    end

    -- find index.html at this level of the tree
    local title = '---'

    for index, item in pairs( tree[part] ) do
      if item.file and item.file == 'index.html' and item.title then
        title = item.title
        break
      end
    end

    table.insert( crumbs, { url = '/'..sofar, title = title } )
    tree = tree[part]
  end

  return crumbs
end


-- requires page or site tree as first parameter, optionally accepts a relative path
-- into the tree, filter can be optionally 'directory' or 'file' and if
-- include_hidden is true then all items are returned including hidden ones
function pashlicks.subpaths( tree, from, filter, include_hidden )

  assert( type( tree ) == 'table', 'tree parameter should be site.tree' ) --'\ntree: '..pashlicks.inspect( tree ) )
  from = from or ''
  assert( type( from ) == 'string', 'from parameter should be a path into tree' ) --'\nfrom: '..pashlicks.inspect( from ) )

  -- return empty if tree is empty
  if #tree == 0 then return {} end

  from = from:trim()

  local results = {}

  if from:ends( '/' ) then
    from = from:sub( 1, -2 )
  end

  local parts = from:split( '/' )

  local subtree = tree
  for _, subpath in ipairs( parts ) do
    subtree = subtree[subpath]
  end

  -- return empty if if subtree does not exist
  if not subtree then return {} end

  for i, item in pairs( subtree ) do
    if item.file and ( not filter or filter == 'file' ) and from ~= '' then
      item.type = 'file'
      if not item.hidden or include_hidden then
        if from == '' then
          table.insert( results, { path = from..item.file, type = 'file', title = item.title, name = item.file } )
        else
          table.insert( results, { path = from..'/'..item.file, type = 'file', title = item.title, name = item.file } )
        end
      end
    elseif not item.file and ( not filter or filter == 'directory' ) then

      local title = nil
      for _, subitem in pairs( item ) do
        if subitem.file == 'index.html' then
          if not subitem.hidden or include_hidden then
            title = subitem.title
          else
            title = nil
          end
          break
        end
      end

      if title then
        if from == '' then
          table.insert( results, { path = from..i, type = 'directory', title = title, name = i } )
        else
          table.insert( results, { path = from..'/'..i, type = 'directory', title = title, name = i } )
        end
      end

    end
  end

  return results
end


-- string convenience methods

-- starts with?
function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

-- ends with?
function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end

-- trim whitespace
function string.trim(String)
  return String:match("^%s*(.-)%s*$")
end

-- split with pattern
function string.split(str, pat )
  pat = pat or " "
  local t = {}  -- NOTE: use {n = 0} in Lua-5.0
  local fpat = "(.-)" .. pat
  local last_end = 1
  local s, e, cap = str:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= "" then
	  table.insert(t,cap)
    end
    last_end = e+1
	s, e, cap = str:find(fpat, last_end)
  end
  if last_end <= #str then
    cap = str:sub(last_end)
    table.insert(t, cap)
  end
  return t
end
