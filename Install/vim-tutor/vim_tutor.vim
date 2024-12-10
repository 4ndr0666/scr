" Vim Tutor - Interactive Guide

function! VimTutor()
    " Create a new buffer with tutorial content
    enew
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nowrap
    setlocal modifiable
    setlocal readonly
    setlocal nomodifiable
    setlocal nonumber
    setlocal norelativenumber
    setlocal nospell

    " Insert tutorial content
    call setline(1, [
    \ '############ Welcome to the Vim Tutor ############',
    \ '',
    \ 'Follow the instructions below to learn basic Vim commands.',
    \ '',
    \ '###############################################################################',
    \ '1. NAVIGATING WITH VIM',
    \ '-------------------------------------------------------------------------------',
    \ 'Use "H", "J", "K", and "L" to move the cursor:',
    \ '  - H: move left',
    \ '  - J: move down',
    \ '  - K: move up',
    \ '  - L: move right',
    \ 'Practice moving the cursor now!',
    \ '',
    \ 'Once you are done, press "J" to move to the next section.',
    \ '',
    \ '###############################################################################',
    \ '2. QUITTING VIM',
    \ '-------------------------------------------------------------------------------',
    \ 'To quit Vim:',
    \ '  - Type ":q!" to quit without saving.',
    \ '  - Type "ZZ" to save and quit.',
    \ '',
    \ 'Try quitting Vim now! Or scroll down to the next section using "J".',
    \ '',
    \ '###############################################################################',
    \ '3. EDITING TEXT',
    \ '-------------------------------------------------------------------------------',
    \ '  - "i": Insert before the cursor.',
    \ '  - "A": Append to the end of the line.',
    \ '  - "dw": Delete a word.',
    \ '  - "d$": Delete from the cursor to the end of the line.',
    \ '',
    \ 'Try inserting, appending, and deleting text now!',
    \ '',
    \ '###############################################################################',
    \ '4. UNDO AND REDO',
    \ '-------------------------------------------------------------------------------',
    \ '  - "u": Undo the last change.',
    \ '  - "Ctrl + R": Redo the change you just undid.',
    \ '',
    \ 'Make some edits, then try undoing and redoing them!',
    \ '',
    \ '###############################################################################',
    \ '5. VISUAL MODE',
    \ '-------------------------------------------------------------------------------',
    \ '  - "v": Enter visual mode to select text by character.',
    \ '  - "V": Select entire lines in visual mode.',
    \ '  - "Ctrl + V": Select a block (column mode).',
    \ '',
    \ 'Practice visual mode selections and manipulating text!',
    \ '',
    \ '###############################################################################',
    \ '6. YANKING AND PASTING',
    \ '-------------------------------------------------------------------------------',
    \ '  - "yy": Yank (copy) a line.',
    \ '  - "yw": Yank a word.',
    \ '  - "p": Paste the yanked text after the cursor.',
    \ '',
    \ 'Try yanking and pasting text now!',
    \ '',
    \ '###############################################################################',
    \ '7. SEARCHING FOR TEXT',
    \ '-------------------------------------------------------------------------------',
    \ '  - "/<search_term>": Search for a word or phrase.',
    \ '  - "n": Jump to the next match.',
    \ '  - "N": Jump to the previous match.',
    \ '',
    \ 'Try searching for the word "Vim" in this document!',
    \ '',
    \ '###############################################################################',
    \ '8. REPLACING TEXT',
    \ '-------------------------------------------------------------------------------',
    \ '  - "R": Replace characters one by one.',
    \ '  - "cw": Change a word and start typing a new one.',
    \ '',
    \ 'Practice replacing words in this section!',
    \ '',
    \ '############### End of Vim Tutor ###############',
    \ ''])

    " Make the buffer readonly so it doesn't get accidentally changed
    setlocal nomodifiable
endfunction

" Key mapping to easily invoke the Vim tutor
command! VimTutor call VimTutor()
