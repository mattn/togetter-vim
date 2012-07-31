scriptencoding utf-8

function! s:wrap(content)
  if &l:wrap != 0
    return a:content
  end
  let lines = split(a:content, '[\r\n]\+')
  let idx = 0
  while idx < len(lines)
    let w = strdisplaywidth(lines[idx])
    if w >= &columns
      let [line, ins] = ['', '']
      for c in split(lines[idx], '\zs')
        if strdisplaywidth(line . c) >= &columns
          let m = matchstr(line, '[\x21-\x7f]\+$')
          let ins .= line[:-1-len(m)] . "\n"
          let line = m
        endif
        let line .= c
      endfor
      let ins .= line . "\n"
      if idx == 0
        let lines = split(ins, '\n') + lines[idx+1:]
      else
        let lines = lines[0: idx-1] + split(ins, '\n') + lines[idx+1:]
      endif
    endif
    let idx += 1
  endwhile
  return join(lines, "\n")
endfunction

function! s:match(node)
  if !has_key(a:node.attr, 'class')
    return 0
  endif
  return stridx(' '.a:node.attr['class'].' ', ' tweet ') != -1
endfunction

function! s:sid()
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfun

function! s:togetter_list(arg)
  let winnum = bufwinnr(bufnr('^Togetter$'))
  if winnum != -1
    if winnum != bufwinnr('%')
      exe winnum 'wincmd w'
    endif
  else
    exec 'silent noautocmd split Togetter'
  endif
  setlocal modifiable
  silent %d _
  redraw | echo "fetching feed..."
  call setline(1, map(webapi#feed#parseURL(a:arg), 'v:val["title"]." : ".v:val["link"]'))
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal nomodified
  setlocal nomodifiable
  nmapclear <buffer>
  syn clear
  syntax match SpecialKey /[\x21-\x7f]\+$/
  nnoremap <silent> <buffer> <cr> :call <SID>togetter_action()<cr>
  exe "nnoremap <silent> <buffer> <leader><leader> :call <SID>togetter_list('".a:arg."')<cr>"
  redraw | echo ""
endfunction

function! s:togetter_action()
  let line = getline('.')
  call s:togetter(matchstr(line, '.* : \zshttp:\S\+\s*$'))
endfunction

function! s:togetter(arg)
  if a:arg =~ '^\d\+$'
   let url = 'http://togetter.com/li/%d', a:arg)
  else
   let url = a:arg
  endif
  setlocal modifiable
  silent %d _
  redraw | echo "fetching tweets..."
  let res = webapi#http#get(url)
  let html = iconv(res.content, 'utf-8', &encoding)
  let html = matchstr(html, '<body[^>]*>\zs.*\ze</body>')
  redraw | echo "parsing data..."
  let dom = webapi#html#parse(html)
  let t = dom.find('a', {"class": "info_title"})
  let title = empty(t) ? "" : t.value()
  let lines = ['['.title.']']
  redraw | echo "formatting tweets..."
  for balloon in dom.findAll('div', {'class': 'balloon_module'})
    let tweet = balloon.find('div', function(printf('<SNR>%d_match', s:sid())))
    if empty(tweet)
      continue
    endif
    let name = balloon.find('a', {'class': 'status_name'})
    let lines += split(s:wrap(tweet.value()), '\n')
    let lines += [name.value()]
    let lines += ['--------------------']
  endfor

  let winnum = bufwinnr(bufnr('^Togetter$'))
  if winnum != -1
    if winnum != bufwinnr('%')
      exe winnum 'wincmd w'
    endif
  else
    exec 'silent noautocmd split Togetter'
  endif
  setlocal modifiable
  silent %d _
  call setline(1, lines)
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal nomodified
  setlocal nomodifiable
  syn clear
  syntax match Constant /^[a-zA-Z0-9_]*$/
  syntax match SpecialKey /^-\+$/
  syntax match Type /\<\(http\|https\|ftp\):\/\/[\x21-\x7f]\+/
  syntax match WarningMsg /\%1l.*/
  nmapclear <buffer>
  exe "nnoremap <silent> <buffer> <leader><leader> :call <SID>togetter('".url."')<cr>"
  redraw | echo ""
endfunction

command! -nargs=0 TogetterHot call s:togetter_list('http://togetter.com/rss/index')
command! -nargs=0 TogetterRecent call s:togetter_list('http://togetter.com/rss/recent')
command! -nargs=1 Togetter call s:togetter(<q-args>)
