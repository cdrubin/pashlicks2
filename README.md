Pashlicks2
=========

Pashlicks2 is a text processor that allows lua to be executed in 
the context of page generation. Developed as a static website 
generator she claims to be simple to extend.

Pashlicks2 expects to be at the foot (root) of your site. She adds
the execution of `_dir.lua` to the environment of the contents of
a directory.

Files and directories that begin with `_` or `.` are ignored.

She understands three kinds of tags inside source files :

1. Code
``` lua
[% for i = 1,5 do %]
  <br />
[% end %]
```

2. Value
``` lua
[% for i = 1,5 do %]
  <li>Item [= i =]</li>
[% end %]
```

3. Include
``` lua
  [( "menu.html" )]
```

She could certainly process any filetype but we usually have her
chew on HTML template files.

A common need when using Pashlicks as a static site generator
is the use of a _layout_ or _template_ inside which to embed the
content of a page. Specifying a layout can be done in a `_dir.lua`
file so that all pages in that directory and any of its child directories 
use a particular layout. Specifying the layout template can of course
also be done inside the page itself.

```lua
page.layout = '_layouts/site.html'
site.keywords = 'Dog-run'
```
**avoid** doing something like the following :
```lua
page = { layout = '_layouts/site.html' }
```
because you will be clobbering the page table contents created elsewhere.

When specifying a layout the page is rendered to the variable `page.content`.

So with a layout like this :

```
_dir.lua
_layouts/
  site.html
_snippets/
  menu.html
index.html
pashlicks.lua
```

we could have :
```
--- _dir.lua
page.layout = '_layouts/site.html'


--- _layouts/site.html
<html>
<head>
  <title>[= page.title =]</title>
</head>
<body>
  [= page.content =]
</body>
</html>


--- index.html
[% page.title = 'The truth about Pashlicks2' %]

Pashlicks loves her sisters Josie and Marmite
```

to produce an index.html file containing :
```html
<html>
<head>
  <title>The truth about Pashlicks2</title>
</head>
<body>

Pashlicks loves her sisters Josie and Marmite
</body>
</html>

```

Pashlicks2 supports **page parts** which are identified by the name of the 
page they are related to preceeded by double underscores followed by a dot and the
name of the part. These sections are rendered within the context of the 
named page. For 'carousel' and 'featured' parts of the events page we would
have :


```
--- __events.carousel.html
<ul id="carousel">
</ul>


--- __events.featured.html
<h2>Featured!</h2>


--- events.html
[%
page.layout = '_layouts/site.html'
page.title = 'Events'
%]

<div id="content">
[= page.parts['carousel.html'] =]
<hr />
[= page.parts['featured.html'] =]
</div>

```


An example of some customization is available in the included
[_dir.lua](https://github.com/cdrubin/pashlicks2/blob/master/_dir.lua).
When this file is placed at the root of the site Pashlicks makes sure that
all pages have these values and functions available in their environment.

Every page has some *special* variables injected into its environment:

```lua
page.file      -- filename of file being processed
page.directory -- directory of the file being processed
page.path      -- path to file from root of site
page.level     -- level in the tree at which this page sits

site.tree      -- tree of site
```

Calling Pashlicks2 should be as simple as :

```bash
lua pashlicks2.lua _output
```
