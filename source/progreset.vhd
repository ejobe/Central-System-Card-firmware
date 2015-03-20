
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------																															
-- Design by: ejo															--
-- DATE : 10 March 2009																			--													--
-- FPGA chip :	altera cyclone III series									   --
-- USB chip : CYPRESS CY7C68013  															--
--	Module name: PROGRESET        															--
--	Description : 																					--
-- 	progreset will reset other modules                        				--
--																										--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--------------------------------------------------------------------------------
--   								I/O Definitions		   						         --
--------------------------------------------------------------------------------

entity PROGRESET is
    Port ( 	CLK     		: 	in std_logic; 		-- CLOCK	48MHz
          	WAKEUP  		: 	in std_logic; 		-- Active High Powered up USB
				xHARD_RESET : 	in std_logic;
				Clr_all 		: 	out std_logic; 	-- Active High Clr_all
           	GLRST   		: 	out std_logic); 	-- RESET low-active
end PROGRESET;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

architecture Behavioral of PROGRESET is
	type    	State_type is(RESETD, NORMAL);
	signal   state: State_type;	
	type		System_reset is (RESETS, NORMALS);
	signal   reset_state 	: System_reset;
	signal 	led_reset  		:	std_logic := '0';
	signal 	led_temp  		:	std_logic := '0';	
	signal 	led_temp_temp 	:	std_logic;	
	signal   POS_LOGIC		:	std_logic	:= '0';

	
	begin xRESET : process(WAKEUP, CLK) 
		variable i: integer range 0 to 144000000 :=0;
	begin	
		if WAKEUP = '0' then -- asynchronous reset
			POS_LOGIC <= '0';
			state <= RESETD;		
		elsif CLK = '1' and CLK'event then		
			case	state is
--------------------------------------------------------------------------------				
				when RESETD =>
						POS_LOGIC <= '0';

						if i > 143000000 then
							i:=0;
							state <= NORMAL;
						else
							if WAKEUP = '1' then
								i := i + 1;
								state <= RESETD;
							else
								state <= RESETD;
							end if;
						end if;
--------------------------------------------------------------------------------
				when NORMAL =>
					if WAKEUP = '1' then
						POS_LOGIC <= '1';
						state <=NORMAL;
					else
						state <= RESETD;
					end if;
--------------------------------------------------------------------------------
				when others =>
					state <= RESETD;
			end case;	
		end if;
	end process xRESET;
--------------------------------------------------------------------------------	
	process(CLK, xHARD_RESET)
		begin
			if led_reset = '1' then
				led_temp <= '0';
			elsif falling_edge(xHARD_RESET) then
				led_temp <= '1';		
			end if;
		end process;
	process(CLK, led_temp)
		variable i : integer range 1000010 downto 0 := 0;	
			begin
			if led_temp = '0' then
				led_temp_temp <= '0';
				led_reset <= '0';
				i := 0;
				reset_state <= RESETS;
			elsif rising_edge(CLK) and led_temp = '1' then
				case reset_state is
					when RESETS =>
						if i > 1000000 then
							i := 0;
							led_temp_temp <= '0';
							reset_state <= NORMALS;
						else
							i := i + 1;
							led_temp_temp <= '1';
						end if;
					
					when NORMALS =>
						led_reset <= '1';
				end case; 
			end if;
	end process;	
	
	process(POS_LOGIC) 
	begin	
		if POS_LOGIC = '0' or led_temp_temp = '1' then
				GLRST 	<= '0';
				Clr_all 	<= '1';
		else
				GLRST 	<= '1';
				Clr_all 	<= '0';
		end if;
	end process;	
end Behavioral;
--------------------------------------------------------------------------------
--   			                 	The End        						   	         --
--------------------------------------------------------------------------------