#!/bin/bash

# This script (webappman) is a webapp builder.
# It can be run in a terminal or with dmenu.

# --- IMPORTANT ---
# This script should be placed in ~/.local/bin to work correctly.
# For dmenu mode, ensure 'dmenu' and 'libnotify' (for notify-send) are installed.
#
# 1. Move this script:
#    mv webappman ~/.local/bin/
#
# 2. Add the webapps directory to your shell's PATH.
#    For fish shell, add this to ~/.config/fish/config.fish:
#    set -p PATH "$HOME/.local/bin/webapps" $PATH
#
# 3. Restart your shell or source the config file.
#    source ~/.config/fish/config.fish
# ---

# Set the directory for webapp scripts and create it if it doesn't exist.
WEBAPPS_DIR="$HOME/.local/bin/webapps"
mkdir -p "$WEBAPPS_DIR"

#######################################
# TERMINAL MODE FUNCTIONS
#######################################

create_new_webapp_terminal() {
    read -p "Enter the URL for the webapp: " url
    read -p "Enter the name for the webapp (e.g., 'gmail'): " app_name

    if [ -z "$url" ] || [ -z "$app_name" ]; then
        echo "URL and App name cannot be empty."
        return
    fi

    local SCRIPT_PATH="$WEBAPPS_DIR/$app_name"
    if [ -f "$SCRIPT_PATH" ]; then
        echo "A webapp with the name '$app_name' already exists."
        return
    fi

    echo "#!/bin/bash" > "$SCRIPT_PATH"
    echo "brave-browser-stable --app=\"$url\"" >> "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    echo "Webapp '$app_name' created successfully at $SCRIPT_PATH"
}

edit_existing_webapp_terminal() {
    if [ ! -d "$WEBAPPS_DIR" ] || [ -z "$(ls -A "$WEBAPPS_DIR")" ]; then
        echo "No webapps found in $WEBAPPS_DIR"
        return
    fi

    mapfile -t webapp_files < <(find "$WEBAPPS_DIR" -maxdepth 1 -type f)
    if [ ${#webapp_files[@]} -eq 0 ]; then echo "No webapps found."; return; fi

    PS3="Select a webapp to edit: "
    select webapp_path in "${webapp_files[@]}"; do
        if [ -n "$webapp_path" ]; then
            local current_name=$(basename "$webapp_path")
            local current_url=$(grep -oP '(?<=--app=")[^"]*' "$webapp_path")

            echo "Editing: $current_name"
            echo "Current URL: $current_url"

            read -p "Enter new URL (or press Enter to keep current): " new_url
            read -p "Enter new name (or press Enter to keep '$current_name'): " new_name
            [ -z "$new_url" ] && new_url=$current_url
            [ -z "$new_name" ] && new_name=$current_name

            if [ "$new_name" == "$current_name" ]; then
                echo "#!/bin/bash" > "$webapp_path"
                echo "brave-browser-stable --app=\"$new_url\"" >> "$webapp_path"
                chmod +x "$webapp_path"
                echo "Webapp '$current_name' updated."
            else
                local new_path="$WEBAPPS_DIR/$new_name"
                if [ -f "$new_path" ]; then echo "Error: A webapp named '$new_name' already exists."; break; fi
                echo "#!/bin/bash" > "$new_path"
                echo "brave-browser-stable --app=\"$new_url\"" >> "$new_path"
                chmod +x "$new_path"
                rm "$webapp_path"
                echo "Webapp renamed to '$new_name' and updated."
            fi
            break
        else
            echo "Invalid selection."
            break
        fi
    done
}

delete_existing_webapp_terminal() {
    if [ ! -d "$WEBAPPS_DIR" ] || [ -z "$(ls -A "$WEBAPPS_DIR")" ]; then
        echo "No webapps found in $WEBAPPS_DIR"
        return
    fi

    mapfile -t webapp_files < <(find "$WEBAPPS_DIR" -maxdepth 1 -type f)
    if [ ${#webapp_files[@]} -eq 0 ]; then echo "No webapps found."; return; fi

    PS3="Select a webapp to delete: "
    select webapp_path in "${webapp_files[@]}"; do
        if [ -n "$webapp_path" ]; then
            local webapp_name=$(basename "$webapp_path")
            read -p "Are you sure you want to delete '$webapp_name'? (y/n): " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                rm "$webapp_path"
                echo "Webapp '$webapp_name' deleted."
            else
                echo "Deletion cancelled."
            fi
            break
        else
            echo "Invalid selection."
            break
        fi
    done
}

main_terminal() {
    echo "Webapp Builder"
    echo "--------------"
    PS3="Please enter your choice: "
    local options=("Create new webapp" "Edit existing webapp" "Delete existing webapp" "Quit")
    select opt in "${options[@]}"; do
        case $opt in
            "Create new webapp") create_new_webapp_terminal ;;
            "Edit existing webapp") edit_existing_webapp_terminal ;;
            "Delete existing webapp") delete_existing_webapp_terminal ;;
            "Quit") break ;;
            *) echo "invalid option $REPLY" ;;
        esac
    done
    echo "Done."
}

