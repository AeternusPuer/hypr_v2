#!/bin/bash
clear
warning(){ echo -en "\033[0;93m[\033[0m \033[0;31m$@\033[0m \033[0;93m]\033[0m" ; }
success(){ echo -en "\033[0;93m[\033[0m \033[0;32m$@\033[0m \033[0;93m]\033[0m" ; }
promt(){ TEMP="" && echo -en "\033[0;33m$@\033[0m " && read TEMP; }
promt_pass(){ TEMP="" && echo -en "\033[0;33m$@\033[0m " && read -s TEMP && echo ""; }
quietly(){ "$@" > /dev/null 2>&1; }
#-------------------------Default------------------#
CREATE_HOME=""          #                          #
DISK="/dev/sda"         # Диск установки           #
BOOT_PART="${DISK}1"    # Раздел /boot             #
ROOT_PART="${DISK}2"    # Раздел /                 #
HOME_PART="$ROOT_PART"  # Диск /home               #
ROOT_PASS="1111"        # Пароль пользователя root #
USER_NAME="user"        # Имя пользователя         #
USER_PASS="1111"        # Пароль пользователя      #
DISPLAY_MANAGER="sddm"  # Дисплейный менеджер      #
FONT="cyr-sun16"        # Шрифт в консоле          #
#--------------------------------------------------#
# Функция с бегущим многоточием
run_loading() {
    local command="$1"
    local message="${2:-Выполняется}"
    # Запускаем команду в фоне
    eval "$command" & local pid=$!
    # Анимация пока процесс работает
    while kill -0 $pid 2>/dev/null; do
        for i in {1..3}; do
            echo -ne "\r\033[0;93m[ -- ]\033[0m \033[1;36m$message$(printf '.%.0s' $(seq 1 $i))\033[0m  "
            sleep 0.3
        done
    done
    # Ожидаем завершения процесса
    wait $pid
    local exit_code=$?
    echo -ne "\r"
    if [ $exit_code -eq 0 ]; then
        success "OK" && echo -e " \033[1;36m$message...\033[0m" 
    else
        warning "NO" && echo -e " \033[1;36m$message...\033[0m"
    fi
    return $exit_code
}
default(){
    echo -en "\033[0;93m"
    echo -e "•••••••••••••••••••••••••••••••••••••••••••••••••"
    echo -e "• Имя пользователя:\t$USER_NAME\t\t\t•"
    echo -e "• Дисплейный менеджер:\t$DISPLAY_MANAGER\t\t\t•"
    echo -e "• Оконный менеджер:\t$WINDOW_MANAGER\t\t\t•"
    echo -e "• Раздел boot:\t$BOOT_PART\t\t\t•"
    echo -e "• Раздел root:\t$ROOT_PART\t\t\t•"
    echo -e "• Раздел home:\t$HOME_PART\t\t\t•"
    echo -e "• Режим BIOS:\t$BOOT_MODE\t\t\t•"
    echo -e "•••••••••••••••••••••••••••••••••••••••••••••••••"
    echo -en "\033[0m"
}
# Ввод имени пользователя
select_user(){
  promt "Введите имя пользователя:"
  if [ "$TEMP" != "" ]; then
     USER_NAME=$TEMP
  fi
}
# Ввод пароля пользователя
select_user_pass(){
  promt_pass "Введите пароль пользователя:"
  if [ "$TEMP" != "" ]; then
     USER_PASS=$TEMP
  fi
}
# Ввод пароля рут
select_root_pass(){
  promt_pass "Введите пароль root:"
  if [ "$TEMP" != "" ]; then
     ROOT_PASS=$TEMP
  fi
}
# Выбор папки home
select_home_part(){
     while true; do
      promt "Выберите диск home (sda):"
      if [[ "/dev/$TEMP" != "$DISK" && "$TEMP" != '' ]]; then
        if [[ -b "/dev/$TEMP" ]]; then
          CREATE_HOME="true"
          HOME_DISK="/dev/$TEMP"
          HOME_PART="${HOME_DISK}1"
          break;
        else
            warning "Ошибка. Диск не найден!"
            echo -en "\n"
        fi
      else
        break;
      fi
    done
}
select_settings(){
  select_part
  select_home_part
  select_user
  select_user_pass
  select_root_pass
  default
  promt "Нажмите Enter для продолжения..."
}
# Локализация
localization(){
  sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  sed -i 's/^#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
  echo "LANG="ru_RU.UTF-8"" > /etc/locale.conf
  set $FONT
  quietly locale-gen
}
# Установка рефлектора
setup_reflector(){
  while true; do
    if ! command -v reflector &> /dev/null; then
      count=$((count + 1))
      pacman -Sy reflector >/dev/null 2>&1 --noconfirm 
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
# Проверка BIOS/UFFI
check_bios(){
  if [ -d /sys/firmware/efi/efivars ]; then
  BOOT_MODE="UEFI"
  else
  BOOT_MODE="BIOS"
  fi
}
# Инициализация
initialisation(){
  setfont $FONT                                                               #Установка шрифта консоли
  sed -i 's/^ParallelDownloads = 5/ParallelDownloads = 25/' /etc/pacman.conf  #Установка количества параллельных загрузок
  timedatectl set-ntp true
  timedatectl set-timezone Asia/Yekaterinburg
  systemctl stop systemd-timesyncd
  sed -i 's/^#NTP=/NTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org 3.arch.pool.ntp.org/' /etc/systemd/timesyncd.conf
  systemctl start systemd-timesyncd
  setup_reflector
  reflector --country RU --protocol https --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
  quietly pacman -Syy
  clear
  return 0
}
# Форматирование и монтирование разделов
# Добавить выбор, необходимо ли форматировать папку home
formating_part(){
  if [ "$BOOT_MODE" = "UEFI" ]; then
    quietly mkfs.vfat $BOOT_PART 
    quietly mkfs.ext4 -I 256 $ROOT_PART 
    quietly mount $ROOT_PART /mnt
    quietly mkdir -p /mnt/boot/efi 
    quietly mount $BOOT_PART /mnt/boot/efi
    if [[ "$CREATE_HOME" == "true" ]]; then
      quietly mkfs.ext4 -I 256 $HOME_PART
      quietly mkdir -p /mnt/home
      quietly mount $HOME_PART /mnt/home
      HOME_UUID=$(blkid -s UUID -o value "$HOME_PART")
    fi
  fi
}
# выбор диска для установки
select_part(){
    while true; do
      echo -e "\033[0;93m" && lsblk && echo -en "\033[0m"
      promt "Выберите диск root (sda):"
      if [[ "$TEMP" != '' && -b "/dev/$TEMP" ]]; then
        DISK="/dev/$TEMP"
        break;
      else
          warning "Ошибка. Диск не найден!"
          echo -en "\n"
      fi
    done
}
# Создание разделов
# Добавить проверку, существуют ли уже разделы
create_part(){
  quietly parted -s $DISK mklabel gpt
  quietly parted -s $DISK mkpart "EFI" fat32 1MiB 513MiB
  quietly parted -s $DISK set 1 esp on
  quietly parted -s $DISK mkpart "root" ext4 513MiB 100%
  if [[ "$CREATE_HOME" == "true" ]]; then
    quietly parted -s $HOME_DISK mklabel gpt
    quietly parted -s $HOME_DISK mkpart "home" ext4 513MiB 100%
  fi
}
# Установка базовой системы
install_base(){
quietly pacstrap /mnt base base-devel linux linux-firmware linux-headers bash-completion grub efibootmgr 
     #pacstrap /mnt base base-devel linux linux-firmware linux-headers bash-completion grub efibootmgr 
}
# Установка Wayland
install_wayland(){
  quietly pacstrap /mnt wayland xorg-xwayland  
}
# Установка Hyprland
install_hyprland(){
 quietly pacstrap /mnt hyprland  
}
# Установка дополнительного по
install_other(){
  quietly pacstrap /mnt networkmanager kitty git $DISPLAY_MANAGER nvidia-utils nvidia-dkms
}
# Генерация fstab
gen_fstab(){
  quietly genfstab -U /mnt >> /mnt/etc/fstab
}
# Установка загрузчика
install_grub(){
  quietly grub-install $BOOT_PART
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3/' /etc/default/grub
  quietly grub-mkconfig -o /boot/grub/grub.cfg
}
# Установка пароля root
install_root_pass(){
  echo "root:$ROOT_PASS" | chpasswd 
}
# Создание и настройка пользователя
create_user(){
  quietly useradd -m $USER_NAME
  echo "$USER_NAME:$USER_PASS" | chpasswd
  quietly usermod -aG wheel,storage,disk,optical $USER_NAME
}
# Настройка sudo
setup_sudo(){
    sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
}
# Настройка параллельной загрузки PACMAN
setup_pacman(){
    quietly sed -i 's|^ParallelDownloads = 5|ParallelDownloads = 30|' /etc/pacman.conf
    quietly sed -i 's/^#\[multilib\]/[multilib]/' /etc/pacman.conf
    quietly sed -i '/^\[multilib\]/{n; s/^#//}' /etc/pacman.conf
}
setup_fstab(){
  echo -e "\n#$HOME_PART" >> /etc/fstab
  sed -i "\$aUUID=$HOME_UUID\t/home\text4\tdefaults,nodev,nosuid\t0\t2" /etc/fstab
}
copy_setup(){
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    TARGET_DIR="/mnt/home/$USER_NAME"
    mkdir -p "$TARGET_DIR"
    cp -rf $SCRIPT_DIR/setup $TARGET_DIR
}
on_nm(){ quietly systemctl enable NetworkManager ; }
on_dm(){ quietly systemctl enable $DISPLAY_MANAGER ; }
arch_chroot(){
arch-chroot /mnt bash <<EOF
  $(declare -f success warning run_loading quietly localization install_grub install_root_pass create_user setup_sudo setup_pacman on_nm on_dm setup_fstab)
  $(declare -p ROOT_PASS USER_NAME USER_PASS BOOT_PART HOME_PART FONT DISPLAY_MANAGER CREATE_HOME)
  run_loading on_nm "Включение NetworkManager"
  run_loading on_dm "Включение DisplayManager"
  run_loading localization "Локализация"
  run_loading install_grub "Установка загрузчика"
  run_loading create_user "Cоздание пользователя"
  run_loading install_root_pass "Установка пароля root"
  run_loading setup_sudo "Настройка sudo"
  run_loading setup_pacman "Настройка pacman" 
  chown -R $USER_NAME:wheel /home/$USER_NAME
  if [[ "$CREATE_HOME" == "true" ]]; then
    HOME_UUID=$(blkid -s UUID -o value "$HOME_PART")
    run_loading setup_fstab "Настройка fstab"
  fi
EOF
}
main(){
  check_bios                     # Проверка на UEFI/BIOS 
  initialisation                 # Инициализация необходимых вещей для установки
  select_settings
  run_loading create_part "Создание разделов"
  run_loading formating_part "Форматирование"
  run_loading copy_setup "Копирование папки setup"
  run_loading install_base "Установка базовой системы"
  # install_base
  run_loading install_wayland "Установка Wayland"
  run_loading install_hyprland "Установка Hyprland"
  run_loading install_other "Установка дополнительного ПО"
  run_loading gen_fstab "Генерация fstab"
  arch_chroot
  umount -R /mnt
  promt "Основная установка завершена. Для перезагрузки нажмите клавишу Enter..."
  clear
  quietly reboot
}
main #Основная Функция
