%{
  title: "NewTab Notes Extension",
  tags: ["chrome", "javascript"],
  description: """
  Today I published a new Chrome Extension in the Chrome Web Store. This
  extension replaces the New Tab page with a rendered markdown page that you can
  edit. It's customizable too!
  """
}
---

Today I [published a new Chrome Extension in the Chrome Web Store][extension].
This extension replaces the New Tab page with a rendered markdown page that you
can edit. It's customizable too!

[extension]: https://chrome.google.com/webstore/detail/newtab-notes/kfbhbipgippofpifimbcnbafehjndccn

[I made it open-source as well.](https://github.com/dbernheisel/MarkdownTab)

![screenshot](/images/newtab-notes-screenshot.png)

I've been trying to get in the habit of taking more notes and writing notes
down before I forget about them. I also use the Chrome browser. The way I look
for information in Chrome is by opening a new tab and start typing away for the
question. What if the new tab had some information on it that I could stow away?

There's plenty of existing extensions out there and I tried about 5 or 6 of them
but they didn't suite my taste or needs. If it didn't sync between Chrome
devices, then my notes would be scattered across machines -- no go. Often times,
the markdown syntax it provided was vanilla Markdown, but I'm used to newer
features and extensions offered by GitHub Flavored Markdown, such as task lists,
tables, and autolinking. If it didn't support GFM -- no go.

I'm working on a project using Elixir, Vue, and Tailwind CSS, and I wanted to
practice using those frameworks so I can understand them more. It's all about
the repetition for learning.

Since I know nothing about Chrome Extension development, I [found an existing
extension](https://github.com/intrvertmichael/markdown-tab) that was pretty close
to what I wanted. I forked it and started customizing it for my own wants.
Fiddling around with the code made me understand more of what makes it
Chrome-specific, which isn't too much, and the rest was just
plain-old-javascript. This led me down the path of using Vue and TailwindCSS,
and packaging it with Webpack-- just like I do with my Elixir project.

- Chrome needs a [`manifest.json`] to specify the icon, description, and
    permissions it needs to operate within Chrome.
- In the manifest, you specify the entry point HTML. In my case, I needed
    the new tab page.
- There are some Chrome APIs you can use. The only one that I care about is
    [`chrome.storage.sync`]. This handles storing small data related to your
    extension and handles offline and online capabilities. If you're offline,
    then it's ok and will store the data in local storage until you're online
    again, which then it will sync through the net and update your other
    devices.

Maybe one day I can make it more like [vimwiki] which offers multi-page
linking, but for now it's fine.

[`manifest.json`]: https://developer.chrome.com/docs/extensions/mv2/manifest/
[`chrome.storage.sync`]: https://developer.chrome.com/docs/extensions/reference/storage/
[vimwiki]: https://github.com/vimwiki/vimwiki
