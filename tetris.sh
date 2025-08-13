#!/bin/bash

trap '' SIGUSR1 SIGUSR2

# Board
BOARD_WIDTH=10
BOARD_HEIGHT=20
SPAWN_BUFFER=2  # Invisible rows above the board for spawning
TOTAL_HEIGHT=$((BOARD_HEIGHT + SPAWN_BUFFER))

# Game state
GAMEOVER=0
TICK=0
SCORE=0
LEVEL=0
LINES_CLEARED=0
BAG=()
SEVEN_BAG_INDEX=0
ACTIVE_TETROMINO=""
NEXT_TETROMINO=""
DELAY=1
DELAY_FACTOR=0.8

# Tetromino state
TETROMINO_X=0
TETROMINO_Y=0
TETROMINO_ROTATION=0
LAST_X=-1
LAST_Y=-1
LAST_ROTATION=-1

# Held piece
HOLD_TETROMINO=""
HELD_THIS_TURN=0

# Toggles
SHOW_HELP=1
GHOST_PIECE=1
PAUSED=0
PIECES_MODE=0 # 0 - default, 1 - colors, 2 - classic

TETROMINOS=(
    "I"
    "O"
    "T"
    "S"
    "Z"
    "J"
    "L"
)

# Tetromino Colors
RED_BG="\033[41m"            # Z - Red background
GREEN_BG="\033[42m"          # S - Green background  
YELLOW_BG="\033[43m"         # O - Yellow background
BLUE_BG="\033[44m"           # J - Blue background
PURPLE_BG="\033[45m"         # T - Purple background
CYAN_BG="\033[46m"           # I - Cyan background
ORANGE_BG="\033[48;5;208m"   # L - Orange background
WHITE_BG="\033[47m"          # Default white background
GREEN_TEXT="\033[38;5;71m"   # Generic green text
RESET="\033[0m"

# Pipe Controls
ROTATE="w"
LEFT="a"
RIGHT="d"
DOWN="s"
HARD_DROP="o"
HOLD="c"
TOGGLE_GHOST="g"
TOGGLE_HELP="h"
PAUSE="p"
PIECE_STYLES="s"
QUIT="q"

declare -A TETROMINO_SHAPES

TETROMINO_SHAPES["I_0"]="........XXXX...."
TETROMINO_SHAPES["I_1"]="..X...X...X...X."
# . . . .   . . X .
# . . . .   . . X .
# X X X X   . . X .
# . . . .   . . X .

TETROMINO_SHAPES["O_0"]=".....XX..XX....."
# . . . .
# . X X .
# . X X .
# . . . .

TETROMINO_SHAPES["T_0"]="....XXX..X......"
TETROMINO_SHAPES["T_1"]=".X..XX...X......"
TETROMINO_SHAPES["T_2"]=".X..XXX........."
TETROMINO_SHAPES["T_3"]=".X...XX..X......"
# . . . .   . X . .   . X . .   . X . .
# X X X .   X X . .   X X X .   . X X .
# . X . .   . X . .   . . . .   . X . .
# . . . .   . . . .   . . . .   . . . .

TETROMINO_SHAPES["S_0"]=".XX.XX.........."
TETROMINO_SHAPES["S_1"]="X...XX...X......"
# . X X .   X . . .
# X X . .   X X . .
# . . . .   . X . .
# . . . .   . . . .

TETROMINO_SHAPES["Z_0"]="XX...XX........."
TETROMINO_SHAPES["Z_1"]="..X..XX..X......"
# X X . .   . . X .
# . X X .   . X X .
# . . . .   . X . .
# . . . .   . . . .

TETROMINO_SHAPES["J_0"]="....XXX...X....."
TETROMINO_SHAPES["J_1"]=".X...X..XX......"
TETROMINO_SHAPES["J_2"]="X...XXX........."
TETROMINO_SHAPES["J_3"]=".XX..X...X......"
# . . . .   . X . .   X . . .   . X X .
# X X X .   . X . .   X X X .   . X . .
# . . X .   X X . .   . . . .   . X . .
# . . . .   . . . .   . . . .   . . . .

