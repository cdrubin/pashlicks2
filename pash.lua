local pash = {}


local templet = require( 'templet' )
local inspect = require( 'inspect' )
local lfs = require( 'lfs' )



-- table deep-copy utility function
function pash.copy( original )
  local original_type = type( original )
  local copy
  if original_type == 'table' then
    copy = {}
    for original_key, original_value in next, original, nil do
      copy[pash.copy( original_key ) ] = pash.copy( original_value )
    end
    -- use the same metatable (do not copy that too)
    setmetatable( copy, getmetatable( original ) )
  else -- number, string, boolean, etc
    copy = original
  end
  return copy
end


function pash.run_code( code, context, name )

  -- check syntax and return a function
  local func, err = load( code, name, 't', context )

  if err then
    error( code, err )
  else
    -- execute with protection and catch errors
    local result, returned = pcall( func )
    if ( result == false ) then
      error( code, returned )
    else
      return returned, context
    end
  end

end



function pash.read_file( name )
  local infile = assert( io.open( name, 'r' ) )
  local content = infile:read( '*a' )
  infile:close()
  return content
end


function pash.write_file( name, content )
  local outfile = io.open( name, 'w' )
  outfile:write( content )
  outfile:close()
end


function pash.run_file( name, context )
  return pash.run_code( pash.read_file( name ), context, name )
end

function pash.render_file( filename, env )
  local function include( filename )
    local template = templet.loadfile( filename )
    return template( env )
  end
  env.include = include
  return include( filename )
end


function pash.render_tree( source, destination, level, context, silent )
  level = level or 0
  context = context or {}

  local whitespace = ' '
  local directories = {}
  local files = {}

  -- check for 'subdir/_context.lua' and add to context if it exists
  file = io.open( source..'/_context.lua', 'r' )
  if file then _, context = pash.run_file( source..'/_context.lua', context ); file.close(); if not silent then print( 'found _context.lua at '..source ) end end

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

    if not silent then print( whitespace:rep( level * 2 )..directory..'/' ) end
    destination_attr = lfs.attributes( destination..'/'..directory )
    if ( destination_attr == nil and not silent ) then
      lfs.mkdir( destination..'/'..directory )
    end
    local subtree = pash.render_tree( source..'/'..directory, destination..'/'..directory, level + 1, pash.copy( context ), silent )

    tree[directory] = subtree
  end

  -- process files now that search has already processed any children
  for count, file in ipairs( files ) do

    pash.processing = source..'/'..file

    -- setup file specific page values
    context.page.level = level
    context.page.directory = source:gsub( '^%.%/', '' )
    context.page.file = file
    context.page.path = ( context.page.directory..'/'..context.page.file ):gsub( '^%.%/', '' )

    local outfile
    if not silent then outfile = io.open( destination..'/'..file, "w" ) end
    
    local output, after_context
   
    -- FIX THIS!
    if file:match( '%.jpg$' ) 
      or file:match( '%.jpeg$' ) 
      or file:match( '%.gif$' ) 
      or file:match( '%.png$' ) 
      or file:match( '%.eot$' ) 
      or file:match( '%.ttf$' )
      or file:match( '%.woff$' ) 
      or destination:match( 'js' ) then
      output = pash.read_file( source..'/'..file )
      after_context = context
    else
      -- TODO: CSS ;ayout handling!
    
      -- check for (and render) page parts
      --[=[
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
      --]=]
      
      
      -- render and write out page
      after_context = pash.copy( context )
      output = pash.render_file( source..'/'..file, after_context )
      
      -- embed in a layout if one was specified
      if after_context.page.layout then
        after_context.page.content = output
        
        --output = pash.render_file( source..'/'..file, after_context )
        output = pash.render_file( after_context.page.layout, after_context )
        
        if not silent then print( whitespace:rep( level * 2 )..file..' ('..after_context.page.layout..')' ) end
      else
        if not silent then print( whitespace:rep( level * 2 )..file ) end
      end
    
    end
    
    if not after_context.page.ignore then
      table.insert( tree, { directory = context.page.directory, file = context.page.file, path = context.page.path, title = after_context.page.title, layout = after_context.page.layout, hidden = after_context.page.hidden } )
    end

    if not silent then outfile:write( output ) end
    if not silent then outfile:close() end
  end

  return tree

end


pash.context = {}

pash.source = arg[1] or nil
pash.destination = arg[2] or nil


if ( #arg ~= 2 ) then
  print( 'Usage: lua '..arg[0]..' <source> <destination>' )
else
  local source_attr = lfs.attributes( pash.source )
  local destination_attr = lfs.attributes( pash.destination )
  if type( source_attr ) ~= 'table' or source_attr.mode ~= 'directory' then
    print( '<source> needs to be an existing directory' )  
  elseif type( destination_attr ) ~= 'table' or destination_attr.mode ~= 'directory' then
    print( '<destination> needs to be an existing directory' )
  else
    
    local here = lfs.currentdir()
    pash.source = here..'/'..pash.source
    pash.destination = here..'/'..pash.destination
    
    print( pash.source.. ' --> ' )
    print( pash.destination )
    
    lfs.chdir( arg[1] )
  
    -- stand-in for the tree for the first pass of render (as the tree is generated in this initial pass)
    pash.context.site = { tree = {} }
    pash.context.page = {}
    local site_tree = pash.render_tree( '.', pash.destination, 0, pash.copy( pash.context ), true )

    --print( pashlicks.inspect( site_tree ) )

    pash.context.site = { tree = site_tree }
    pash.context.page = {}
    
    pash.render_tree( '.', pash.destination, 0, pash.context )
  end
end

