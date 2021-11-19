" vim-pursuit
"
" (C) Copyright 2021 Jeet Sukumaran
"
" Includes code and other work produced by and copyright (c) 2017 Christopher
" Prohm, released and used under the MIT license.
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to
" deal in the Software without restriction, including without limitation the
" rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
" sell copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
" FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
" DEALINGS IN THE SOFTWARE.

" Reload Guard {{{1
" ============================================================================
if exists("g:did_pursuit_plugin") && g:did_pursuit_plugin == 1
    finish
endif
let g:did_pursuit_plugin = 1
" }}} 1

" Compatibility Guard {{{1
" ============================================================================
" avoid line continuation issues (see ':help user_41.txt')
let s:save_cpo = &cpo
set cpo&vim
" }}}1

" Globals {{{1
" ============================================================================
" (NOTE: Uses case-insenstive glob patterns)
let s:pursuit_default_external_handling_filepath_patterns = [
            \   "*.gif",
            \   "*.jpeg",
            \   "*.jpg",
            \   "*.pdf",
            \   "*.png",
            \ ]
let g:pursuit_external_handling_filepath_patterns = get(g:, "pursuit_external_handling_filepath_patterns", s:pursuit_default_external_handling_filepath_patterns)
" }}}1

" Functions {{{1
python3 <<EOF
import collections
import json
import os.path
import re
import sys
import subprocess
from urllib.parse import urlparse
import webbrowser
import vim
import fnmatch

class LinkStack(object):
    def __init__(
            self,
            max_size=100):
        self.max_size = max_size
        self._stack = []
    def push(self, bufn, row, col):
        val = (bufn, row, col)
        if not self._stack or self._stack[-1] != val:
            if len(self._stack) > self.max_size:
                del(self._stack[0])
            self._stack.append(val)
    def pop(self):
        try:
            return self._stack.pop()
        except IndexError:
            return (None, None, None,)

class LinkStackNoSaveException(Exception):
    pass

