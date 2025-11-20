vim9script

# SearchAndReplace Plugin
# Usage: :SR 'search_term' 'replace_term' [pattern]

command! -nargs=+ -complete=file SR SearchAndReplace(<q-args>)

def SearchAndReplace(args_str: string)
    var args = ParseArgs(args_str)
    if len(args) < 2
        echoerr "Usage: :SR 'search_term' 'replace_term' [pattern]"
        return
    endif

    var search_term = args[0]
    var replace_term = args[1]
    var pattern = "."

    if len(args) >= 3
        pattern = args[2]
    endif

    # Debug output to help diagnose issues
    echo "Search Term: " .. search_term
    echo "Replace Term: " .. replace_term
    echo "Pattern: " .. pattern
    
    # Use -r for recursive search to avoid shell expansion issues with **/*
    var grep_cmd = 'grep! -r -F ' .. shellescape(search_term) .. ' ' .. pattern
    echo "Executing: " .. grep_cmd

    # 1. Search for the search term with :grep -F
    try
        execute grep_cmd
    catch
        echoerr "Grep command failed: " .. v:exception
        echo "Command was: " .. grep_cmd
        return
    endtry
    redraw!

    var qflist = getqflist()
    if empty(qflist)
        echo "No matches found for: " .. search_term
        return
    endif

    # 2. Open quickfix window
    copen

    var replace_all = false
    var logs = []
    
    var i = 0
    var start_col = 0
    var history = []

    # 3. Ask for every quickfix in the list
    while i < len(qflist)
        var item = qflist[i]
        if item.valid == 0
            i += 1
            start_col = 0
            continue
        endif

        # Load buffer if not loaded
        if !bufexists(item.bufnr)
            i += 1
            start_col = 0
            continue
        endif
        
        # Switch to the buffer and line
        execute 'buffer ' .. item.bufnr
        cursor(item.lnum, 1)
        
        var line_content = getline(item.lnum)
        
        var col = stridx(line_content, search_term, start_col)
        if col == -1
            # No more matches on this line, move to next item
            i += 1
            start_col = 0
            continue
        endif
        
        cursor(item.lnum, col + 1)
        
        redraw

        var choice = ''
        if replace_all
            choice = 'y'
        else
            echo "Match found in " .. bufname(item.bufnr) .. ":" .. item.lnum
            echo line_content
            
            # Highlight the search term
            # SRSubtle highlights all matches (context) - mild gray background
            if &background == 'dark'
                highlight SRSubtle ctermbg=237 guibg=#3a3a3a guifg=NONE ctermfg=NONE
            else
                highlight SRSubtle ctermbg=253 guibg=#dadada guifg=NONE ctermfg=NONE
            endif
            var match_id = matchadd('SRSubtle', '\V' .. escape(search_term, '\'))
            
            # IncSearch highlights ONLY the current match to be replaced
            var specific_pattern = '\%' .. item.lnum .. 'l\%' .. (col + 1) .. 'c\V' .. escape(search_term, '\')
            var match_id2 = matchadd('IncSearch', specific_pattern, 11)
            
            redraw
            
            var prompt = "Replace (y/n/a/q/c"
            var valid_keys = ['y', 'n', 'a', 'q', 'c']
            if !empty(history)
                prompt ..= "/u"
                add(valid_keys, 'u')
            endif
            prompt ..= ")? "
            echo prompt
            
            while true
                choice = getcharstr()
                if index(valid_keys, choice) != -1
                    break
                endif
            endwhile
            
            # Remove highlight
            matchdelete(match_id)
            matchdelete(match_id2)

            redraw
        endif

        if choice == 'q'
            break # Break to show logs
        elseif choice == 'c'
            # Undo all changes
            if empty(history)
                echo "Cancelled. No changes made."
            else
                while !empty(history)
                    var state = remove(history, -1)
                    execute 'buffer ' .. state.bufnr
                    setline(state.lnum, state.old_line_content)
                    update
                endwhile
                echo "Cancelled. All changes undone."
            endif
            return
        elseif choice == 'a'
            replace_all = true
            choice = 'y'
        elseif choice == 'u' && !empty(history)
            var state = remove(history, -1)
            
            # Restore buffer content
            execute 'buffer ' .. state.bufnr
            setline(state.lnum, state.old_line_content)
            update
            
            # Restore iteration state
            i = state.i
            start_col = state.start_col
            
            # Remove logs
            if len(logs) > state.log_len
                remove(logs, state.log_len, -1)
            endif
            
            echo "Undone."
            continue
        endif

        if choice == 'y'
            # Save state BEFORE replacing
            add(history, {
                'i': i,
                'start_col': start_col,
                'bufnr': item.bufnr,
                'lnum': item.lnum,
                'old_line_content': line_content,
                'log_len': len(logs)
            })

            # Perform replacement
            var prefix = (col > 0) ? line_content[0 : col - 1] : ''
            var suffix = line_content[col + len(search_term) : ]
            var new_line = prefix .. replace_term .. suffix
            
            setline(item.lnum, new_line)
            update
            
            add(logs, "Replaced in " .. bufname(item.bufnr) .. ":" .. item.lnum)
            add(logs, "  Old: " .. line_content)
            add(logs, "  New: " .. new_line)
            
            # Advance start_col past the replacement
            start_col = col + len(replace_term)
        else
            # Skip this match (choice == 'n' or invalid input)
            start_col = col + len(search_term)
        endif
    endwhile
    
    redraw
    
    if empty(logs)
        echo "Search and replace completed. No changes made."
    else
        new
        setlocal buftype=nofile bufhidden=wipe noswapfile
        setline(1, logs)
        echo "Search and replace completed. Log opened."
    endif
enddef

def ParseArgs(input: string): list<string>
    var args = []
    var current_arg = ''
    var in_quote = false
    var quote_char = ''
    var i = 0
    var len = len(input)
    
    while i < len
        var char = input[i]
        
        if in_quote
            if quote_char == "'"
                if char == "'"
                    # Check for escaped quote (doubled quote char)
                    if i + 1 < len && input[i + 1] == "'"
                        current_arg ..= "'"
                        i += 1 # Skip the next quote char
                    else
                        in_quote = false
                    endif
                else
                    current_arg ..= char
                endif
            elseif quote_char == '"'
                if char == '\'
                    # Check for escaped char
                    if i + 1 < len
                        var next_char = input[i + 1]
                        if next_char == '"' || next_char == '\'
                            current_arg ..= next_char
                            i += 1
                        else
                            current_arg ..= char
                        endif
                    else
                        current_arg ..= char
                    endif
                elseif char == '"'
                    # Check for escaped quote (doubled quote char) - optional but good for consistency if user does ""
                    # But standard JSON/Vim double quotes use backslash.
                    # Let's stick to backslash for double quotes as requested.
                    in_quote = false
                else
                    current_arg ..= char
                endif
            endif
        else
            if char == '"' || char == "'"
                in_quote = true
                quote_char = char
            elseif char == ' '
                if !empty(current_arg)
                    add(args, current_arg)
                    current_arg = ''
                endif
                # If we already have 2 args (search and replace), the rest is the pattern
                if len(args) == 2
                    # Add the rest of the string as the pattern, trimming leading spaces
                    var rest = input[i + 1 : ]
                    # Trim leading spaces
                    rest = substitute(rest, '^\s*', '', '')
                    if !empty(rest)
                        add(args, rest)
                    endif
                    return args
                endif
            else
                current_arg ..= char
            endif
        endif
        
        i += 1
    endwhile
    
    if !empty(current_arg)
        add(args, current_arg)
    endif
    
    return args
enddef
