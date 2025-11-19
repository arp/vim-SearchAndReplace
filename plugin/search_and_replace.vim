vim9script

# SearchAndReplace Plugin
# Usage: :SR 'search_term' 'replace_term' [pattern]

command! -nargs=+ -complete=file SR SearchAndReplace(<f-args>)

def SearchAndReplace(...args: list<string>)
    if len(args) < 2
        echoerr "Usage: :SR 'search_term' 'replace_term' [pattern]"
        return
    endif

    var search_term = args[0]
    var replace_term = args[1]
    var pattern = "**/*"

    if len(args) >= 3
        pattern = join(args[2 : ], ' ')
    endif

    # Debug output to help diagnose issues
    echo "Search Term: " .. search_term
    echo "Replace Term: " .. replace_term
    echo "Pattern: " .. pattern
    
    var grep_cmd = 'grep! -F ' .. shellescape(search_term) .. ' ' .. pattern
    # echo "Executing: " .. grep_cmd

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
    # Create the combined highlight group
    CreateCombinedHighlight('IncSearch', 'SRMatch')
    
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
            
            # SRMatch highlights ONLY the current match to be replaced (bold, underline + IncSearch colors)
            var specific_pattern = '\%' .. item.lnum .. 'l\%' .. (col + 1) .. 'c\V' .. escape(search_term, '\')
            var match_id2 = matchadd('SRMatch', specific_pattern, 11)
            
            redraw
            
            var prompt = "Replace (y/n/a/q"
            var valid_keys = ['y', 'n', 'a', 'q']
            if !empty(history)
                prompt ..= "/u/c"
                add(valid_keys, 'u')
                add(valid_keys, 'c')
            endif
            prompt ..= ")? "
            echo prompt
            
            while true
                choice = getcharstr()
                if index(valid_keys, choice) != -1
                    break
                endif
            endwhile
            redraw
            
            # Remove highlight
            matchdelete(match_id)
            matchdelete(match_id2)
        endif

        if choice == 'q'
            if !empty(logs)
                break # Break to show logs
            else
                return
            endif
        elseif choice == 'c'
            # Undo all changes
            while !empty(history)
                var state = remove(history, -1)
                execute 'buffer ' .. state.bufnr
                setline(state.lnum, state.old_line_content)
                update
            endwhile
            echo "Cancelled. All changes undone."
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
    
    if !empty(logs)
        new
        setlocal buftype=nofile bufhidden=wipe noswapfile
        setline(1, logs)
        echo "Search and replace completed. Log opened."
    else
        echo "\nSearch and replace completed. No changes made."
    endif
enddef

def CreateCombinedHighlight(base: string, new_group: string)
    var id = synIDtrans(hlID(base))
    var gui_attrs = []
    var cterm_attrs = []
    for attr in ['bold', 'italic', 'reverse', 'inverse', 'underline', 'undercurl', 'standout']
        if synIDattr(id, attr, 'gui') == '1'
            add(gui_attrs, attr)
        endif
        if synIDattr(id, attr, 'cterm') == '1'
            add(cterm_attrs, attr)
        endif
    endfor
    
    # Add desired attributes
    if index(gui_attrs, 'bold') == -1 | add(gui_attrs, 'bold') | endif
    if index(gui_attrs, 'underline') == -1 | add(gui_attrs, 'underline') | endif
    if index(cterm_attrs, 'bold') == -1 | add(cterm_attrs, 'bold') | endif
    if index(cterm_attrs, 'underline') == -1 | add(cterm_attrs, 'underline') | endif
    
    var cmd = 'highlight ' .. new_group
    if !empty(gui_attrs)
        cmd ..= ' gui=' .. join(gui_attrs, ',')
    endif
    if !empty(cterm_attrs)
        cmd ..= ' cterm=' .. join(cterm_attrs, ',')
    endif
    
    var guifg = synIDattr(id, 'fg', 'gui')
    if !empty(guifg) | cmd ..= ' guifg=' .. guifg | endif
    var guibg = synIDattr(id, 'bg', 'gui')
    if !empty(guibg) | cmd ..= ' guibg=' .. guibg | endif
    var ctermfg = synIDattr(id, 'fg', 'cterm')
    if !empty(ctermfg) | cmd ..= ' ctermfg=' .. ctermfg | endif
    var ctermbg = synIDattr(id, 'bg', 'cterm')
    if !empty(ctermbg) | cmd ..= ' ctermbg=' .. ctermbg | endif
    
    execute cmd
enddef