class Pursuit(object):

    reference_definition_pattern = re.compile(r"^\[[^\]]*\]:(?P<link>.*)$")
    link_pattern = re.compile(r"^(?P<link>\[(?P<text>[^\]]*)\](?:\((?P<direct>[^\)]*)\)|\[(?P<indirect>[^\]]*)\])).*$")
    named_anchor_pattern = re.compile(r"<a *(name|id) *= *('|\")(?P<title>.*?)('|\") *(>.*?< */ *a *>|/ *>)")

    def __init__(self, link_stack=None):
        if int(vim.eval("exists('g:pursuit_external_handling_filepath_patterns')")):
            external_handling_pattern_strs = vim.eval('g:pursuit_external_handling_filepath_patterns')
            self.external_handling_patterns = [re.compile(fnmatch.translate(e), re.IGNORECASE) for e in external_handling_pattern_strs]

        else:
            self.external_handling_patterns = []
        self.heading_pattern = re.compile(r'^#+(?P<title>.*)$')
        self.attr_list_pattern = re.compile(r'{:\s+#(?P<id>\S+)\s')
        self.is_run_external_process_using_vim_shell = False
        if link_stack is None:
            self.link_stack = LinkStack()
        else:
            self.link_stack = link_stack

    def pop_link(self):
        bufn, row, col = self.link_stack.pop()
        if bufn is not None:
            vim.command("b {}".format(bufn))
            vim.command("call setpos('.', [{}, {}, {}, {}])".format(bufn, row, col+1, 0))
            # vim.cursor = (row, col)
        else:
            self._info("Link stack is empty")

    def follow_link(self):
        row, col = vim.current.window.cursor
        cursor = (row - 1, col)
        lines = vim.current.buffer
        self.link_stack.push(vim.current.window.buffer.number, row, col)
        target = self.parse_link(cursor, lines)
        try:
            self.process_link(target, current_file=vim.eval("expand('%:p')"),)
        except LinkStackNoSaveException:
            self.link_stack.pop()

    def process_link(self, target, current_file):
        """
        :returns: a callable that encapsulates the action to perform
        """
        if target is not None:
            target = target.strip()
        if not target:
            self._info("Not on a recognized link")
            raise LinkStackNoSaveException()
        elif target.startswith('#'):
            self.jump_to_anchor(target)
        elif self.has_scheme(target):
            self.browser_open(target)
            raise LinkStackNoSaveException()
        elif self.external_handling_patterns and self.is_matches_external_open_pattern(target):
            self.os_open(self.anchor_path(target, current_file))
            raise LinkStackNoSaveException()
        else:
            if target.startswith('|filename|'):
                target = target[len('|filename|'):]
            if target.startswith('{filename}'):
                target = target[len('{filename}'):]
            return self.vim_open(self.anchor_path(target, current_file))

    def is_matches_external_open_pattern(self, path):
        for pattern in self.external_handling_patterns:
            if pattern.match(path):
                return True

    def anchor_path(self, target, current_file):
        if os.path.isabs(target):
            return target
        return os.path.join(os.path.dirname(current_file), target)

    def has_scheme(self, target):
        return bool(urlparse(target).scheme)

    def jump_to_anchor(self, target):
        if target.startswith("#"):
            target = target[1:]
        title_identifier = target.lower()
        line_idx = None
        col_idx = 0
        for (idx, line) in enumerate(vim.current.buffer):
            m = self.heading_pattern.match(line)
            if (m is not None
                    and self.title_to_anchor(m.group("title")) == title_identifier):
                line_idx = idx
                break
            # m = self.attr_list_pattern.search(line)
            # if m is not None and title_identifier == m.group("id"):
            #     line_idx = idx
            #     break
            for m in self.named_anchor_pattern.finditer(line,):
                # if m is not None:
                #     print("{: 3d}: {}".format(idx+1, m.group("title")))
                if m is not None and m.group("title") == title_identifier:
                    span = m.span()
                    line_idx = idx
                    col_idx = span[0]
                    break
            else:
                # only executed if the inner loop did NOT break
                # so move on to the next buffer line (and do not abnormally terminate the inner loop)
                continue
            # only executed if the inner loop DID break
            # which means we found anchor
            break
        if line_idx is None:
            self._error("Anchor not found: {}".format(target))
            raise LinkStackNoSaveException()
        vim.command("execute 'normal! {}G{}|'".format(line_idx+1, col_idx))

    def browser_open(self, target):
        webbrowser.open_new_tab(target)

    def os_open(self, target):
        if sys.platform.startswith('linux'):
            self._shell_call(['xdg-open', target])
        elif sys.platform.startswith('darwin'):
            self._shell_call(['open', target])
        else:
            os.startfile(target)

    def vim_open(self, target):
        path, anchor, line_nr = self.parse_link_spec(target)
        vim.command('e {}'.format(path.replace(' ', '\\ ')))
        if anchor is not None:
            self.jump_to_anchor(anchor)
        elif line_nr is not None:
            try:
                line_nr = int(line_nr)
            except:
                self._error("Invalid line number: {}".format(line_nr))
                raise LinkStackNoSaveException()
            else:
                vim.current.window.cursor = (line_nr, 0)

    def title_to_anchor(self, title):
        return '-'.join(part.lower() for part in title.split())

    def parse_link(self, cursor, lines):
        row, column = cursor
        line = lines[row]
        m = self.reference_definition_pattern.match(line)
        if m is not None:
            return m.group('link').strip()
        link_text, rel_column = self.select_from_start_of_link(line, column)
        if not link_text:
            return None
        m = self.link_pattern.match(link_text)
        if not m:
            return None
        if m.end('link') <= rel_column:
            return None
        assert (m.group('direct') is None) != (m.group('indirect') is None)
        if m.group('direct') is not None:
            return m.group('direct')
        indirect_ref = m.group('indirect')
        if not indirect_ref:
            indirect_ref = m.group('text')
        indirect_link_pattern = re.compile(
            r'^\[' + re.escape(indirect_ref) + r'\]:(.*)$'
        )
        for line in lines:
            m = indirect_link_pattern.match(line)

            if m:
                return m.group(1).strip()
        return None

    def select_from_start_of_link(self, line, pos):
        if pos < len(line) and line[pos] == '[':
            start = pos
        else:
            start = line[:pos].rfind('[')
        # TODO: handle escapes
        if start < 0:
            return None, pos
        # check for indirect links
        if start != 0 and line[start - 1] == ']':
            alt_start = line[:start].rfind('[')
            if alt_start >= 0:
                start = alt_start

        return line[start:], pos - start

    def parse_link_spec(self, link_spec):
        path = link_spec
        anchor = None
        line_nr = None
        if "#" in link_spec:
            path, anchor = link_spec.rsplit("#", 1)
        elif ":" in link_spec:
            path, line_nr = link_spec.rsplit(":", 1)
        return path, anchor, line_nr

    def _shell_call(self, args):
        if self.is_run_external_process_using_vim_shell:
            args = ['shellescape(' + json.dumps(arg) + ')' for arg in args]
            vim.command('execute "! " . ' + ' . " " . '.join(args))
        else:
            try:
                subprocess.check_call(args)
            except subprocess.CalledProcessError as e:
                self._error("cannot open file", e)

    def _error(self, msg, additional=None):
        if msg:
            print("[pursuit] {}".format(msg))
        if additional:
            print(additional)
        # if msg:
        #     sys.stderr.write("[pursuit] {}\n".format(msg))
        # if additional:
        #     sys.stderr.write(additional)

    def _info(self, msg):
        if msg:
            print("[pursuit] {}".format(msg))

    def dump_link_stack(self, message=None, dest=None):
        if dest is None:
            dest = sys.stdout
        if message is not None:
            dest.write(">>> {} >>>\n".format(message))
        dest.write("Pursuit {}, Current link stack ({}):\n".format(id(self), id(self.link_stack)))
        for x in self.link_stack._stack[::-1]:
            dest.write("- {}\n".format(x))