TETROMINO_SHAPES["L_0"]="....XXX.X......."
TETROMINO_SHAPES["L_1"]="XX...X...X......"
TETROMINO_SHAPES["L_2"]="..X.XXX........."
TETROMINO_SHAPES["L_3"]=".X...X...XX....."
# . . . .   X X . .   . . X .   . X . .
# X X X .   . X . .   X X X .   . X . .
# X . . .   . X . .   . . . .   . X X .
# . . . .   . . . .   . . . .   . . . .

declare -a BOARD_STATE
for ((y = 0; y < TOTAL_HEIGHT; y++)); do
    for ((x = 0; x < BOARD_WIDTH; x++)); do
        BOARD_STATE[y * BOARD_WIDTH + x]=" ."
    done
done

# draw_piece <type> <origin_x> <origin_y> <target_x> <target_y> [char]
# Returns 0 and prints if it should draw something at (target_x, target_y)
draw_piece() {
    local tetro_type=$1
    local origin_x=$2
    local origin_y=$3
    local tx=$4
    local ty=$5
    local char=${6:-$tetro_type}
    local color=""

    if [[ "$PIECES_MODE" == "1" ]]; then
        case "$tetro_type" in
            "I") color="${CYAN_BG}" ;;
            "O") color="${YELLOW_BG}" ;;
            "T") color="${PURPLE_BG}" ;;
            "S") color="${GREEN_BG}" ;;
            "Z") color="${RED_BG}" ;;
            "J") color="${BLUE_BG}" ;;
            "L") color="${ORANGE_BG}" ;;
        esac
        char="${color}  ${RESET}"
    elif [[ "$PIECES_MODE" == "2" ]]; then
        char="${GREEN_TEXT}[]${RESET}"
    else
        char="${GREEN_TEXT}${tetro_type}${tetro_type}${RESET}"
    fi

    local shape="${TETROMINO_SHAPES[${ACTIVE_TETROMINO}_${TETROMINO_ROTATION}]}"

    for ((dy = 0; dy < 4; dy++)); do
        for ((dx = 0; dx < 4; dx++)); do
            local cell="${shape:$((dy * 4 + dx)):1}"
            if [[ "$cell" == "X" ]]; then
                local px=$((origin_x + dx))
                local py=$((origin_y + dy))

                if ((px == tx && py == ty)); then
                    echo -ne "$char"
                    return 0
                fi
            fi
        done
    done

    return 1
}

draw_board() {
    printf "\033[2;1H"

    local ghost_y=$TETROMINO_Y
    if ((GHOST_PIECE == 1)); then
        while can_place_at "$TETROMINO_X" "$((ghost_y + 1))"; do
            ((ghost_y++))
        done
    fi

    for ((y = SPAWN_BUFFER; y < TOTAL_HEIGHT; y++)); do
        printf "\033[%d;40H" $((y - SPAWN_BUFFER + 2))
        printf "${GREEN_TEXT}<!${RESET}"
        for ((x = 0; x < BOARD_WIDTH; x++)); do
            if draw_piece "$ACTIVE_TETROMINO" "$TETROMINO_X" "$TETROMINO_Y" "$x" "$y"; then
                continue
            fi
            
            if ((GHOST_PIECE == 1 && ghost_y != TETROMINO_Y)) && draw_ghost_at "$x" "$y" "$ghost_y"; then
                continue
            fi

            local index=$((y * BOARD_WIDTH + x))
            cell="${BOARD_STATE[$index]}"
            if [[ "$PIECES_MODE" == "1" && "$cell" != " ." ]]; then
                case "${cell:0:1}" in
                    "I") color="${CYAN_BG}" ;;
                    "O") color="${YELLOW_BG}" ;;
                    "T") color="${PURPLE_BG}" ;;
                    "S") color="${GREEN_BG}" ;;
                    "Z") color="${RED_BG}" ;;
                    "J") color="${BLUE_BG}" ;;
                    "L") color="${ORANGE_BG}" ;;
                    *) color="${WHITE_BG}" ;;
                esac
                printf "%b  %b" "$color" "$RESET"
            elif [[ "$PIECES_MODE" == "2" && "$cell" != " ." ]]; then
                printf "${GREEN_TEXT}[]${RESET}"
            elif [[ "$cell" != " ." ]]; then
                printf "${GREEN_TEXT}%s${RESET}" "$cell"
            else
                printf "${GREEN_TEXT}%s${RESET}" "$cell"
            fi
        done
        printf "${GREEN_TEXT}!>\n${RESET}"
    done

    printf "\033[%d;40H" $((TOTAL_HEIGHT - SPAWN_BUFFER + 2))
    printf "${GREEN_TEXT}<!====================!>\n${RESET}"
    printf "\033[%d;40H" $((TOTAL_HEIGHT - SPAWN_BUFFER + 3))
    printf "${GREEN_TEXT}  \\/\\/\\/\\/\\/\\/\\/\\/\\/\\/\n${RESET}"
}

