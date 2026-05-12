#!/usr/bin/env bash
# ============================================================
#  ███╗   ██╗███████╗███████╗██╗  ██╗    ██████╗ ██╗ ██████╗███████╗
#  ████╗  ██║██╔════╝██╔════╝██║  ██║    ██╔══██╗██║██╔════╝██╔════╝
#  ██╔██╗ ██║█████╗  ███████╗███████║    ██████╔╝██║██║     █████╗
#  ██║╚██╗██║██╔══╝  ╚════██║██╔══██║    ██╔══██╗██║██║     ██╔══╝
#  ██║ ╚████║███████╗███████║██║  ██║    ██║  ██║██║╚██████╗███████╗
#  ╚═╝  ╚═══╝╚══════╝╚══════╝╚═╝  ╚═╝    ╚═╝  ╚═╝╚═╝ ╚═════╝╚══════╝
# ============================================================
# Instalador do Starship + Customizador de Terminal
# Mantenedor: NESh Core
# ============================================================

set -euo pipefail

# --- Cores para output ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; PURPLE='\033[0;35m'; NC='\033[0m'
BOLD='\033[1m'

logo() {
    echo -e "${PURPLE}"
    cat << 'EOF'
    ╔══════════════════════════════════════════╗
    ║       NESH://BLACKSITE TERMINAL RICE     ║
    ║        Starship Installer & Customizer   ║
    ╚══════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# --- Função para exibir mensagens ---
msg() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# --- Detectar sistema operacional ---
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi
    msg "Sistema detectado: ${OS}"
}

# --- Verificar dependências básicas ---
check_deps() {
    local deps=("curl" "tar" "gzip" "find" "grep" "sed")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            warn "Dependência '$dep' não encontrada. Instalando..."
            install_pkg "$dep"
        fi
    done
}

# --- Instalador de pacotes universal ---
install_pkg() {
    local pkg=$1
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y "$pkg"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y "$pkg"
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm "$pkg"
    elif command -v brew &>/dev/null; then
        brew install "$pkg"
    else
        err "Gerenciador de pacotes não suportado. Instale '$pkg' manualmente."
    fi
}

# --- Instalar Starship ---
install_starship() {
    if command -v starship &>/dev/null; then
        msg "Starship já está instalado."
        return
    fi

    warn "Starship não encontrado. Iniciando instalação..."

    # Tentar via gerenciador de pacotes primeiro
    case $OS in
        ubuntu|debian)
            if command -v apt &>/dev/null; then
                msg "Instalando via APT..."
                sudo apt update && sudo apt install -y starship 2>/dev/null && return
            fi
            ;;
        fedora|rhel|centos)
            if command -v dnf &>/dev/null; then
                msg "Instalando via DNF..."
                sudo dnf install -y starship 2>/dev/null && return
            fi
            ;;
        arch|manjaro)
            if command -v pacman &>/dev/null; then
                msg "Instalando via Pacman..."
                sudo pacman -S --noconfirm starship 2>/dev/null && return
            fi
            ;;
    esac

    # Fallback: script oficial
    msg "Usando script oficial do Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y || err "Falha ao instalar Starship."
}

# --- Detectar shells disponíveis ---
detect_shells() {
    SHELLS_CONFIGURED=()
    for shell in bash zsh fish; do
        if command -v "$shell" &>/dev/null; then
            SHELLS_CONFIGURED+=("$shell")
        fi
    done
    if [ ${#SHELLS_CONFIGURED[@]} -eq 0 ]; then
        err "Nenhum shell suportado encontrado (bash, zsh, fish)."
    fi
    msg "Shells detectados: ${SHELLS_CONFIGURED[*]}"
}

# --- Função para configurar um shell ---
configure_shell() {
    local shell=$1
    local rc_file
    case $shell in
        bash) rc_file="$HOME/.bashrc" ;;
        zsh)  rc_file="$HOME/.zshrc" ;;
        fish) rc_file="$HOME/.config/fish/config.fish" ;;
    esac

    # Garantir diretório para fish
    if [ "$shell" = "fish" ]; then
        mkdir -p "$(dirname "$rc_file")"
    fi

    # Linha de inicialização
    local init_line
    case $shell in
        bash|zsh) init_line='eval "$(starship init '"$shell"')"' ;;
        fish)     init_line='starship init fish | source' ;;
    esac

    # Verificar se já existe
    if [ -f "$rc_file" ] && grep -q "starship init" "$rc_file"; then
        msg "Starship já configurado no $rc_file."
        return
    fi

    # Backup
    if [ -f "$rc_file" ]; then
        cp "$rc_file" "${rc_file}.bak.$(date +%s)"
        msg "Backup criado: ${rc_file}.bak.*"
    fi

    # Adicionar ao final
    echo "" >> "$rc_file"
    echo "# >>> Starship prompt (adicionado por NESh installer) >>>" >> "$rc_file"
    echo "$init_line" >> "$rc_file"
    echo "# <<< Starship <<<" >> "$rc_file"

    msg "Shell $shell configurado."
}

