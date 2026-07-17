#!/usr/bin/env fish
#
# Interactive installer for LyricWidget (Fish Shell)
# Supports: install, upgrade, and remove
#
# Usage:
#   ./bin/install.fish           (run from within the repo clone)
#   fish <(curl -fsSL ...)       (run directly from GitHub)

# ─── Constants ───────────────────────────────────────────────────────────────

set -l REPO_URL "https://github.com/codesftdev/lyricwidget.git"
set -l PACKAGE_ID "lyricwidget"
set -l PACKAGE_TYPE "Plasma/Applet"
set -l DEFAULT_CLONE_DIR "/tmp/lyricwidget-install"
set -l INSTALLED_DIR "$HOME/.local/share/plasma/plasmoids/$PACKAGE_ID"

# ─── Helpers ─────────────────────────────────────────────────────────────────

function die
    set_color red
    echo "❌ $argv" >&2
    set_color normal
    exit 1
end

function warn
    set_color yellow
    echo "⚠️  $argv" >&2
    set_color normal
end

function info
    set_color blue
    echo "ℹ️  $argv"
    set_color normal
end

function success
    set_color green
    echo "✅ $argv"
    set_color normal
end

function get_version_from_json
    set -l file $argv[1]
    if test -f "$file"
        grep '"Version"' "$file" 2>/dev/null | sed 's/.*"Version": "\([^"]*\)".*/\1/'
    else
        echo "unknown"
    end
end

# ─── Phase 1: Dependency Check ─────────────────────────────────────────────

function check_deps
    if not command -v kpackagetool6 >/dev/null 2>&1
        die "kpackagetool6 not found. Please install KDE Plasma 6 (plasma-sdk or plasma-workspace package)."
    end

    if not command -v git >/dev/null 2>&1
        die "git not found. Please install git."
    end

    if not command -v msgfmt >/dev/null 2>&1
        warn "msgfmt not found (gettext package). Translations will not be compiled."
        return 1
    end
    return 0
end

# ─── Phase 2: Determine Source Location ──────────────────────────────────────

function get_source_dir
    set -l script_dir (cd (dirname (status -f)) && pwd)

    # Check if we're running from inside the repo
    if test -f "$script_dir/../src/metadata.json"
        set -g SOURCE_DIR (cd "$script_dir/.." && pwd)/src
        set -g SKIP_CLONE 1
        info "Detected existing repo clone — using local source."
        return
    end

    set -g SKIP_CLONE 0

    read -P "Where should the repo be cloned? [$DEFAULT_CLONE_DIR]: " clone_dir < /dev/tty
    if test -z "$clone_dir"
        set clone_dir $DEFAULT_CLONE_DIR
    end

    # Handle existing directory
    if test -d "$clone_dir/.git"
        read -P "Directory exists and is a git repo. [R]e-clone, [P]ull, or [U]se as-is? [U]: " choice < /dev/tty
        if test -z "$choice"
            set choice U
        end
        switch (string upper "$choice")
            case R
                rm -rf "$clone_dir"
            case P
                cd "$clone_dir"
                and git pull
                or warn "git pull failed, continuing with local copy."
            case '*'
                # Use as-is
        end
    else if test -d "$clone_dir"
        set files (ls -A "$clone_dir" 2>/dev/null)
        if test (count $files) -gt 0
            die "Directory $clone_dir exists and is not empty. Please choose a different location."
        end
    end

    # Clone if needed
    if not test -d "$clone_dir/.git"
        info "Cloning $REPO_URL to $clone_dir..."
        git clone "$REPO_URL" "$clone_dir"
        or die "Clone failed. Check your network connection."
    end

    set -g SOURCE_DIR "$clone_dir/src"
end

# ─── Phase 3: Compile Translations ───────────────────────────────────────────

function compile_translations
    set -l i18n_script (cd "$SOURCE_DIR/.." && pwd)/bin/i18n

    if not test -f "$i18n_script"
        warn "i18n script not found. Translations will not be compiled."
        return
    end

    info "Compiling translations..."
    if bash "$i18n_script" compile
        success "Translations compiled."
    else
        warn "Translation compilation failed, but continuing..."
    end
end

# ─── Phase 4: Install / Upgrade / Remove ─────────────────────────────────────

function is_installed
    test -d "$INSTALLED_DIR"
end

function get_installed_version
    get_version_from_json "$INSTALLED_DIR/metadata.json"
end

function get_source_version
    get_version_from_json "$SOURCE_DIR/metadata.json"