draw_ghost_at() {
    local tx=$1
    local ty=$2
    local ghost_y=$3

    local shape="${TETROMINO_SHAPES[${ACTIVE_TETROMINO}_${TETROMINO_ROTATION}]}"

    for ((dy = 0; dy < 4; dy++)); do
        for ((dx = 0; dx < 4; dx++)); do
            local cell="${shape:$((dy * 4 + dx)):1}"
            if [[ "$cell" == "X" ]]; then
                local px=$((TETROMINO_X + dx))
                local py=$((ghost_y + dy))

                if ((px == tx && py == ty)); then
                    # Draw ghost piece based on current mode
                    printf "░░"
                    return 0
                fi
            fi
        done
    done

    return 1
}

get_rotation_count() {
    local tetro=$1
    local count=0
    for key in "${!TETROMINO_SHAPES[@]}"; do
        if [[ $key == "${tetro}_"* ]]; then
            ((count++))
        fi
    done
    echo $count
}

rotate() {
    local old_rotation=$TETROMINO_ROTATION
    local count=$(get_rotation_count "$ACTIVE_TETROMINO")
    TETROMINO_ROTATION=$(((TETROMINO_ROTATION + 1) % count))
    
    if ! can_place_at "$TETROMINO_X" "$TETROMINO_Y"; then
        TETROMINO_ROTATION=$old_rotation
    fi
}

# Generate a random sequence of tetrominoes that ensures
# each tetromino appears at least once before repeating
seven_bag_generate() {
    local pool=("${TETROMINOS[@]}")
    BAG=()

    while ((${#pool[@]} > 0)); do
        local idx=$((RANDOM % ${#pool[@]}))
        BAG+=("${pool[idx]}")
        unset 'pool[idx]'
        pool=("${pool[@]}")
    done
}

initialize_tetromino_system() {
    seven_bag_generate
    SEVEN_BAG_INDEX=0
    NEXT_TETROMINO="${BAG[0]}"
    SEVEN_BAG_INDEX=1
}

drop_tetromino() {
    if [[ -z $NEXT_TETROMINO ]]; then
        initialize_tetromino_system
    fi

    if [[ $SEVEN_BAG_INDEX -ge 7 ]]; then
        seven_bag_generate
        SEVEN_BAG_INDEX=0
    fi

    ACTIVE_TETROMINO="$NEXT_TETROMINO"
    NEXT_TETROMINO="${BAG[$SEVEN_BAG_INDEX]}"
    ((SEVEN_BAG_INDEX++))
    HELD_THIS_TURN=0

    local spawn_x=4
    local spawn_y=0

    # Check if spawn position is blocked
    for ((y = 0; y < SPAWN_BUFFER; y++)); do
        if [[ "${BOARD_STATE[$((y * BOARD_WIDTH + spawn_x))]}" != " ." ]]; then
            GAMEOVER=1
            return
        fi
    done

    TETROMINO_X=4
    TETROMINO_Y=0
    TETROMINO_ROTATION=0
}

lock_tetromino() {
    local shape="${TETROMINO_SHAPES[${ACTIVE_TETROMINO}_${TETROMINO_ROTATION}]}"
    local px py

    for ((dy = 0; dy < 4; dy++)); do
        for ((dx = 0; dx < 4; dx++)); do
            local index=$((dy * 4 + dx))
            local char="${shape:$index:1}"

            if [[ "$char" == "X" ]]; then
                px=$((TETROMINO_X + dx))
                py=$((TETROMINO_Y + dy))
                if ((px >= 0 && px < BOARD_WIDTH && py >= 0 && py < TOTAL_HEIGHT)); then
                    BOARD_STATE[$((py * BOARD_WIDTH + px))]="$ACTIVE_TETROMINO$ACTIVE_TETROMINO"
                fi
            fi
        done
    done

    can_clear_lines
}

draw_whole_tetromino() {
    local tetromino=$1
    local origin_x=$2
    local origin_y=$3

    local shape="${TETROMINO_SHAPES[${tetromino}_0]}"
    for ((dy = 0; dy < 4; dy++)); do
        printf "\033[%d;%dH" $((origin_y + dy + 1)) $((origin_x * 2 + 3))
        for ((dx = 0; dx < 4; dx++)); do
            local char="${shape:$((dy * 4 + dx)):1}"
            if [[ "$char" == "X" ]]; then
                if [[ "$PIECES_MODE" == "1" ]]; then
                    local color
                    case "$tetromino" in
                        "I") color="${CYAN_BG}" ;;
                        "O") color="${YELLOW_BG}" ;;
                        "T") color="${PURPLE_BG}" ;;
                        "S") color="${GREEN_BG}" ;;
                        "Z") color="${RED_BG}" ;;
                        "J") color="${BLUE_BG}" ;;
                        "L") color="${ORANGE_BG}" ;;
                        *) color="${WHITE_BG}" ;;
                    esac
                    printf "%b  %b" "$color" "$RESET"
                elif [[ "$PIECES_MODE" == "2" ]]; then
                    printf "${GREEN_TEXT}[]${RESET}"
                else
                    printf "${GREEN_TEXT}%s%s${RESET}" "$tetromino" "$tetromino"
                fi
            else
                printf "  "
            fi
        done
    done
}

