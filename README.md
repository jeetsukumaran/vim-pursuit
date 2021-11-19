# Pursuit

**pursuit** is a Vim plugin for navigating links in Markdown files.
**pursuit** is based on [mdnav](https://github.com/chmp/mdnav), a project by [Christopher Prohm](https://github.com/chmp).

It can handle:

- **Local text links**:
    `[foo](second.md)` will be opened inside vim.
    If the target contains line number as in `[foo](second.md:30)`, the line
    will be jumped to.
    Also anchors are supported, for example `[foo](second.md#custom-id)`.
- **URL links**:
    `[google](https://google.com)` will be opened with the OS browser.
- **Non-text files**:
    A list of file patterns (`g:pursuit_external_handling_filepath_patterns`)
    that specify files to be opened via the operating system instead of in Vim.
    This allows for linking to and opening binary documents, for example PDFs.
- **Internal links to headings**:
    `[Link Text](#Target)` will link to the heading `# Target`.
    Following the link will jump to the heading inside vim.
    Currently both github style anchors, all words lowercased and hyphenated,
    and jupyter style anchors, all words hyphenated, are supported.
- **Links to named anchors**:
    Links in the form of `[foo](#bar)` will also connect to "named anchors", i.e.,
    tokens located anywhere in the buffer (and not neccessarily associated with
    headings) in the form of `<a name="bar"></a>`.
- **Reference style links**:
    for links of the form `[foo][label]`, **Pursuit** will lookup the corresponding
    label and open the target referenced there.
    This mechanism works will all link targets.
- **Implicit name links**:
    for links of the form `[foo][]` will use `foo` as the label and then follow
    the logic of reference style links.
- **Custom ids via attribute lists**:
    the id of a link target can be defined via [attribute lists][attr-lists] of
    the form `{: #someid ...}`.
    This way fixed name references can be defined to prevent links from going
    stale after headings have been changed.
- **Local link format of Pelican**:
    **Pursuit** handles `|filename| ...` and `{filename} ...` links as expected, for
    example `[link](|filename|./second.md)` and
    `[link]({filename}../posts/second.md)`.

[label]: https://google.com
[foo]: https://wikipedia.org
[fml]: https://github.com/prashanthellina/follow-markdown-links
[attr-lists]: https://pythonhosted.org/Markdown/extensions/attr_list.html

## Installation

-   Clone the repository into your installation's package directory:

    ```
    cd ~/.vim/pack/standard/start
    git clone https://github.com/jeetsukumaran/vim-pursuit.git
    ```

-   Or otherwise use your preferred third-party package manager in your
    configuration file (i.e., "``.vimrc``", "``init.vim``" etc.), making sure
    to specify the "``main``" branch. For e.g.,:
    -   [vim-plug](https://github.com/junegunn/vim-plug)
    ```
    Plug 'jeetsukumaran/vim-pursuit', {'branch': 'main'}
    ```
    -   [packer](https://github.com/wbthomason/packer.nvim)
    ```
    use {'jeetsukumaran/vim-pursuit', branch = 'main'}
    ```


## Usage

Inside normal mode with an open Markdown document, you may press `g<Enter>` on a
Markdown link to open it.
If the link is a local file (with a name that does not match any pattern in
specified in the external application list), it will be opened in Vim
Otherwise it will be opened by the current browser.
If opened in Vim, the previous position is stored in the jumplist, so you can
hop back with "`<C-o>`", as well as in a specialized "link stack", and so can
pop back using "`g<BS>`".

## Commands

### Core Commands

**Pursuit** provides a set of commands as well as a set ["`<Plug>`"](https://neovim.io/doc/user/map.html#%3CPlug%3E) internal mappings for these commands.
By default, these internal mappings will be bound to keys as show below.


| Command                  | Action                                                                    | Internal Key Map                | Default Binding |
|--------------------------|---------------------------------------------------------------------------|---------------------------------|-----------------|
| `:PursuitFollowLink`     | Open link under cursor; if opened in Vim, push current position to stack. | `<Plug>(PursuitFollowLink)`     | ``<g><CR>``     |
| `:PursuitReturnFromLink` | Pop previous link position from stack                                     | `<Plug>(PursuitReturnFromLink)` | ``<g><BS>``     |
| `:PursuitFindLinkNext`   | Search forward in current buffer for link                                 | `<Plug>(PursuitFindLinkNext)`   | ``z]``          |
| `:PursuitFindLinkPrev`   | Search bacward in current buffer for link                                 | `<Plug>(PursuitFindLinkPrev)`   | ``z[``          |

If you defined "``g:pursuit_default_key_maps``" to be 0 in your configuration file, then the above commands will not be bound to any keys.
You can then add custom bindings yourself in your configuration file.
For e.g., the following replicates the default bindings:

```
let g:pursuit_default_key_maps = 0
nmap <silent> g<CR>   <Plug>(PursuitFollowLink)
nmap <silent> g<BS>   <Plug>(PursuitReturnFromLink)
nmap <silent> z]      <Plug>(PursuitFindLinkNext)
nmap <silent> z[      <Plug>(PursuitFindLinkPrev)
```

### Setup Commands

| Command                | Action                            |
|------------------------|-----------------------------------|
| `:PursuitApply`        | Setup conceal syntax and key maps |
| `:PursuitApplyKeymaps` | Setup key maps                    |
| `:PursuitApplySyntax`  | Setup syntax                      |

## Options

The behavior of *pursuit* can be configured via the following options:

-   `g:pursuit_default_key_maps`
-   `g:pursuit_conceal_links`
-   `g:pursuit_default_conceal_level`
-   `g:pursuit_link_conceal_char`
-   `g:pursuit_anchor_conceal_char`
-   `g:pursuit_external_handling_filepath_patterns`:
    a list of file pattern (strings).
    Filepaths that match one of the glob patterns will be opened via the
    configured application (using `open` on OSX and `xdg-open` on linux).
    This option may be useful to link to non-text documents, say PDF files.
-   `g:pursuit_fix_indented_code_region_bug`


## License

>  The MIT License (MIT)
>
>  Copyright (c) 2021 Jeet Sukumaran
>
>  Includes code and other work produced by and copyright (c) 2017 Christopher
>  Prohm, released and used under the MIT license.
>
>  Permission is hereby granted, free of charge, to any person obtaining a copy
>  of this software and associated documentation files (the "Software"), to
>  deal in the Software without restriction, including without limitation the
>  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
>  sell copies of the Software, and to permit persons to whom the Software is
>  furnished to do so, subject to the following conditions:
>
>  The above copyright notice and this permission notice shall be included in
>  all copies or substantial portions of the Software.
>
>  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
>  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
>  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
>  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
>  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
>  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
>  DEALINGS IN THE SOFTWARE.