#######################################
# DMENU MODE FUNCTIONS
#######################################

create_new_webapp_dmenu() {
    local url=$(dmenu -p "Enter URL:" < /dev/null)
    [ -z "$url" ] && exit 1

    local app_name=$(dmenu -p "Enter App Name:" < /dev/null)
    [ -z "$app_name" ] && exit 1

    local SCRIPT_PATH="$WEBAPPS_DIR/$app_name"
    if [ -f "$SCRIPT_PATH" ]; then
        notify-send "Webapp Builder Error" "A webapp named '$app_name' already exists."
        return
    fi

    echo "#!/bin/bash" > "$SCRIPT_PATH"
    echo "brave-browser-stable --app=\"$url\"" >> "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    notify-send "Webapp Builder" "Webapp '$app_name' created."
}

edit_existing_webapp_dmenu() {
    if [ ! -d "$WEBAPPS_DIR" ] || [ -z "$(ls -A "$WEBAPPS_DIR")" ]; then
        notify-send "Webapp Builder" "No webapps found to edit."
        return
    fi

    mapfile -t webapp_files < <(find "$WEBAPPS_DIR" -maxdepth 1 -type f)
    if [ ${#webapp_files[@]} -eq 0 ]; then notify-send "Webapp Builder" "No webapps found."; return; fi
    
    local webapp_names=()
    for file in "${webapp_files[@]}"; do webapp_names+=("$(basename "$file")"); done

    local selected_app=$(printf "%s\n" "${webapp_names[@]}" | dmenu -p "Select webapp to edit")
    [ -z "$selected_app" ] && exit 1

    local webapp_path="$WEBAPPS_DIR/$selected_app"
    local current_url=$(grep -oP '(?<=--app=")[^"]*' "$webapp_path")

    local new_url=$(dmenu -p "New URL (current: $current_url)" < /dev/null)
    [ -z "$new_url" ] && new_url=$current_url

    local new_name=$(dmenu -p "New Name (current: $selected_app)" < /dev/null)
    [ -z "$new_name" ] && new_name=$selected_app

    if [ "$new_name" == "$selected_app" ]; then
        echo "#!/bin/bash" > "$webapp_path"
        echo "brave-browser-stable --app=\"$new_url\"" >> "$webapp_path"
        chmod +x "$webapp_path"
        notify-send "Webapp Builder" "Webapp '$selected_app' updated."
    else
        local new_path="$WEBAPPS_DIR/$new_name"
        if [ -f "$new_path" ]; then
            notify-send "Webapp Builder Error" "A webapp named '$new_name' already exists."
            return
        fi
        echo "#!/bin/bash" > "$new_path"
        echo "brave-browser-stable --app=\"$new_url\"" >> "$new_path"
        chmod +x "$new_path"
        rm "$webapp_path"
        notify-send "Webapp Builder" "Webapp renamed to '$new_name' and updated."
    fi
}

delete_existing_webapp_dmenu() {
    if [ ! -d "$WEBAPPS_DIR" ] || [ -z "$(ls -A "$WEBAPPS_DIR")" ]; then
        notify-send "Webapp Builder" "No webapps found to delete."
        return
    fi

    mapfile -t webapp_files < <(find "$WEBAPPS_DIR" -maxdepth 1 -type f)
    if [ ${#webapp_files[@]} -eq 0 ]; then notify-send "Webapp Builder" "No webapps found."; return; fi

    local webapp_names=()
    for file in "${webapp_files[@]}"; do webapp_names+=("$(basename "$file")"); done

    local selected_app=$(printf "%s\n" "${webapp_names[@]}" | dmenu -p "Select webapp to delete")
    [ -z "$selected_app" ] && exit 1

    local confirm=$(echo -e "No\nYes" | dmenu -p "Delete '$selected_app'?")
    if [ "$confirm" == "Yes" ]; then
        rm "$WEBAPPS_DIR/$selected_app"
        notify-send "Webapp Builder" "Webapp '$selected_app' deleted."
    else
        notify-send "Webapp Builder" "Deletion cancelled."
    fi
}

main_dmenu() {
    if ! command -v dmenu &> /dev/null || ! command -v notify-send &> /dev/null; then
        # Fallback to terminal if dmenu/notify-send are not found
        main_terminal
        exit 1
    fi

    local choice=$(echo -e "Create new webapp\nEdit existing webapp\nDelete existing webapp\nQuit" | dmenu -p "Webapp Builder")

    case "$choice" in
        "Create new webapp") create_new_webapp_dmenu ;;
        "Edit existing webapp") edit_existing_webapp_dmenu ;;
        "Delete existing webapp") delete_existing_webapp_dmenu ;;
        "Quit") exit 0 ;;
        *) exit 0 ;; # Exit if user escapes dmenu
    esac
}

#######################################
# SCRIPT ENTRYPOINT
#######################################

if [ "$1" == "--cli" ]; then
    main_terminal
else
    main_dmenu
fi