# --- Escolher tema ---
choose_theme() {
    echo -e "${CYAN}${BOLD}Escolha o tema do Starship:${NC}"
    echo "1) NESH://BLACKSITE (roxo futurista com cabeçalho)"
    echo "2) Caveira Assombrada (divertido, terror leve)"
    echo "3) Minimalista Limpo (apenas informações essenciais)"
    read -rp "Digite o número do tema (1-3): " theme_choice

    case $theme_choice in
        1) write_nesh_theme ;;
        2) write_skull_theme ;;
        3) write_minimal_theme ;;
        *) warn "Opção inválida, usando tema NESH."; write_nesh_theme ;;
    esac
    msg "Tema aplicado em ~/.config/starship.toml"
}

# --- Temas (embedados) ---
write_nesh_theme() {
    cat > ~/.config/starship.toml << 'NESH_EOF'
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃               NESH://BLACKSITE              ┃
# ┃         recovered infrastructure node       ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

add_newline = false
command_timeout = 900

format = """
$custom.header\
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$c\
$cpp\
$nodejs\
$python\
$memory_usage\
$custom.jobs\
$cmd_duration\
$line_break\
$character\
"""

palette = "nesh"

[palettes.nesh]
bg            = "#0b0d12"
void          = "#12141b"
purple        = "#b05cff"
deep_purple   = "#7d3cff"
soft          = "#c7b8ff"
white         = "#d6d6e7"
red           = "#ff4d6d"
warning       = "#ffb86c"
faded         = "#6e7391"

[custom.header]
command = "echo '╭─[ NESH://BLACKSITE ]'"
when = "true"
shell = ["bash"]
style = "fg:purple bold"
format = "[$output]($style)\n"

[username]
show_always = true
style_user = "fg:soft bold"
style_root = "fg:red bold"
format = "│ user :: [$user]($style) "

[hostname]
ssh_only = true
style = "fg:deep_purple bold"
format = "node :: [$hostname]($style)\n"

[directory]
style = "fg:white bold"
truncation_length = 3
truncate_to_repo = true
home_symbol = "~"
read_only = " [locked]"
format = "│ path :: [$path]($style) "

[git_branch]
symbol = "git:"
style = "fg:purple bold"
format = "branch :: [$symbol $branch]($style) "

[git_status]
style = "fg:warning bold"
format = "[$all_status$ahead_behind]($style)"
ahead = "[⇡](fg:purple bold)"
behind = "[⇣](fg:purple bold)"
diverged = "[⇕](fg:red bold)"
conflicted = "[≠](fg:red bold)"
deleted = "[×](fg:red bold)"
renamed = "[»](fg:purple bold)"
modified = "[•](fg:warning bold)"
staged = "[+](fg:soft bold)"
untracked = "[?](fg:faded bold)"

[nodejs]
symbol = "js"
style = "fg:purple bold"
format = "\n│ runtime :: [$symbol $version]($style)"

[python]
symbol = "py"
style = "fg:deep_purple bold"
format = " [$symbol $version]($style)"

[c]
symbol = "c"
style = "fg:soft bold"
format = "\n│ compiler :: [$symbol]($style)"

[cpp]
symbol = "cpp"
style = "fg:soft bold"
format = " [$symbol]($style)"

[memory_usage]
disabled = false
threshold = 70
style = "fg:faded bold"
format = "\n│ usage :: [mem ${ram}]($style)"

[custom.jobs]
command = 'if [ $(jobs -l | wc -l) -gt 0 ]; then echo " ⚙"; fi'
when = "true"
shell = ["bash"]
style = "fg:warning bold"
format = "[$output]($style)"

[cmd_duration]
min_time = 1500
style = "fg:warning bold"
format = " [took $duration]($style)"

[character]
success_symbol = "[╰─▶ access granted](fg:purple bold)"
error_symbol = "[╰─▶ integrity compromised](fg:red bold)"

[status]
disabled = false
style = "fg:red bold"
format = ""

[time]
disabled = true

[battery]
disabled = true
NESH_EOF
}

