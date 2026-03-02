export GRUB_ENV=/efi/EFI/Boot/grubenv
export GRUB_CFG=/efi/EFI/Boot/grub.cfg

alias grub-list='grub-editenv $GRUB_ENV list'
alias grub-set='grub-editenv $GRUB_ENV set'
alias set-a='grub-set ORDER="A B"'
alias set-b='grub-set ORDER="B A"'
