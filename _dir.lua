-- add some convenience and website-related functions
pashlicks.run_file( '_lib/extensions.lua', _ENV )

page.layout = '_layouts/default.html'
page.test_var = 'test value'


function site.subpaths( from, filter, include_hidden )
  return pashlicks.subpaths( site.tree, from, filter, include_hidden )
end


function site.breadcrumbs( to )
  return pashlicks.breadcrumbs( site.tree, to )
end