can_place_at() {
    local test_x=$1
    local test_y=$2
    local shape="${TETROMINO_SHAPES[${ACTIVE_TETROMINO}_${TETROMINO_ROTATION}]}"

    for ((dy = 0; dy < 4; dy++)); do
        for ((dx = 0; dx < 4; dx++)); do
            local char="${shape:$((dy * 4 + dx)):1}"
            if [[ "$char" == "X" ]]; then
                local piece_x=$((test_x + dx))
                local piece_y=$((test_y + dy))

                if ((piece_x < 0 || piece_x >= BOARD_WIDTH || piece_y >= TOTAL_HEIGHT)); then
                    return 1
                fi

                if ((piece_y >= 0 && piece_y < TOTAL_HEIGHT)) && [[ "${BOARD_STATE[$((piece_y * BOARD_WIDTH + piece_x))]}" != " ." ]]; then
                    return 1
                fi
            fi
        done
    done
    return 0
}

can_move_down() {
    can_place_at "$TETROMINO_X" "$((TETROMINO_Y + 1))"
}

can_move_left() {
    can_place_at "$((TETROMINO_X - 1))" "$TETROMINO_Y"
}

can_move_right() {
    can_place_at "$((TETROMINO_X + 1))" "$TETROMINO_Y"
}

can_clear_lines() {
    local lines_to_clear=()

    for ((y = SPAWN_BUFFER; y < TOTAL_HEIGHT; y++)); do
        local full=1
        for ((x = 0; x < BOARD_WIDTH; x++)); do
            if [[ "${BOARD_STATE[y * BOARD_WIDTH + x]}" == " ." ]]; then
                full=0
                break
            fi
        done
        if ((full)); then
            lines_to_clear+=("$y")
        fi
    done

    for line in "${lines_to_clear[@]}"; do
        clear_line "$line"
    done
    
    update_score "${#lines_to_clear[@]}"

    return 0
}

clear_line() {
    local line=$1

    for ((y = line; y > 0; y--)); do
        for ((x = 0; x < BOARD_WIDTH; x++)); do
            BOARD_STATE[y * BOARD_WIDTH + x]=${BOARD_STATE[(y - 1) * BOARD_WIDTH + x]}
        done
    done

    for ((x = 0; x < BOARD_WIDTH; x++)); do
        BOARD_STATE[x]=" ."
    done
}

hold_piece() {
    if ((HELD_THIS_TURN == 1)); then
        return # Prevent holding again immediately after holding
    fi
    if [[ -z $HOLD_TETROMINO ]]; then
        HOLD_TETROMINO="$ACTIVE_TETROMINO"
        HELD_THIS_TURN=1
        drop_tetromino
    else
        local temp="$ACTIVE_TETROMINO"
        ACTIVE_TETROMINO="$HOLD_TETROMINO"
        HOLD_TETROMINO="$temp"
        TETROMINO_X=4
        TETROMINO_Y=0
        TETROMINO_ROTATION=0
        HELD_THIS_TURN=1

        # Check if the new active tetromino can be placed
        if ! can_place_at "$TETROMINO_X" "$TETROMINO_Y"; then
            GAMEOVER=1
            return
        fi
    fi
}