write_skull_theme() {
    cat > ~/.config/starship.toml << 'SKULL_EOF'
[character]
success_symbol = "[>>](bold green)"
error_symbol = "[!!](bold red)"

[directory]
truncation_length = 3
format = "in [$path]($style) "
style = "bold cyan"

[git_branch]
format = "on [🌿 $branch](bold purple) "

[git_status]
conflicted = "⚡"
deleted = "🗑"
renamed = "📛"
modified = "✏️"
staged = "✔️"

[cmd_duration]
min_time = 2000
format = "took [⏳ $duration](bold yellow) "

[python]
format = "via [🐍 v${version}](bold green) "

[nodejs]
format = "via [🌐 v${version}](bold green) "

[status]
format = '[💀 $status](bold red) '
disabled = false

[time]
disabled = false
format = '🕒 [$time]($style) '
style = "bold yellow"

[custom.skull]
command = "echo '💀'"
when = "true"
format = "[$output]($style)"
style = "bold red blink"
SKULL_EOF
}

write_minimal_theme() {
    cat > ~/.config/starship.toml << 'MINIMAL_EOF'
add_newline = false

format = """

$directory\
$git_branch\
$git_status\
$nodejs\
$python\
$cmd_duration\
$line_break\
$character\
"""

[directory]
style = "bold blue"
truncation_length = 2
format = "[$path]($style) "

[git_branch]
symbol = "git:"
style = "bold yellow"

[character]
success_symbol = "[→](bold green)"
error_symbol = "[→](bold red)"
MINIMAL_EOF
}

# --- Aplicar cores ao terminal (opcional, apenas GUI) ---
apply_terminal_colors() {
    if command -v dconf &>/dev/null && [ -n "${DISPLAY:-}" ]; then
        warn "Ambiente gráfico detectado. Aplicar paleta NESh ao GNOME Terminal? (s/N)"
        read -r resp
        if [[ "$resp" =~ ^[sS] ]]; then
            PROFILE=$(dconf list /org/gnome/terminal/legacy/profiles:/ | head -1 | tr -d '/')
            if [ -n "$PROFILE" ]; then
                dconf write /org/gnome/terminal/legacy/profiles:/:${PROFILE}/palette "['#0b0d12', '#ff4d6d', '#b05cff', '#ffb86c', '#7d3cff', '#c7b8ff', '#6e7391', '#d6d6e7', '#12141b', '#ff4d6d', '#b05cff', '#ffb86c', '#7d3cff', '#c7b8ff', '#6e7391', '#d6d6e7']"
                dconf write /org/gnome/terminal/legacy/profiles:/:${PROFILE}/background-color "'#0b0d12'"
                dconf write /org/gnome/terminal/legacy/profiles:/:${PROFILE}/foreground-color "'#d6d6e7'"
                msg "Paleta de cores aplicada ao GNOME Terminal."
            fi
        fi
    fi
}

# --- Resumo final ---
final_message() {
    echo -e "\n${GREEN}${BOLD}Instalação concluída!${NC}"
    echo -e "${CYAN}Tema escolhido aplicado em: ~/.config/starship.toml${NC}"
    echo -e "Para ver as mudanças, abra um novo terminal ou execute:"
    echo -e "  ${YELLOW}exec bash${NC}   (ou exec zsh / exec fish)"
    echo -e "\n${PURPLE}Dica:${NC} Use 'starship toggle' para desativar temporariamente."
}

# ============================================================
# EXECUÇÃO PRINCIPAL
# ============================================================
main() {
    logo
    detect_os
    check_deps
    install_starship
    detect_shells

    # Criar diretório de configuração
    mkdir -p ~/.config

    # Escolher e aplicar tema
    choose_theme

    # Configurar cada shell encontrado
    for shell in "${SHELLS_CONFIGURED[@]}"; do
        configure_shell "$shell"
    done

    apply_terminal_colors
    final_message
}

main "$@"
