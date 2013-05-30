-- Pashlicks

--   templating features thanks to Zed Shaw's tir

local lfs = require( 'lfs' )

pashlicks = { context = { render_parents = {} }, processing = '' }
setmetatable( pashlicks.context, { __index = _G } )

pashlicks.inspect = require( '_lib/inspect' )

pashlicks.TEMPLATE_ACTIONS = {
  ['[%'] = function(code)
    return code
  end,
  ['[='] = function(code)
    return ('_result[#_result+1] = %s'):format(code)
  end,
  ['[('] = function(code)
    return ( '_result[#_result+1] = pashlicks.render( pashlicks.read_file( %s ), _ENV )' ):format( code )
  end
}


function pashlicks.render( code, context, name )
  local tmpl = code..'[!pashlicks!]'
  local code = {'local _result = {}\n'}

  for text, block in string.gmatch( tmpl, "([^%[]-)(%b[])" ) do
    local act = pashlicks.TEMPLATE_ACTIONS[block:sub( 1, 2 )]

    --pashlicks.render_block = block
    --print( 'text: '..pashlicks.inspect( text ) )
    --print( 'block: '..pashlicks.inspect( block ) )
    --print( 'act: '..pashlicks.inspect( act ) )

    if ( block:sub( 1, 2 ) == '[(' ) then
      table.insert( context.render_parents, block:match( '"(.+)"' ) )
    end

    if act then
      code[#code+1] = '_result[#_result+1] = [=====[' .. text .. ']=====]'
      code[#code+1] = act(block:sub(3,-3))
    elseif block ~= '[!pashlicks!]' then
      code[#code+1] = '_result[#_result+1] = [=====[' .. text .. block .. ']=====]'
    else
      code[#code+1] = '_result[#_result+1] = [=====[' .. text .. ']=====]'
    end

  end

  code[#code+1] = 'return table.concat(_result)'
  code = table.concat( code, '\n' )

  return pashlicks.run_code( code, context, name )
end


function pashlicks.error( code, err )

  local filename, linenumber, description = err:match( '"(.+)".-:(%d+): (.+)$' )

  -- break code into lines
  local code_linearray = {}
  local linecount = 1
  for i in code:gmatch( '.-\n' ) do
    table.insert( code_linearray, string.format( '%-5d', linecount )..i )
    linecount = linecount + 1
  end

  -- consider only linenumber lines of code
  local code_uptoerror = pashlicks.slice( code_linearray, 1, linenumber )
  code_uptoerror = table.concat( code_uptoerror )
  local _, count_newlinestart = string.gsub( code_uptoerror, '_result%[#_result%+1%] = %[=====%[\n', '' )
  local _, count_singleline = string.gsub( code_uptoerror, '_result%[#_result%+1%] = %[=====%[]=====]\n', '' )

  --print( code_uptoerror )
  --print( count_newlinestart )
  --print( count_singleline )

  local error_line = linenumber - ( count_newlinestart * 2 )- count_singleline - 2;

  if ( filename:sub( 1, 7 ) == 'local _' ) then
    filename = pashlicks.processing .. ' > '..table.concat( context.render_parents, ' > ');
  end

  print( arg[0].. ':'..filename..':'..error_line..': '..description )
  os.exit( 1 )

end


-- Helper function that uses load to check code and if okay return the environment it creates
function pashlicks.run_code( code, context, name )

  -- check syntax and return a function
  local func, err = load( code, name, 't', context )

  if err then
    pashlick.error( code, err )
  else
    -- execute with protection and catch errors
    local result, returned = pcall( func )
    if ( result == false ) then
      pashlicks.error( code, returned )
    else
      return returned, context
    end

    --return func(), context
  end

end


function pashlicks.read_file( name )
  local infile = assert( io.open( name, 'r' ) )
  local content = infile:read( '*a' )
  infile:close()
  return content
end


function pashlicks.write_file( name, content )
  local outfile = io.open( name, 'w' )
  outfile:write( content )
  outfile:close()
end

-- global loadfile uses global environment by default, this one uses the current environment
function pashlicks.run_file( name, context )
  return pashlicks.run_code( pashlicks.read_file( name ), context, name )
end

function pashlicks.render_file( name, context )
  --return pashlicks.run_code( pashlicks.read_file( name ), context, name )
  return pashlicks.render( pashlicks.read_file( name ), pashlicks.copy( context ), name )
end

-- silent will not write files or print anything
function pashlicks.render_tree( source, destination, level, context, silent )
  level = level or 0
  context = context or {}

  local whitespace = ' '
  local directories = {}
  local files = {}

  -- check for 'subdir/_dir.lua' and add to context if it exists
  file = io.open( source..'/_dir.lua', 'r' )
  --if file then _, context = pashlicks.run_code( pashlicks.read_file( source..'/_dir.lua' ), context ) end
  if file then _, context = pashlicks.run_file( source..'/_dir.lua', context ) end

  -- create tables of the file and directory names
  for item in lfs.dir( source ) do
    local attr = lfs.attributes( source..'/'..item )
    if item:sub( 1, 1 ) ~= '_' and item:sub( 1, 1 ) ~= '.' and item ~= arg[0] then
      if attr.mode == "directory" then
        table.insert( directories, item )
      elseif attr.mode == 'file' then
        table.insert( files, item )
      end
    end
  end
  table.sort( directories ) ; table.sort( files )

  local tree = {}

  -- process directories first for depth-first search
  for count, directory in ipairs( directories ) do

    --print( '::::'..whitespace:rep( level * 2 )..directory..'/' )
    --print( pashlicks.inspect( context.page ) )
    --print( pashlicks.inspect( pashlicks.copy( context ) ) )

    if not silent then print( whitespace:rep( level * 2 )..directory..'/' ) end
    destination_attr = lfs.attributes( destination..'/'..directory )
    if ( destination_attr == nil and not silent ) then
      lfs.mkdir( destination..'/'..directory )
    end
    local subtree = pashlicks.render_tree( source..'/'..directory, destination..'/'..directory, level + 1, pashlicks.copy( context ), silent )

    tree[directory] = subtree


  end

  --local visible_pages = {}
  -- process files now that search has already processed any children
  for count, file in ipairs( files ) do

    --print( '::::'..whitespace:rep( level * 2 )..file )
    pashlicks.processing = source..'/'..file

    -- setup file specific page values
    context.page.level = level
    context.page.directory = source:gsub( '^%.%/', '' )
    context.page.file = file
    context.page.path = ( context.page.directory..'/'..context.page.file ):gsub( '^%.%/', '' )


    -- check for (and render) page parts
    local rendered_page_parts = {}
    local page_part_identifier = '__'..file:match( '[%a%d%-_]+'..'.' )
    for page_part in lfs.dir( source ) do
      if page_part:find( page_part_identifier ) == 1 then
        local page_part_name = page_part:sub( page_part_identifier:len() + 1 )
        if not silent then print( whitespace:rep( level * 2 )..'-'..page_part_name ) end
        --local rendered_page_parts = {}
        rendered_page_parts[page_part_name] = pashlicks.render_file( source..'/'..page_part, pashlicks.copy( context ) )
      end
    end
    context.page.parts = rendered_page_parts

    -- render and write out page
    local outfile
    if not silent then outfile = io.open( destination..'/'..file, "w" ) end
    local output, after_context = pashlicks.render_file( source..'/'..file, pashlicks.copy( context ) )

    -- embed in a layout if one was specified
    if after_context.page.layout then
      after_context.page.content = output
      output = pashlicks.render_file( after_context.page.layout, after_context )
      if not silent then print( whitespace:rep( level * 2 )..file..' ('..after_context.page.layout..')' ) end
    else
      if not silent then print( whitespace:rep( level * 2 )..file ) end
    end

    if not after_context.page.ignore then
      table.insert( tree, { directory = context.page.directory, file = context.page.file, path = context.page.path, title = after_context.page.title, layout = after_context.page.layout, hidden = after_context.page.hidden } )
    end

    if not silent then outfile:write( output ) end
    if not silent then outfile:close() end
  end

  return tree

end


-- table deep-copy utility function
function pashlicks.copy( original )
  local original_type = type( original )
  local copy
  if original_type == 'table' then
    copy = {}
    for original_key, original_value in next, original, nil do
      copy[pashlicks.copy( original_key ) ] = pashlicks.copy( original_value )
    end
    -- use the same metatable (do not copy that too)
    setmetatable( copy, getmetatable( original ) )
  else -- number, string, boolean, etc
    copy = original
  end
  return copy
end


-- table slice utility function
function pashlicks.slice( values, start_index, end_index )
  local result = {}
  local n = #values
-- default values for range
  start_index = tonumber( start_index ) or 1
  end_index = tonumber( end_index ) or n
  if end_index < 0 then
    end_index = n + end_index + 1
  elseif end_index > n then
    end_index = n
  end
  if start_index < 1 or start_index > n then
    return {}
  end
  local k = 1
  for i = start_index, end_index do
    result[k] = values[i]
    k = k + 1
  end
  return result
end


pashlicks.destination = arg[1] or nil

if ( #arg ~= 1 ) then
  print( 'Usage: lua '..arg[0]..' <destination>' )
else
  local destination_attr = lfs.attributes( pashlicks.destination )
  if type( destination_attr ) ~= 'table' or destination_attr.mode ~= 'directory' then
    print( '<destination> needs to be an existing directory' )
  else
    -- stand-in for the tree for the first pass of render (as the tree is generated in this initial pass)
    pashlicks.context.site = { tree = {} }
    pashlicks.context.page = {}
    local site_tree = pashlicks.render_tree( '.', pashlicks.destination, 0, pashlicks.copy( pashlicks.context ), true )

    --print( pashlicks.inspect( site_tree ) )

    pashlicks.context.site = { tree = site_tree }
    pashlicks.context.page = {}

    pashlicks.render_tree( '.', pashlicks.destination, 0, pashlicks.context )
  end
end