pursuit = Pursuit()

EOF
" }}}1

" Functions {{{1
" ============================================================================

function! s:_pursuit_find_next_link()
    call search('\[.\{-}\](.\{-})', 'w')
endfunction

function! s:_pursuit_find_prev_link()
    call search('\[.\{-}\](.\{-})', 'bw')
endfunction

function! s:_pursuit_apply_syntax(on)
    " let g:pursuit_link_conceal_char = get(g:, "pursuit_link_conceal_char", "🔗")
    " let g:pursuit_anchor_conceal_char = get(g:, "pursuit_anchor_conceal_char", "⚓")
    let g:pursuit_link_conceal_char = get(g:, "pursuit_link_conceal_char", "🗲")
    let g:pursuit_anchor_conceal_char = get(g:, "pursuit_anchor_conceal_char", "🖈")
    if a:on
        if get(g:, "pursuit_conceal_links", 1)
            syntax match pursuitLineText '\[.\{-}\]' skipwhite
            execute 'syntax match pursuitLinkUrl  +\(\\\@<!\[.\{-}\]\)\@<=\((.\{-})\|\[.\{-}\]\)+ conceal skipwhite cchar=' . g:pursuit_link_conceal_char
            let sq = "'"
            execute 'syntax match pursuitNamedAnchor +<a *\(name\|id\) *= *\(' .sq . '\|"\).\{-}\(' . sq . '\|"\) *\(>.\{-}< */ *a>\|/ *>\)+ conceal skipwhite cchar='. g:pursuit_anchor_conceal_char
            highlight default link markdownLinkText Directory
            highlight default link markdownUrl SpecialKey
            highlight default link pursuitLineText markdownLinkText
            highlight default link pursuitLinkUrl markdownUrl
            highlight default link pursuitNamedAnchor Special
            execute "setlocal conceallevel=" . get(g:, "pursuit_default_conceal_level", 2)
        endif
        if get(g:, "pursuit_fix_indented_code_region_bug", 1)
            " ref: https://stackoverflow.com/questions/55645317/how-to-disable-a-syntax-region-in-vim-syntax-highlighting
            " ref: https://github.com/tpope/vim-markdown/pull/140/files
            try
                syn clear markdownCodeBlock
            catch /E28/
            endtry
            syn region markdownCodeBlock start="\n\(    \|\t\)" end="\v^((\t|\s{4})@!|$)" contained
        endif
    else
        try
            syntax clear pursuitLink
            syntax clear pursuitLineText
            syntax clear pursuitNamedAnchor
        catch /E28/
        endtry
    endif
endfunction

function! s:_pursuit_apply_keymaps(bang)
    if a:bang || !get(g:, "pursuit_keymaps_applied", 0)
        nmap <silent> g<CR>   <Plug>(PursuitFollowLink)
        " nnoremap <silent> <C-[> <C-o>
        nmap <silent> g<BS>    <Plug>(PursuitReturnFromLink)
        nmap <silent> z]      <Plug>(PursuitFindLinkNext)
        nmap <silent> z[      <Plug>(PursuitFindLinkPrev)
        let g:pursuit_keymaps_applied = 1
    endif
endfunction

function! s:_pursuit_apply(bang)
    if a:bang || get(g:, "pursuit_default_key_maps", 1)
        call s:_pursuit_apply_keymaps(a:bang)
    endif
    call s:_pursuit_apply_syntax(1)
endfunction

" }}}1

" Commands {{{1
" ============================================================================

" Core Commands
command! PursuitFollowLink :python3 pursuit.follow_link()
command! PursuitReturnFromLink :python3 pursuit.pop_link()
command! PursuitFindLinkNext :call s:_pursuit_find_next_link()
command! PursuitFindLinkPrev :call s:_pursuit_find_prev_link()

" Setup Commands
command! -bang PursuitApply :call s:_pursuit_apply(<bang>0)
command! -bang PursuitApplyKeymaps :call s:_pursuit_apply_keymaps(<bang>0)
command! PursuitApplySyntax :call s:_pursuit_apply_syntax(1)
command! PursuitUnapplySyntax :call s:_pursuit_apply_syntax(0)

" }}}1

" Key Mappings {{{1
" ============================================================================
nnoremap <Plug>(PursuitFollowLink) :PursuitFollowLink<CR>
nnoremap <Plug>(PursuitReturnFromLink) :PursuitReturnFromLink<CR>
nnoremap <Plug>(PursuitFindLinkNext) :PursuitFindLinkNext<CR>
nnoremap <Plug>(PursuitFindLinkPrev) :PursuitFindLinkPrev<CR>
" }}}1

" Autostart {{{1
augroup pursuit
    autocmd!
    autocmd BufNewFile,BufFilePre,BufRead *.txt,*.txt,*.md,*.markdown :PursuitApply
augroup END
" }}}1

" Restore State {{{1
" ============================================================================
" restore options
let &cpo = s:save_cpo
" }}}1
