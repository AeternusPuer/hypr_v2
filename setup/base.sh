#!/bin/bash
if [[ $EUID -eq 0 ]]; then
    echo "ОШИБКА: Этот скрипт должен запускаться без прав суперпользователя"
    echo "Не используйте sudo и не запускайте из-под root"
    exit 1
fi
promt(){ TEMP="" && echo -en "\033[0;33m$@\033[0m " && read TEMP; }
SWAP_PATH="./setup/swap.sh"                         #Путь к скрипту установки swap
warning(){ echo -en "\033[0;31m$@\033[0m"; }
success(){ echo -en "\033[0;32m$@\033[0m"; }
install="quietly sudo pacman -S --noconfirm"
add="quietly yay -S --noconfirm"
quietly(){ "$@"> /dev/null 2>&1; }
setup_reflector(){
  while true; do
    if ! command -v reflector &> /dev/null; then
      count=$((count + 1))
      sudo pacman -Sy reflector >/dev/null 2>&1 --noconfirm 
    else
      break
    fi
    if [ $count -eq 3 ]; then
      warning "Не удалось установить reflector!"
      exit 1
    fi
  done
  return 0
}
run_loading() {
    local time=""
    local command="$1"
    local message="${2:-Установка ${1##* }}"
    # Запускаем команду в фоне
    eval "$command" & local pid=$!
    # Анимация пока процесс работает
    while kill -0 $pid 2>/dev/null; do
        for i in {1..3}; do
            if (( i==1 )); then
              time="- "
            elif (( i==2 )); then
              time=" -"
            elif (( i==3 )); then
              time="  "
            fi
            echo -ne "\r[ \033[1;36m$time\033[0m ] \033[1;36m$message\033[0m  "
            sleep 0.3
        done
    done
    # Ожидаем завершения процесса
    wait $pid
    local exit_code=$?
    echo -ne "\r"
    if [ $exit_code -eq 0 ]; then
        echo -n "[ " && success "OK" && echo -n " ]" && echo -e " \033[1;36m$message\033[0m"
    else
        echo -n "[ " && warning "NO" && echo -n " ]" && echo -e " \033[1;36m$message\033[0m"
    fi
    return $exit_code
}
sync_time(){
    sudo timedatectl set-ntp true                        #Включаем ntp
    sudo timedatectl set-timezone Asia/Yekaterinburg     #Устанавливаем часовой пояс
    sudo systemctl restart systemd-timesyncd             #Перезагружаем службу
}
setup_swap(){
    quietly sudo chmod +x $SWAP_PATH                             
    quietly sudo $SWAP_PATH                                      #Запуск скрипта установки swap
}
setup_permission(){
  local rule_content='polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.udisks2") == 0 && 
        subject.isInGroup("storage")) {
        return polkit.Result.YES;
    } });'
    if sudo test -f /etc/polkit-1/rules.d/50-udisks.rules; then
      return 0
    else
      echo "$rule_content" | sudo tee /etc/polkit-1/rules.d/50-udisks.rules > /dev/null
      sudo test -f /etc/polkit-1/rules.d/50-udisks.rules && return 0 || return 1
    fi
}
# Установка AUR helper (yay)
install_yay(){
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd ..
  rm -rf yay
}
# Базовые настройки
base_settings(){
  setup_reflector
  sudo reflector --country RU --protocol https --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
  quietly "sudo pacman -Syu" 
  sync_time
  clear
  run_loading setup_permission "Установка polkit storage"
  if swapon --show | grep -q .; then
    echo -n ""
  else
    run_loading setup_swap "Настройка файла swap"
  fi 
  if ! command -v yay &> /dev/null; then
    run_loading "quietly install_yay" "Установка yay"
  fi  
}
# Базовые пакеты
install_base_packages(){
  # Системные утилиты и мониторинг
  run_loading "$install btop" 
  run_loading "$install fastfetch" 
  run_loading "$install os-prober" 
  run_loading "$install zenity" 
  run_loading "$install lact"
  quietly sudo systemctl enable --now lactd
  run_loading "$install hyprshutdown" 
  # Драйверы и оборудование
  run_loading "$install lib32-nvidia-utils"
  # Сеть и интернет
  run_loading "$install wget" "Установка wget"
  run_loading "$install curl" "Установка curl"
  # Файловый менеджер и работа с файлами
  run_loading "$install thunar"
  run_loading "$install thunar-volman"
  run_loading "$install thunar-archive-plugin"
  run_loading "$install tumbler"
  run_loading "$install gvfs"
  run_loading "$install gvfs-mtp"
  run_loading "$install gvfs-gphoto2"
  run_loading "$install mtpfs"
  run_loading "$install ntfs-3g"
  run_loading "$install tree"
  # Мультимедиа (звук и видео)
  run_loading "$install vlc" 
  run_loading "$install pipewire-alsa" 
  run_loading "$install alsa-card-profiles" 
  run_loading "$install pipewire-pulse" 
  run_loading "$install alsa-utils" 
  run_loading "$install playerctl" 
  run_loading "$install pavucontrol"
  # Окружение Hyprland / Wayland
  run_loading "$install waybar"                       # Панель
  run_loading "$install swaybg"                       # Обои
  run_loading "$install azote"                        # Обои
  run_loading "$install wofi"                         # Меню запуска
  run_loading "$install hyprlock"                     # Экран блокировки
  run_loading "$install hyprpolkitagent"              # Агент аутентификации
  run_loading "$install nwg-look"                     # Утилита для настройки внешнего вида GTK
  run_loading "$install nwg-displays" 
  run_loading "$install slurp"                        # Утилита для выбора областей экрана
  run_loading "$install grim"                         # Cоздания скриншотов
  run_loading "$install qt5-wayland"
  run_loading "$install qt6-wayland" 
  run_loading "$install xdg-desktop-portal-hyprland" 
  run_loading "$install xdg-desktop-portal-wlr"
  # Браузер
  run_loading "$install firefox"                       # Браузер
  # Разработка
  run_loading "$install cmake" 
  # Графические библиотеки и зависимости
  run_loading "$install qt5-quickcontrols2" 
  run_loading "$install qt5-graphicaleffects" 
  run_loading "$add visual-studio-code-bin" 
  run_loading "$add hyprland-per-window-layout" 
  # Прочее
  run_loading "$install nano"
  run_loading "$install obsidian"
  #run_loading "$add onlyoffice"                       # Замена Microsoft Office
  # Оформление
  run_loading "$install breeze-gtk"
}
# Установка шрифтов
install_font()
{
  run_loading "$install ttf-dejavu" 
  run_loading "$install ttf-opensans" 
  run_loading "$install ttf-ubuntu-font-family" 
  run_loading "$install ttf-hack" 
  run_loading "$install ttf-terminus-nerd"
  run_loading "$install ttf-jetbrains-mono"
  run_loading "$install ttf-fira-code"
  run_loading "$add noto-fonts-emoji"
  run_loading "$add ttf-nerd-fonts-symbols"
}
install_obs()
{
  local temp="[Unit]
Description=Portal service
Requires=xdg-desktop-portal-hyprland.service
After=xdg-desktop-portal-hyprland.service
[Service]
ExecStart=/usr/lib/xdg-desktop-portal
Type=dbus
BusName=org.freedesktop.portal.Desktop"
  echo "$temp" | sudo tee /usr/lib/systemd/user/xdg-desktop-portal.service > /dev/null
  $install obs-studio
  $install pipewire
  $install wireplumber
  $install luajit

}
# Нужно изменить принцип работы, с локального копирования, на копирование с GitHub
settings(){
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  quietly git clone https://github.com/aeternuspuer/.config.git "$SCRIPT_DIR/.config"
  sudo cp -rf ./setup/.config \
              ./setup/.bashrc \
              ./  
  sudo chown -R $USER:wheel /home/$USER
  sudo chmod +x ~/.config/wofi/wofi-toggle.sh
}
main(){
  base_settings
  install_base_packages
  install_font
  run_loading "install_obs" "Установка OBS-Studio"
  run_loading settings "Настройка конфигурационных файлов"
}
main