update_score() {
    cleared=$1

    if ((cleared == 1)); then
        SCORE=$((SCORE + 100))
    elif ((cleared == 2)); then
        SCORE=$((SCORE + 300))
    elif ((cleared == 3)); then
        SCORE=$((SCORE + 500))
    elif ((cleared >= 4)); then
        SCORE=$((SCORE + 800))
    fi

    LINES_CLEARED=$((LINES_CLEARED + cleared))
    local last_level=$LEVEL
    LEVEL=$((LINES_CLEARED / 10))
    if ((LEVEL > last_level)); then
        pkill -SIGUSR1 -f "/bin/bash $0"
    fi


    printf "\033[5;5H"
    local formatted_score
    formatted_score=$(printf "%'d" "$SCORE")
    printf "${GREEN_TEXT}Score: %s${RESET}\n" "$formatted_score"
    printf "\033[6;5H"
    printf "${GREEN_TEXT}Lines Cleared: %d${RESET}\n" "$LINES_CLEARED"
    printf "\033[7;5H"
    printf "${GREEN_TEXT}Level: %d${RESET}\n" "$LEVEL"
}

help() {
    local x=$1
    local y=$2
    local lines=(
        "       Controls        "
        "   a/d - left/right    "
        "     s - soft drop     "
        "      w - rotate       "
        "   space - hard drop   "
        "       q - quit        "
        " f - cycle piece styles"
        "   g - toggle ghost    "
        "     p - pause game    "
        "    h - toggle help    "
        "    c - hold piece     "
    )
    for i in "${!lines[@]}"; do
        printf "\033[%d;%dH${GREEN_TEXT}%s${RESET}\n" "$((y + i))" "$x" "${lines[$i]}"
    done
}

drop_tetromino

quit() {
    pkill -SIGUSR2 -f "/bin/bash $0" 2>/dev/null || true  # Kill gravity and controller
    GAMEOVER=1
    printf "\033[%d;1H" $((BOARD_HEIGHT + 5))
    printf "${GREEN_TEXT}Game Over!${RESET}\n"
    printf "\033[0m"
    printf "\033[?25h"
    exit 0
}

draw_frame() {
    printf "\n"
    draw_board
    printf "\033[5;28H${GREEN_TEXT}Next:${RESET}"
    draw_whole_tetromino "$NEXT_TETROMINO" 12 6
    printf "\033[12;28H"
    if [[ $HOLD_TETROMINO ]]; then
        printf "${GREEN_TEXT}Hold:${RESET}"
        draw_whole_tetromino "$HOLD_TETROMINO" 12 12
    fi

    LAST_X=$TETROMINO_X
    LAST_Y=$TETROMINO_Y
    LAST_ROTATION=$TETROMINO_ROTATION
}

move_left() {
    if can_move_left; then
        ((TETROMINO_X--))
    fi
}

move_right() {
    if can_move_right; then
        ((TETROMINO_X++))
    fi
}

move_down() {
    if can_move_down; then
        ((TETROMINO_Y++))
        SCORE=$((SCORE + 1))
    else
        lock_tetromino
        drop_tetromino
        if [[ $GAMEOVER -eq 1 ]]; then
            quit
        fi
    fi
}

hard_drop() {
    while can_move_down; do
        ((TETROMINO_Y++))
        ((SCORE+=2))
    done
    lock_tetromino
    drop_tetromino
}

change_pieces_style() {
    PIECES_MODE=$(((PIECES_MODE + 1) % 3))
    printf "\033[0m"
}

toggle_ghost() {
    if [[ $GHOST_PIECE -eq 1 ]]; then
        GHOST_PIECE=0
    else
        GHOST_PIECE=1
    fi
}

toggle_help() {
    if [[ $SHOW_HELP -eq 1 ]]; then
        SHOW_HELP=0
        for ((i = 0; i < 14; i++)); do
            printf "\033[%d;70H%24s" $((6 + i)) ""
        done
    else
        SHOW_HELP=1
        help 70 6
    fi
}

