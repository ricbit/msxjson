set throttle off
set file_handle [open "coverage.txt" "w"]
set coverage_on 0
set addrs [dict create]

debug set_bp 0xD000 {} {set coverage_on 1}
debug set_watchpoint read_mem {0xD000 0xD400} {
  $coverage_on && [reg pc] == $wp_last_address
} {
  dict set addrs $wp_last_address 1
}
debug set_bp 0xFF07 {} {
  foreach addr [dict keys $addrs] {
    puts $file_handle $addr
  }
  close $file_handle
  quit
}