end

function do_install
    if is_installed
        info "LyricWidget is already installed (version "(get_installed_version)")."
        read -P "Would you like to upgrade instead? [Y/n]: " choice < /dev/tty
        if test -z "$choice"; or string match -q -r '^[Yy]' "$choice"
            do_upgrade
        else
            info "Skipping install."
        end
        return
    end

    info "Installing LyricWidget..."
    if kpackagetool6 -i "$SOURCE_DIR" --type "$PACKAGE_TYPE"
        success "LyricWidget installed successfully!"
        ask_restart_after_change "install"
    else
        die "Installation failed."
    end
end

function do_upgrade
    if not is_installed
        info "LyricWidget is not currently installed."
        read -P "Would you like to install it instead? [Y/n]: " choice < /dev/tty
        if test -z "$choice"; or string match -q -r '^[Yy]' "$choice"
            do_install
        else
            info "Skipping upgrade."
        end
        return
    end

    info "Upgrading LyricWidget..."
    if kpackagetool6 -u "$SOURCE_DIR" --type "$PACKAGE_TYPE"
        success "LyricWidget upgraded successfully!"
        ask_restart_after_change "upgrade"
    else
        die "Upgrade failed."
    end
end

function do_remove
    if not is_installed
        warn "LyricWidget is not currently installed."
        return
    end

    read -P "Are you sure you want to remove LyricWidget? [y/N]: " choice < /dev/tty
    if string match -q -r '^[Yy]' "$choice"
        info "Removing LyricWidget..."
        if kpackagetool6 -r "$PACKAGE_ID" --type "$PACKAGE_TYPE"
            success "LyricWidget removed successfully!"
        else
            die "Removal failed."
        end
    else
        info "Skipping removal."
    end
end

function do_restart_plasma
    if not command -v plasmashell >/dev/null 2>&1
        die "plasmashell not found. Cannot restart Plasma."
    end

    read -P "This will briefly restart your Plasma desktop. Continue? [Y/n]: " choice < /dev/tty
    if test -z "$choice"; or string match -q -r '^[Yy]' "$choice"
        info "Restarting KDE Plasma..."
        plasmashell --replace &
        success "Plasma restarted."
    else
        info "Skipping restart."
    end
end

function ask_restart_after_change
    set -l action $argv[1]
    read -P "Restart KDE Plasma to apply $action changes? [Y/n]: " choice < /dev/tty
    if test -z "$choice"; or string match -q -r '^[Yy]' "$choice"
        do_restart_plasma
    end
end

# ─── Phase 5: Cleanup ────────────────────────────────────────────────────────

function cleanup
    if test "$SKIP_CLONE" -eq 1
        return
    end

    set -l clone_dir (cd "$SOURCE_DIR/.." && pwd)

    read -P "Delete the cloned repo at $clone_dir? [y/N]: " choice < /dev/tty
    if string match -q -r '^[Yy]' "$choice"
        rm -rf "$clone_dir"
        success "Clone directory removed."
    end
end

# ─── Phase 6: Menu ───────────────────────────────────────────────────────────

function show_menu
    set -l src_ver (get_source_version)
    set -l installed_ver (get_installed_version)
    set -l status_line

    if is_installed
        set status_line "Installed: v$installed_ver"
    else
        set status_line "Status:  Not installed"
    end

    echo ""
    set_color blue
    echo "╔══════════════════════════════╗"
    echo "║      LyricWidget Setup       ║"
    echo "╠══════════════════════════════╣"
    printf  "║  Source:    v%-14s ║\n" "$src_ver"
    printf  "║  %-26s ║\n" "$status_line"
    echo "╠══════════════════════════════╣"
    echo "║  1) Install / Upgrade        ║"
    echo "║  2) Remove / Uninstall       ║"
    echo "║  3) Restart Plasma           ║"
    echo "║  4) Quit                     ║"
    echo "╚══════════════════════════════╝"
    set_color normal
    echo ""
end

# ─── Main ────────────────────────────────────────────────────────────────────

check_deps
get_source_dir
compile_translations

while true
    show_menu
    read -P "Enter choice [1-4]: " choice < /dev/tty

    switch "$choice"
        case 1
            if is_installed
                do_upgrade
            else
                do_install
            end
        case 2
            do_remove
        case 3
            do_restart_plasma
        case 4 q Q quit exit
            info "Exiting."
            break
        case '*'
            warn "Invalid choice. Please enter 1, 2, 3, or 4."
    end
end

cleanup
