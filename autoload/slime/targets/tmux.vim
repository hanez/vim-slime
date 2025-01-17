
function! slime#targets#tmux#config() abort
  if !exists("b:slime_config")
    let b:slime_config = {"socket_name": "default", "target_pane": ""}
  end
  let b:slime_config["socket_name"] = input("tmux socket name or absolute path: ", b:slime_config["socket_name"])
  let b:slime_config["target_pane"] = input("tmux target pane: ", b:slime_config["target_pane"], "custom,slime#targets#tmux#pane_names")
  if b:slime_config["target_pane"] =~ '\s\+'
    let b:slime_config["target_pane"] = split(b:slime_config["target_pane"])[0]
  endif
endfunction

function! slime#targets#tmux#send(config, text)
  let target_cmd = s:target_cmd(a:config["socket_name"])
  let bracketed_paste = slime#config#resolve("bracketed_paste")

  let [text_to_paste, has_crlf] = [a:text, 0]
  if bracketed_paste
    if a:text[-2:] == "\r\n"
      let [text_to_paste, has_crlf] = [a:text[:-3], 1]
    elseif a:text[-1:] == "\r" || a:text[-1:] == "\n"
      let [text_to_paste, has_crlf] = [a:text[:-2], 1]
    endif
  endif

  " reasonable hardcode, will become config if needed
  let chunk_size = 1000

  for i in range(0, len(text_to_paste) / chunk_size)
    let chunk = text_to_paste[i * chunk_size : (i + 1) * chunk_size - 1]
    call slime#common#write_paste_file(chunk)
    call slime#common#system(target_cmd . " load-buffer %s", [slime#config#resolve("paste_file")])
    call slime#common#system(target_cmd . " send-keys -X -t %s cancel", [a:config["target_pane"]])
    if bracketed_paste
      call slime#common#system(target_cmd . " paste-buffer -d -p -t %s", [a:config["target_pane"]])
    else
      call slime#common#system(target_cmd . " paste-buffer -d -t %s", [a:config["target_pane"]])
    end
  endfor

  " trailing newline
  if has_crlf
    call slime#common#system(target_cmd . " send-keys -t %s Enter", [a:config["target_pane"]])
  end
endfunction

" -------------------------------------------------

function! slime#targets#tmux#pane_names(A,L,P)
  let target_cmd = s:target_cmd(b:slime_config["socket_name"])
  let format = '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{window_name}#{?window_active, (active),}'
  return slime#common#system(target_cmd . " list-panes -a -F %s", [format])
endfunction

function! s:target_cmd(socket_name)
  " socket with absolute path: use tmux -S
  if a:socket_name =~ "^/"
    return "tmux -S " . shellescape(a:socket_name)
  endif
  " socket with relative path: use tmux -L
  return "tmux -L " . shellescape(a:socket_name)
endfunction
