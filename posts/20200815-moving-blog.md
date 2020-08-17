%{
  title: "Moving the blog to Elixir and Phoenix LiveView",
  tags: ["elixir", "phoenix"],
  description: """
  I moved my blog. It's now powered by Phoenix LiveView. Let me tell you about
  the transition. I outline the features I lost, I gained, and some performance
  surprises along the way.
  """
}
---

I moved my blog. It's now powered by Phoenix LiveView. Let me tell you about the
transition. I outline the features I lost, I gained, and some performance
surprises along the way.

What I'm **giving up**:

1. Offline access
1. Progressive Web App capabilities.
1. Free hosting (bummer.)
1. Pre-compiled syntax highlighting. Gatsby has a great [VSCode-powered
     highlighter][gatsby-remark-vscode]
     that runs during compilation.
1. A mature asset-processing pipeline to [optimize
   images](https://developers.google.com/web/fundamentals/design-and-ux/responsive/images),
   especially for responsiveness.
1. Easier scaling if traffic gets out of hand. It's fundamentally easier to
   scale static content using a CDN service. But, given Elixir's web request
   performance, I'm not too worried about this yet, and maybe I shouldn't be for
   this little ol' blog.

What I'm **gaining**:

1. A tool-chain that I understand thoroughly and can contribute to; I actually
     know Elixir and Phoenix.
1. The ability to show off LiveView-enabled components (stay tuned!)

What I'm **not losing**:

1. A fast load time.
1. A reactive local development tool-chain. For example, when editing the post, I
     can save the file and my dev server shows the changes almost immediately.

The "giving up" list doesn't bother me too much, at least not on my blog. If
you're managing a huge static site with lots of pages; perhaps look elsewhere at
the moment. The biggest reason is that Elixir lacks an asset-pipeline to
optimize images. It wouldn't be impossible to have with a LiveView-powered blog
with optimized images, but as far as I know, you'll have to roll-your-own.

I was initially worried that moving a static site to an Elixir-powered web
application would have too many trade-offs, but I was wrong! Many static sites
today don't offer pre-compiled syntax highlighting, but I was using one, so it's
a loss for me. Losing the PWA and cached offline access don't bother me.

The "gaining" list is worth it to me, as an Elixir developer, because it unlocks
some potential for what I want to do. I'm considering collecting
LiveView-powered components, and how else would I be able to show them off
without a LiveView site? So, the trade-off is totally worth it to me.

The "not losing" list was surprising. Let's talk about it; I'll show you some
informal benchmarks.

## Let's look at the dev server

Elixir and Phoenix offer live-reloading when assets change (ie, JavaScript and
CSS), and code-reloading when Elixir code changes. To make this reloading work
in the context of a blog written with Markdown, I used
[NimblePublisher](https://github.com/dashbitco/nimble_publisher).
NimblePublisher is a small system that sets up compiling Markdown files into
HTML at compile-time. Create a `/blog` folder, put your markdown in there, and
configure Elixir to watch it for changes.

```elixir
# config/dev.exs
config :bern, BernWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/bern_web/(live|views)/.*(ex)$",
      ~r"lib/bern_web/templates/.*(eex)$",
      ~r"posts/*/.*(md)$" # <-- right here!
    ]
  ]
```

Now, **a big plus for Elixir is the boot-up time**. Granted if you haven't
changed files that requires the entire Elixir project to re-compile, booting up
the dev server is _very quick_. How quick? **36 times quicker**. But before you
run off to social media with this stat, just remember that it's not very
scientific, nor is it always fair. It's not apples-to-apples.

Let's say that I have inspiration one day and I want to write a blog post. I go
to my blog folder, start the dev server, and start writing. I haven't changed
anything; I just want to write a post.

Here's the Elixir dev server running `iex -S mix phx.server`:

![Elixir Phoenix Boot Up](/images/elixir-dev-server-blog.png)

Now the Gatsby dev server running `yarn run gatsby develop`:

![Gatsby Boot Up](/images/gatsby-dev-server-blog.png)

If I'm reading this correctly, Gatsby took about **36 seconds** to boot. I
hadn't changed anything in the project! In comparison, Elixir and Phoenix booted
in **1 second**, and that _includes Webpack_; granted, nothing changed in the
project and some of this is thanks to
[HardSourceWebpackPlugin](https://github.com/mzgoddard/hard-source-webpack-plugin);
but even without that plugin, Elixir is still up and running and serving
requests and whenever Webpack finishes it will live-reload with those compiled
CSS and JS resources.

Again, I'll repeat, this is not apples-to-apples. For example, I'm giving up
compile-time syntax highlighting for non-Elixir code blocks. Gatsby is likely
recompiling everything without needing to, whereas Elixir is a compiled language
that only recompiles what it needs to.

## Syntax Highlighting

NimblePublisher also handles syntax-highlighting at compile-time, but
unfortunately only when the language is Elixir or Erlang. Since I write about
other languages, including Ruby, JavaScript, Bash, Vim, and more, I need
more syntax highlighting options. NimblePublisher is using
[Makeup](https://github.com/tmbb/makeup/) for highlighting; so perhaps I can
contribute by making more Makeup lexers.

To cover the gap in the meantime, I'm going to syntax-highlight at runtime; in
other words, you visiting this page ran some JavaScript to highlight syntax for
me! Since this blog is now powered with LiveView, I handled it in a hook.

Let's see how it works

```javascript
// Configure Webpack to make another bundle for vendored code like Highlight.js
// assets/webpack.config.js

module.exports = (_env, options) => {
  return {
    // ...
    entry: {
      app: ["./js/app.js", "./css/app.css"],
      vendor: ["./js/vendor.js"] // <-- this part
    }
  }
}

// ==================================================
// assets/js/vendor.js
import "./highlighter";


// ==================================================
// assets/js/highlighter.js
import hljs from 'highlight.js/lib/core';
import javascript from 'highlight.js/lib/languages/javascript';
import shell from 'highlight.js/lib/languages/shell';
import bash from 'highlight.js/lib/languages/bash';
import erb from 'highlight.js/lib/languages/erb';
import ruby from 'highlight.js/lib/languages/ruby';
import vim from 'highlight.js/lib/languages/vim';
import yaml from 'highlight.js/lib/languages/yaml';
import json from 'highlight.js/lib/languages/json';
import diff from 'highlight.js/lib/languages/diff';
import xml from 'highlight.js/lib/languages/xml';

// Yeah, this isn't very sexy, but I'm trying to keep the bundle small
// by only opting into languages I use in blog posts.
hljs.registerLanguage('javascript', javascript);
hljs.registerLanguage('shell', shell);
hljs.registerLanguage('bash', bash);
hljs.registerLanguage('eex', erb);
hljs.registerLanguage('ruby', ruby);
hljs.registerLanguage('vim', vim);
hljs.registerLanguage('yaml', yaml);
hljs.registerLanguage('json', json);
hljs.registerLanguage('diff', diff);
hljs.registerLanguage('html', xml);

window.highlightAll = function(where = document) {
  where.querySelectorAll('pre code').forEach((block) => {
    const lang = block.getAttribute("class")
    // Since Makeup handles Elixir code at compile-time, I don't need
    // highlight.js to care about this language.
    if (lang !== "makeup elixir") {
      const { value: value } = hljs.highlight(lang, block.innerText);
      block.innerHTML = value;
    }
  });
}

window.highlightAll()  // this covers on page load

// ==================================================
// assets/js/hooks.js
let hooks = {}

hooks.Highlight = {
  mounted() {
    window.highlightAll(this.el) // this covers LiveView patches
  }
}

export default hooks

// ==================================================
// assets/js/app.js
import hooks from "./hooks";

// the normal phoenix LiveView initialization, but passing in the hooks:
window.liveSocket = new LiveSocket("/live", Socket, {
  hooks,
});

window.liveSocket.connect();
```

```html
<!-- lib/bern_web/templates/layout/root.html.leex -->
<script defer phx-track-static type="text/javascript"
  src="<%= Routes.static_path(@conn, "/js/vendor.js") %>"></script>


<!-- lib/bern_web/live/blog_show.html.leex -->
<div id="post-content-<%= @post.id %>" phx-hook="Highlight" phx-update="ignore">
  <%= raw(@post.body) %>
</div>
```

Cool. That's not terrible, but still I would much-prefer ALL syntax highlighting
happen at compile-time. It's not like this stuff changes in runtime so there's
no reason for every visitor's browser to do syntax highlighting for me. Kudos to
the Gatsby tool-chain for solving this problem via [gatsby-remark-vscode].

## What about performance?

I'm glad you asked.

There's no practical difference in my opinion, which is **an upset to common
perception of JavaScript-powered static sites being _much_ slimmer and faster**.

Let's look.

Here's the Blog Show page powered by Gatsby:

![Gatsby Network Show](/images/network-gatsby-show.png)

Here's the Blog Show page powered by Elixir Phoenix LiveView:

![Elixir Phoenix Network Show](/images/network-phoenix-show.png)

**REMEMBER** the LiveView-powered blog now requires browser-based syntax
highlighing, so there's an extra 79.5kb of JavaScript that needs to download and
parse and run. Also notice that there's an extra font on the Gatsby site since
it needed it on this page.

All-in-all this is very comparable judging by the `DomContentLoaded` and `Load`
times, but notice that Elixir and Phoenix are barely beating Gatsby in this
scenario.

Let's look at the Blog Index page powered by Gatsby:

![Gatsby Network Index](/images/network-gatsby-index.png)

Here's the Blog Index page powered by Elixir Phoenix LiveView:

![Elixir Phoenix Network Index](/images/network-phoenix-index.png)

Elixir is slower in this case for `DOMContentLoaded` and `Load` times by tens of
milliseconds. Hopefully imperceptible to most visitors. Also, **that's not bad
considering this is running on a $5/mo server** in the US East Coast, opposed to
CDN-cached static content at the edge by Cloudflare and GitHub Pages. Also
considering that LiveView-powered index page is **literally loading every single
post it their entirety, but not rendering the bodies of the posts**; so there
is room for optimization here.

Lastly, just for the giggles, here's the Lighthouse scores:

Gatsby:

![Gatsby Network Index](/images/lighthouse-gatsby.png)

Elixir Phoenix LiveView:

![Elixir Phoenix Network Index](/images/lighthouse-phoenix.png)

The SEO hit on the Phoenix app is because of a `canonical` URL not being
correct. Once the LiveView blog replaces the Gatsby blog, it'll be 100 again.
Also, the Accessibility score took a hit because of different styling where the
contrast isn't high enough in one spot. Really, the only difference is Gatsby's
score of 95 on performance vs LiveView's score of 99 on performance, and the
lack of PWA on LiveView. I don't really think these scores mean anything between
the two sites; but take it as you will.

Now, of course, if you check the score now, you'll see it's different because
I've since added some web font preloading which _kills the score_. This only
happens on the first load though, thankfully.

## Migrating to Phoenix LiveView from Gatsby

Here are the big changes. You'll find several more details on your own if you
consider migrating to NimblePublisher depending on your setup.

1. Update all the front-matter to a new format.
1. Rename all your markdown files. In my case, the structure was
   `./blog/blog-id/index.md` with images beside the post, and it moved to
   `./posts/DATE-blog-id.md` with all images moving to `./assets/static/images`.
1. Change all references to images in Markdown posts. **Bummer** point here is
   that it does not use the digested version of images referenced in your
   Markdown posts. This would require NimblePublisher or Earmark (the markdown
   parser) to be aware of resources like images and relative URLs, and replace
   them with Phoenix-generated paths. Currently it is not, and not sure how it
   could be since it's happening at compile-time, and asset digests occur after
   compilation.
1. Convert any React components into Phoenix templates.
1. Make navbar LiveView-aware.

For example, the front-matter went from this:

```yaml
---
title: "Phoenix LiveView and Views"
tags: ["elixir", "phoenix"]
date: 2020-06-29
excerpt: |
  Everytime I build a LiveView application, I learn something new and find a new
  pattern, and some concept finally _clicks_. Today, that concept that cemented
  in my mind is how Phoenix and Phoenix LiveView renders templates.

  I want to show you a couple different View-rendering strategies. This should
  help you decide which strategy to use.
---
```

To this:

```elixir
%{
  title: "Phoenix LiveView and Views",
  tags: ["elixir", "phoenix"],
  description: """
  Every time I build a LiveView application, I learn something new and find a
  new pattern, and some concept finally _clicks_. Today, that concept that
  cemented in my mind is how Phoenix and Phoenix LiveView renders templates.

  I want to show you a couple different View-rendering strategies. This should
  help you decide which strategy to use.
  """
}
---
```

The date moved out of the front-matter and relies only on the filename now on
disk. It was a little tedious, but since my blog only has a handful of articles,
it wasn't worth it to script something.

For the most part, the HTML structure of the page is the same as it was on
Gatsby. I literally copy-pasted the HTML from my Gatsby React components into
the Phoenix templates and modified them to not rely on React.

Getting the navbar links to know what page they were on was another challenge.
I'm using AlpineJS on this blog, so I leverage some event dispatching in
AlpineJS when clicking on navbar links, which is caught and assigns the
active/inactive classes on the links. It's optimistic UI and shadows the
LiveView click events, but it should be fine.

For example:

```html
<!-- lib/bern_web/templates/layout/nav.html.eex -->
<!-- loading the route from the conn will take care of the initial page load -->
<!-- further LiveView-powered navigation needs some help from AlpineJS -->

<% [route | _] = @conn.path_info %>
<nav @navigate="open = false; currentRoute = $event.detail" x-data="{currentRoute: '<%= route %>', open: false}">
  <%= live_redirect "Blog", to: Routes.blog_path(@conn, :index),
    class: "all my classes",
    "@click": "$dispatch('navigate', 'blog')",
    ":class": "{
      'all my active classes': currentRoute === 'blog',
      'all my inactive classes': currentRoute !== 'blog'
    }" %>
  <!-- ... -->
</nav>
```

## Conclusion

I enjoyed the process. I'm making the right decision for myself to evolve a
static-site blog into a web application that also serves static content. If
you're _only_ using it for static content, then it's probably not the right
choice to move to LiveView if all you care about is efficiency.

It turns out that argument for JavaScript-powered static site being _much
better_ than server-generated content is simply not true. Elixir-powered static
sites could also use some help in the areas of syntax highlighting and asset
pipelines; so perhaps that's where I can turn some of my attention to next!

NimblePublisher isn't the only option out there for Phoenix! You could have [a
full-fledged Markdown engine][phoenix-markdown] in Phoenix that renders the
markdown in runtime and interpolates dynamic content during the request. This
would solve the issue of asset versioning.

If I got anything wrong or missed something obvious (totally likely) then please
tell me! [Hit me up on twitter @bernheisel](https://twitter.com/bernheisel)

## Oh yeah, it's open source

[Check out the source](https://github.com/dbernheisel/bernheisel.com). Lastly,
this is hosted on [Linode](https://www.linode.com/?r=11f896e75a7bee1316e6a087df9fd77af1a71553).

[gatsby-remark-vscode]: https://www.gatsbyjs.com/plugins/gatsby-remark-vscode/
[phoenix-markdown]: https://github.com/boydm/phoenix_markdown
