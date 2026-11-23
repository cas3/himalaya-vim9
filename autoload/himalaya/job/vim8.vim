let s:stdout = []
let s:stderr = []

function! himalaya#job#vim8#start(cmd, on_data) abort
  if v:version < 800 | throw 'incompatible vim version' | endif
  if !has('job') | throw 'job feature missing' | endif
  if !has('channel') | throw 'channel feature missing' | endif

  let s:stdout = []
  let s:stderr = []
  
  let cmd = split(a:cmd, ' -- ')
  if has('win32') && fnamemodify(&shell, ':t') =~? '^cmd\%(\.exe\)\?$'
    " job_start(List) escapes embedded quotes with backslashes on Windows,
    " but cmd.exe /c does not understand backslash-escaped quotes.
    " Use a String and wrap the command for cmd.exe /s /c instead.
    let command = shellescape(&shell) . ' /s ' . &shellcmdflag . ' "' . cmd[0] . '"'
  else
    let command = [&shell] + split(&shellcmdflag) + [cmd[0]]
  endif
  let job = job_start(command, {
  \ 'env': {'RUST_LOG': 'off'},
  \ 'out_mode': 'nl',
  \ 'out_cb': {_, line -> s:on_out(line)},
  \ 'err_cb': {_, line -> s:on_err(line)},
  \ 'close_cb': {-> s:on_close(a:on_data)},
  \})

  if len(cmd) > 1
    let channel = job_getchannel(job)
    call ch_sendraw(channel, join(cmd[1:], ' -- '))
    call ch_close_in(channel)
  endif
endfunction

function! s:on_out(line) abort
  let s:stdout += [a:line]
endfunction

function! s:on_err(line) abort
  let s:stderr += [a:line]
endfunction

function! s:on_close(callback) abort
  if !empty(s:stderr)
    for line in s:stderr
      call himalaya#log#err(line)
    endfor
    redraw
    throw 'CLI error, see :messages for more information'
  endif
  call a:callback(s:stdout)
endfunction
