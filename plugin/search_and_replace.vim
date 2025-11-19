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

    # 3. Ask for every quickfix in the list
    # We iterate by index to potentially modify the list or track progress if needed,
    # but mostly we just need the item.
    for i in range(len(qflist))
        var item = qflist[i]
        if item.valid == 0
            continue
        endif

        # Load buffer if not loaded
        if !bufexists(item.bufnr)
            # This shouldn't happen often if grep found it, but good to be safe
            continue
        endif
        
        # Switch to the buffer and line
        execute 'buffer ' .. item.bufnr
        cursor(item.lnum, 1)
        
        var line_content = getline(item.lnum)
        var start_col = 0
        
        while true
            var col = stridx(line_content, search_term, start_col)
            if col == -1
                break
            endif
            
            cursor(item.lnum, col + 1)
            
            redraw
            # echo "Match found in " .. bufname(item.bufnr) .. ":" .. item.lnum
            # echo line_content

            var choice = ''
            if replace_all
                choice = 'y'
            else
                echo "Match found in " .. bufname(item.bufnr) .. ":" .. item.lnum
                echo line_content
                
                # Highlight the search term
                # IncSearch highlights all matches (like /)
                var match_id = matchadd('IncSearch', '\V' .. escape(search_term, '\'))
                
                # SRMatch highlights ONLY the current match to be replaced (bold, underline + IncSearch colors)
                # Use \%l and \%c to match specific line and column
                # Note: col is 0-indexed byte index, \%c expects 1-indexed column
                var specific_pattern = '\%' .. item.lnum .. 'l\%' .. (col + 1) .. 'c\V' .. escape(search_term, '\')
                var match_id2 = matchadd('SRMatch', specific_pattern, 11)
                
                redraw
                
                echo "Replace (y/n/a/q)? "
                choice = getcharstr()
                redraw
                
                # Remove highlight
                matchdelete(match_id)
                matchdelete(match_id2)
            endif

            if choice == 'q'
                return
            elseif choice == 'a'
                replace_all = true
                choice = 'y'
            endif

            if choice == 'y'
                # Perform replacement
                # We replace only the occurrence at 'col'
                # line_content[0 : col - 1] is before match
                # line_content[col + len(search_term) : ] is after match
                var prefix = (col > 0) ? line_content[0 : col - 1] : ''
                var suffix = line_content[col + len(search_term) : ]
                var new_line = prefix .. replace_term .. suffix
                
                setline(item.lnum, new_line)
                
                # Mark buffer as modified (setline does this)
                update
                
                add(logs, "Replaced in " .. bufname(item.bufnr) .. ":" .. item.lnum)
                add(logs, "  Old: " .. line_content)
                add(logs, "  New: " .. new_line)
                
                # Update line_content for next iteration
                line_content = new_line
                # Advance start_col past the replacement to avoid infinite loop if recursive
                start_col = col + len(replace_term)
            else
                # Skip this match
                start_col = col + len(search_term)
            endif
        endwhile
    endfor
    
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
