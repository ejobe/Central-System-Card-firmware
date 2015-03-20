# Create generated clocks based on PLLs


create_clock -period "40 MHz" \
					[get_ports DCrefclock]
					
create_clock -period "40 MHz" \
					[get_ports USB_IFCLK]
					
#set_false_path -setup -rise_from [get_ports USB_IFCLK] -fall_to [get_ports DCrefclock]
#set_false_path -setup -fall_from [get_ports USB_IFCLK] -rise_to[get_ports DCrefclock]
#set_false_path -hold -rise_from [get_ports USB_IFCLK] -rise_to_to [get_ports DCrefclock]
#set_false_path -hold -fall_from [get_ports USB_IFCLK] -fall_to[get_ports DCrefclock]

derive_pll_clocks -use_tan_name
					
derive_clock_uncertainty