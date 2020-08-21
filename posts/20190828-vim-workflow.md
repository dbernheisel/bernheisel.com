%{
  title: "VIM Testing and Workflow",
  tags: ["elixir", "ruby", "vim"],
  description: """
  If you develop in Ruby or Elixir or write Markdown, you might find this
  helpful!
  """
}
---

I realized that I love my VIM workflow, so I want to share that with you.
I am by-no-means a VIM expert or purist -- my [neovim] files are not slim and
are a melting pot of stolen code from others, sometimes modified or not,
sometimes found in GitHub comments, sometimes found in others' dotfiles, or
Reddit comments.

If you develop in Ruby or Elixir or write Markdown, you might find this helpful!

Let's start with some basics:

## Environment

* [neovim] - right now I'm using 0.4.0 so I can use floating windows.
* [kitty] Terminal Emulator
* built-in terminal in neovim
* [ArchLinux] - My distro of choice. Shouldn't matter for this article.
* [i3] - My window manager. Shouldn't matter for this article.
* [Plug] - for managing neovim plugins.
* [coc.nvim] for languageserver integration.
* [dotfiles] - My dotfiles if you want the complete picture

There are three ways that I can split my workspace: (1) via my window manager
[i3], (2) via my terminal emulator [kitty], (3) via [neovim] with
splits/buffers. Generally I adhere to this practice:

  1) Split with i3 if it's an application, especially a GUI app. This gives me
     the ability to move the window to another desktop if I want.
  2) Split with built-in neovim terminal for tests.
  3) Don't split with kitty ever. It'd be too confusing for me to have 3 sets of
     keyboard shortcuts to keep track of for switching windows/panes/splits.
     Maybe one day I'll replace the built-in neovim terminal with a kitty split
     or an i3 split.

[neovim]: https://neovim.io
[ArchLinux]: https://www.archlinux.org
[i3]: https://github.com/Airblader/i3
[kitty]: https://sw.kovidgoyal.net/kitty/
[Plug]: https://github.com/junegunn/vim-plug
[coc.nvim]: https://github.com/neoclide/coc.nvim
[dotfiles]: https://github.com/dbernheisel/dotfiles

## Testing

I use [vim-test] and it's pretty incredible. I picked this workflow up while
working at thoughtbot from some good friends and the [thoughtbot dotfiles],
and it changed the way I code. The whole TDD workflow is great despite that I
still have trouble actually writing tests first - I tend to spike, iterate,
iterate, THEN write tests, then open a PR. Yea-- this probably means I'm not a
10x developer 😛

I also use neoterm to help open up terminal splits. When I'm at home, I have an
ultrawide that I use so splitting windows vertically is the way to go; but when
I'm mobile with my laptop then I typically split horizontally. I want tests to
be visible either way, so I need this to be flexible.

The vim-test neoterm strategy defaults to sending tests to the last-used neoterm
buffer; I can have more terminal buffers, but the first one I open is what
vim-test will use going forward.

[thoughtbot dotfiles]: https://github.com/thoughtbot/dotfiles
[vim-test]: https://github.com/vim-test/vim-test
[neoterm]: https://github.com/kassio/neoterm

Here's how I configure vim-test with neoterm. (my [dotfiles] for reference)

```vim
" ~/.config/nvim/init.vim

" Test
let g:test#strategy = "neoterm"
let g:neoterm_shell = '$SHELL -l' " use the login shell
let g:neoterm_default_mod = 'vert'
let g:neoterm_autoscroll = 1      " autoscroll to the bottom when entering insert mode
let g:neoterm_size = 80
let g:neoterm_fixedsize = 1       " fixed size. The autosizing was wonky for me
let g:neoterm_keep_term_open = 0  " when buffer closes, exit the terminal too.
let test#ruby#rspec#options = { 'suite': '--profile 5' }

" Create some commands that makes the splits easy

function! OpenTermV(...)
  let g:neoterm_size = 80
  let l:cmd = a:1 == '' ? 'pwd' : a:1
  execute 'vert T '.l:cmd
endfunction

function! OpenTermH(...)
  let g:neoterm_size = 10
  let l:cmd = a:1 == '' ? 'pwd' : a:1
  execute 'belowright T '.l:cmd
endfunction

command! -nargs=? VT call OpenTermV(<q-args>)
command! -nargs=? HT call OpenTermH(<q-args>)

" Use the project's test suite script if it exists

function! RunTestSuite()
  Tclear
  if filereadable('bin/test_suite')
    T echo 'bin/test_suite'
    T bin/test_suite
  elseif filereadable("bin/test")
    T echo 'bin/test'
    T bin/test
  else
    TestSuite
  endif
endfunction

nmap <silent> <leader>t :call TestNearest<CR>
nmap <silent> <leader>T :call TestFile<CR>
nmap <silent> <leader>a :call RunTestSuite()<CR>
nmap <silent> <leader>l :call TestLast<CR>
```