toggle_pause() {
    if [[ $PAUSED -eq 1 ]]; then
        PAUSED=0
    else
        PAUSED=1
        printf "\033[10;47H${GREEN_TEXT}Game Paused${RESET}\n"
    fi
}

# Thanks to this anonymous github gist for teaching me about signals and piping
# https://gist.github.com/anonymous/dac9b4db7b843e4b1e519ce1d1dbe28c

gravity() {
    trap exit SIGUSR2
    trap 'DELAY=$(awk "BEGIN {print $DELAY * $DELAY_FACTOR}")' SIGUSR1

    while true; do 
        echo -n $DOWN
        sleep $DELAY
    done
}

controller() {
    trap exit SIGUSR2
    trap '' SIGUSR1
    local key a='' b='' cmd esc_ch=$'\x1b'

    while read -s -n 1 key; do
        case "$a$b$key" in
            "${esc_ch}["[ACD]) 
                case "$key" in
                    "A") cmd=$ROTATE ;;
                    "B") cmd=$DOWN ;;
                    "C") cmd=$RIGHT ;;
                    "D") cmd=$LEFT ;;
                esac
                ;;
            *${esc_ch}${esc_ch}) cmd=$QUIT ;;
            *)
                if [[ "$a" != "$esc_ch" ]] || [[ "$b" != "[" ]]; then
                    case "$key" in
                        "w") cmd=$ROTATE ;;
                        "s") cmd=$DOWN ;;
                        "a") cmd=$LEFT ;;
                        "d") cmd=$RIGHT ;;
                        "") cmd=$HARD_DROP ;;
                        "q") cmd=$QUIT ;;
                        "h") cmd=$TOGGLE_HELP ;;
                        "g") cmd=$TOGGLE_GHOST ;;
                        "p") cmd=$PAUSE ;;
                        "f") cmd=$PIECE_STYLES ;;
                        "c") cmd=$HOLD ;;
                        *) cmd="" ;;
                    esac
                else
                    cmd=""
                fi
                ;;
        esac
        
        a=$b
        b=$key
        
        [[ -n "$cmd" ]] && echo -n "$cmd"
        cmd=""
    done
}

main() {
    trap '' SIGUSR1 SIGUSR2
    local cmd

    clear
    printf "\033[?25l" # Hide cursor
    initialize_tetromino_system
    drop_tetromino
    draw_frame
    
    while [[ $GAMEOVER -eq 0 ]]; do
        read -s -n 1 cmd
        
        if [[ $PAUSED -eq 1 && $cmd != "$PAUSE" && $cmd != "$QUIT" ]]; then
            printf "\033[10;47H${GREEN_TEXT}Game Paused${RESET}"
            continue
        fi
        
        case "$cmd" in
            "$QUIT") quit ;; 
            "$RIGHT") move_right ;;
            "$LEFT") move_left ;;
            "$ROTATE") rotate ;;
            "$DOWN") move_down ;;
            "$HARD_DROP") hard_drop ;;
            "$HOLD") hold_piece ;;
            "$TOGGLE_GHOST") toggle_ghost ;;
            "$TOGGLE_HELP") toggle_help ;;
            "$PAUSE") 
                toggle_pause
                if [[ $PAUSED -eq 1 ]]; then
                    printf "\033[10;47H${GREEN_TEXT}Game Paused${RESET}"
                else
                    printf "\033[10;47H%20s" ""
                fi
                ;;
            "$PIECE_STYLES") change_pieces_style ;;
        esac

        # Only redraw if something changed and not paused
        if [[ $PAUSED -eq 0 && ( $TETROMINO_X != "$LAST_X" || $TETROMINO_Y != "$LAST_Y" || $TETROMINO_ROTATION != "$LAST_ROTATION" ) ]]; then
            draw_frame
        fi
    done
}

stty_saved=$(stty -g)
stty -echo -icanon time 0 min 0

trap 'stty "$stty_saved"; printf "\033[?25h"; clear; exit' INT TERM

# Initial screen setup
clear
printf "\033[8;30;100t"

(
    gravity &
    controller
) | main

# Cleanup
printf "\033[?25h"
stty "$stty_saved"
