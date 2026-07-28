#!/bin/sh
navigation_v945_report(){
  printf 'iSH-AOK Config 9.4.5 — Menu Boundary Navigation\n\n'
  printf 'Dedicated Back status: %s\n' "${UI_MENU_BACK_RC:-90}"
  printf 'Menu boundaries normalized: yes\n'
  printf 'Back propagation to launcher: blocked\n'
  printf 'Real menu errors: preserved\n'
}