I've found it conventional to have a `bin/test_suite` or `bin/test` script in
the project that takes care of a lot of details like environment exports,
cleanup, or making sure the test environment's database is setup as well as
running all the tests. Even if the test suite isn't complicated, it's still
helpful for new developers on the project.

If that script is present and when I want to run all tests, I should execute
that file; otherwise use the default vim-test suite command. For non-suite
tests, I use the default vim-test commands.

`<space>a` triggers **a**ll tests. If a neoterm split isn't open,
then it'll automatically open one with the default settings-- in my case, a
vertical split at 80 columns wide. If a neoterm split is already open, then
it'll send the test to that split. In situations where my vertical space is
lacking, I prep by opening up a split, and then hit my test shortcut. `:HT` to
open the terminal up.

If I'm testing a method or function, then `<space>t` to send the nearest
**t**est to it. If I'm trying to make a test pass, I'll modify the code and then
`<space>l` to run the **l**ast test. If I'm refactoring a class or module, I'll
run all the **T**ests for it. I haven't found myself using vim-test's TestVisit.
If you have some examples on where that command helps, I'd love to hear it!

[![asciicast](https://asciinema.org/a/gs6r5QlC8oR8HPNYhRPDypY6n.svg)](https://asciinema.org/a/gs6r5QlC8oR8HPNYhRPDypY6n)

## Transformations

This is a great start! But eventually there might be a pesky app where I need to
opt-into an environment variable, but only when I'm running a small number of
tests. vim-test lets me define my own transformations to the commands. I can
check for a certain file and string in it to determine what project I'm in. If
I'm in that project, then change the command where I can.

```vim
" ~/.config/nvim/after/ftplugin/ruby.vim

function! MyAppRspec(cmd) abort
  " If I'm in the pesky app and
  " not running the entire test suite indicated by the --profile flag
  " Add the SKIP_FIXTURES env var.
  call system("cat README.md | grep 'MyApp'")
  if match(a:cmd, '--profile') == -1 && v:shell_error == 0
    return substitute(a:cmd, 'bundle exec', 'SKIP_FIXTURES=true bundle exec', '')
  else
    return a:cmd
  endif
endfunction

let g:test#custom_transformations = {
      \ 'myapp_ruby': function('MyAppRspec')
      \ }
let g:test#transformation = 'myapp_ruby'
```

On the Elixir side, umbrella apps can be a little tricky. vim-test will send the
path of the test to `mix test {file}`, but `mix` will run that command for each
of the apps in the umbrella. That's probably not what we want to do since that
test exists for only one for apps. Again, we can solve it with a transformation.

```vim
" ~/.config/nvim/after/ftplugin/elixir.vim

function! ElixirUmbrellaTransform(cmd) abort
  " if in an umbrella project indicated by the existence of an ./apps folder
  " limit the mix command to the app to which the test belongs
  if match(a:cmd, 'apps/') != -1
    " capture the app from the file path, and send it to the --app flag instead
    return substitute(a:cmd, 'mix test apps/\([^/]*\)/', 'mix cmd --app \1 mix test --color ', '')
  else
    return a:cmd
  end
endfunction

let g:test#custom_transformations = {
       \ 'elixir_umbrella': function('ElixirUmbrellaTransform')
       \ }
let g:test#transformation = 'elixir_umbrella'
```

That's it for tests!

Hope you picked up something nifty. If you have any tips for me, send them my
way [@bernheisel]

[@bernheisel]: https://twitter.com/bernheisel
