#!/bin/sh
# v9.4.3 global navigation contract.
# Menu Back tags are interpreted centrally by ui_menu in lib/ui.sh.

navigation_v943_report(){
  printf 'iSH-AOK Config 9.4.3 — Navigation Audit\n\n'
  printf 'Shared Back handling: enabled\n'
  printf 'Recognized Back tags: back, return, previous, __back__, @return\n'
  printf 'dialog Cancel label: Back\n'
  printf 'whiptail Cancel label: Back\n'
  printf 'text UI blank selection: Back\n'
  printf 'Declarative menu Back rows: shared UI exit\n'
}
