library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity USBread is
   port ( xIFCLK     			: in    	std_logic;
          xUSB_DATA  			: in    	std_logic_vector (15 downto 0);
          xFLAGA    				: in    	std_logic;
			 xRESET    				: in    	std_logic;
          xWBUSY    				: in    	std_logic;
			 xCLK40					: in		std_logic;
			 xCC_SYNC_IN			: in		std_logic;
			 xCC_SYNC_OUT			: out		std_logic;
          xFIFOADR  				: out   	std_logic_vector (1 downto 0);
          xRBUSY    				: out   	std_logic;
          xSLOE     				: out   	std_logic;
          xSLRD     				: out   	std_logic;
          xSYNC_USB 				: out   	std_logic;
          xSOFT_TRIG				: out   	std_logic_vector(3 downto 0);
			 xSOFT_TRIG_BIN		: out		std_logic_vector(2 downto 0);
			 xALIGN					: out	  	std_logic;
			 xCC_INSTRUCTION		: out		std_logic_vector(31 downto 0);
			 xCC_INSTRUCT_RDY		: out		std_logic;
			 xCC_READ_MODE			: out		std_logic_vector(2 downto 0);
			 xTRIG_MODE				: out		std_logic;
			 xCC_SOFT_DONE 		: out		std_logic;
			 xTRIG_DELAY			: out 	std_logic_vector(6 downto 0);
          xTOGGLE   				: out   	std_logic;
			 xRESET_TIMESTAMP 	: out  	std_logic;
			 xREAD_CC_BUFFER		: out  	std_logic;
			 xTRIG_SOURCE        : out  	std_logic_vector(2 downto 0);
			 xINSTRUCT_MASK		: out 	std_logic_vector(3 downto 0);
			 xHARD_RESET         : out 	std_logic; 
			 xWAKEUP_USB			: out    std_logic;
			 xTRIG_VALID			: out		std_logic);
end USBread;

architecture BEHAVIORAL of USBread is
	--usb FSM and signals for interface control
	type State_type is(st1_WAIT,
							st1_READ, st2_READ, st3_READ,st4_READ,
							st1_SAVE, st1_TARGET, ENDDELAY);
	signal state: State_type;
	signal dbuffer				: std_logic_vector (15 downto 0);
	signal Locmd				: std_logic_vector (15 downto 0);
	signal Hicmd				: std_logic_vector (15 downto 0);
	signal again				: std_logic_vector (1 downto 0);
	signal TOGGLE				: std_logic;
	signal SOFT_TRIG			: std_logic;
	signal SOFT_TRIG_BIN		: std_logic_vector(2 downto 0);
	signal SOFT_TRIG_MASK	: std_logic_vector(3 downto 0);
	signal SYNC_USB			: std_logic;
	signal ALIGN_LVDS    	: std_logic;
	signal SLRD					: std_logic;
	signal SLOE					: std_logic;
	signal RBUSY				: std_logic;
	signal FIFOADR    		: std_logic_vector (1 downto 0);
	
	--signals for CC 32 bit instructions
	signal cc_only_instruct_rdy	: std_logic;
	signal CC_INSTRUCTION			: std_logic_vector(31 downto 0);
	signal CC_INSTRUCT_RDY			: std_logic;
	--copies of above for syncing
	signal CC_INSTRUCTION_GOOD		: std_logic_vector(31 downto 0);
	signal CC_INSTRUCT_RDY_GOOD	: std_logic;
	signal CC_INSTRUCTION_tmp		: std_logic_vector(31 downto 0);
	
	type handle_cc_instruct_state_type is (get_instruct, check_sync, get_synced, send_instruct, be_done );
	signal handle_cc_instruct_state: handle_cc_instruct_state_type;
	signal handle_cc_only_instruct_state: handle_cc_instruct_state_type;
	
	--signals to CC only
	signal trig_valid			: std_logic;
	signal CC_READ_MODE		: std_logic_vector(2 downto 0);
	signal TRIG_MODE	   	: std_logic;
	signal TRIG_SOURCE   	: std_logic_vector(2 downto 0);
	signal CC_SOFT_DONE		: std_logic;
	signal TRIG_DELAY			: std_logic_vector (6 downto 0);
	signal RESET_DLL_FLAG	: std_logic;
	signal read_cc_buffer	: std_logic;
	signal HARD_RESET       : std_logic := '0';
	signal WAKEUP_USB 		: std_logic := '0';
	signal INSTRUCT_MASK		: std_logic_vector(3 downto 0);

	--copies of above that may be synced
	signal trig_valid_GOOD			: std_logic;
	signal trig_valid_TMP			: std_logic;
	signal SOFT_TRIG_GOOD			: std_logic;
	signal SOFT_TRIG_MASK_GOOD		: std_logic_vector(3 downto 0);
	signal SOFT_TRIG_BIN_GOOD		: std_logic_vector(2 downto 0);
	signal SOFT_TRIG_TMP				: std_logic;
	signal SOFT_TRIG_MASK_TMP		: std_logic_vector(3 downto 0);
	signal SOFT_TRIG_BIN_TMP		: std_logic_vector(2 downto 0);
	signal RESET_TIME_GOOD			: std_logic;
	signal RESET_TIME_TMP			: std_logic;
	signal CC_SOFT_DONE_TMP			: std_logic;
	signal CC_SOFT_DONE_GOOD		: std_logic;
	signal INSTRUCT_MASK_TMP		: std_logic_vector(3 downto 0);
	signal INSTRUCT_MASK_GOOD		: std_logic_vector(3 downto 0);

	signal		SYNC_TRIG			: std_logic;
	signal		SYNC_MODE			: std_logic;
	signal		SYNC_TIME			: std_logic;
	signal		SYNC_RESET			: std_logic;
	--syncing signals between boards 
	signal CC_SYNC				: std_logic;	--from USB, clocked on 48 MHz
	signal CC_SYNC_REG		: std_logic;  	--registered on 40 MHz clock
	signal CC_SYNC_IN_REG	: std_logic;	--registered on 40 MHz clock
	--
	signal done_with_cc_instruction 			: std_logic;
	signal ready_for_instruct   	  			: std_logic;
	--
	signal done_with_cc_only_instruction 	: std_logic;
	signal ready_for_cc_instruct				: std_logic;
	signal		sync_a					: std_logic;
	signal		sync_b					: std_logic;
	signal		sync_c					: std_logic;
	signal		sync_d					: std_logic;
	signal   soft_trig_ready_good  : std_logic;
	--signal TX_LENGTH     	: std_logic_vector (13 downto 0);
--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
	xTOGGLE 				<= TOGGLE;
	xSYNC_USB 			<= SYNC_USB;
	xSLRD 				<= SLRD;
	xSLOE 				<= SLOE;
	xRBUSY 				<= RBUSY;
	xFIFOADR 			<= FIFOADR;
	xALIGN				<= ALIGN_LVDS;
	--xCC_SOFT_DONE		<= CC_SOFT_DONE;
	xCC_SOFT_DONE		<= CC_SOFT_DONE;
	--cc instructions
	xCC_INSTRUCTION	<= CC_INSTRUCTION_GOOD;
	xCC_INSTRUCT_RDY	<= CC_INSTRUCT_RDY_GOOD;
	xINSTRUCT_MASK		<= INSTRUCT_MASK_GOOD;
	--
	xCC_READ_MODE	 	<= CC_READ_MODE(2 downto 0);
	xTRIG_MODE			<= TRIG_MODE;
	xTRIG_SOURCE 		<= TRIG_SOURCE;  
	xTRIG_DELAY 		<= TRIG_DELAY;
	xRESET_TIMESTAMP 	<= RESET_DLL_FLAG;
	xREAD_CC_BUFFER 	<= read_cc_buffer;
	xHARD_RESET       <= HARD_RESET;
	xWAKEUP_USB       <= WAKEUP_USB;
	xCC_SYNC_OUT		<= CC_SYNC_REG;
	xTRIG_VALID			<= trig_valid;
--------------------------------------------------------------------------------	
process(xRESET, xCLK40)
begin
	if xRESET = '0' then
		CC_SYNC_REG 	<= '0';
		CC_SYNC_IN_REG	<= '0';
	elsif rising_edge(xCLK40) then
		CC_SYNC_REG 	<= CC_SYNC;
		CC_SYNC_IN_REG	<= xCC_SYNC_IN;
	end if;
end process;		
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
	process(soft_trig_ready_good 	)
	begin
		if xRESET = '0'  then
			xSOFT_TRIG 		<= (others=>'0');
			xSOFT_TRIG_BIN <= (others=>'0');
		elsif rising_edge(xCLK40) and soft_trig_ready_good = '0'  then
			xSOFT_TRIG 		<= (others=>'0');
			xSOFT_TRIG_BIN <= (others=>'0');
		elsif rising_edge(xCLK40) and soft_trig_ready_good = '1'  then
			xSOFT_TRIG 		<= SOFT_TRIG_MASK_GOOD;
			xSOFT_TRIG_BIN <= SOFT_TRIG_BIN_GOOD;
		end if;
	end process;
	
	process(xRESET, cc_only_instruct_rdy)
	begin
		if xRESET = '0' or done_with_cc_only_instruction= '1' then
			ready_for_cc_instruct <= '0';
		elsif rising_edge(cc_only_instruct_rdy) then
			ready_for_cc_instruct  <= '1';
		end if;
	end process;
	-----
	process(xCLK40, ready_for_cc_instruct, xRESET)
	variable i : integer range 100002 downto 0;	
	begin
		if xRESET = '0' then 
			done_with_cc_only_instruction <= '0';
			i := 0;
			SOFT_TRIG_TMP 			<= '0';	 
			SOFT_TRIG_MASK_TMP 	<= (others=>'0');
			SOFT_TRIG_MASK_GOOD 	<= (others=>'0');
			SOFT_TRIG_BIN_TMP 	<= (others=>'0');
			SOFT_TRIG_BIN_GOOD 	<= (others=>'0');
			CC_SOFT_DONE_TMP     <= '0';
			CC_SOFT_DONE_GOOD		<= '0';
			RESET_TIME_TMP 		<= '0';
			RESET_TIME_GOOD		<= '0';	
			trig_valid_GOOD		<= '0';
			sync_a					<= '0';
			sync_b					<= '0';
			sync_c					<= '0';
			sync_d					<= '0';
			handle_cc_only_instruct_state <= get_instruct;
		
		elsif falling_edge(xCLK40) and ready_for_cc_instruct = '0' then
			--same as RESET condition, except for trig_valid flag (only change value when toggled)
			done_with_cc_only_instruction<= '0';
			i := 0;
			SOFT_TRIG_TMP 			<= '0';	 
			SOFT_TRIG_GOOD			<= '0';
			SOFT_TRIG_MASK_TMP 	<= (others=>'0');
			SOFT_TRIG_MASK_GOOD 	<= (others=>'0');
			--SOFT_TRIG_BIN_TMP 	<= (others=>'0');
			--SOFT_TRIG_BIN_GOOD 	<= (others=>'0');
			--CC_SOFT_DONE_TMP     <= '0';
			--CC_SOFT_DONE_GOOD		<= '0';
			--RESET_TIME_TMP 		<= '0';
			--RESET_TIME_GOOD		<= '0';
			--sync_a					<= '0';
			--sync_b					<= '0';
			--sync_c					<= '0';
			--sync_d					<= '0';	
			handle_cc_only_instruct_state <= get_instruct;

		elsif falling_edge(xCLK40) and ready_for_cc_instruct = '1' then
			case handle_cc_only_instruct_state is
			
				when get_instruct=>
					SOFT_TRIG_TMP 			<= SOFT_TRIG;	 
					SOFT_TRIG_MASK_TMP 	<= SOFT_TRIG_MASK;
					SOFT_TRIG_BIN_TMP		<= SOFT_TRIG_BIN;
					if i > 2 then
						i := 0;
						handle_cc_only_instruct_state <= check_sync;
					else
						i:=i+1;
					end if;

				when check_sync =>			
					if CC_SYNC_REG = '1' or CC_SYNC_IN_REG = '1' then						--
						i:=0;
						handle_cc_only_instruct_state <= get_synced;
						--
					else 
						i:=0;
						handle_cc_only_instruct_state <= send_instruct;
					end if;
		
				when get_synced =>
					if CC_SYNC_REG = '0' and CC_SYNC_IN_REG = '0' then
						i:=0;
						handle_cc_only_instruct_state <= send_instruct;
					elsif i > 50000 then
						i:=0;
						handle_cc_only_instruct_state <= send_instruct;
					else 
						i:=i+1;
						handle_cc_only_instruct_state <= get_synced;
					end if;
					
				when send_instruct =>						
					SOFT_TRIG_GOOD 			<= SOFT_TRIG_TMP;	 
					SOFT_TRIG_MASK_GOOD 		<= SOFT_TRIG_MASK_TMP;
					SOFT_TRIG_BIN_GOOD		<= SOFT_TRIG_BIN_TMP;
					soft_trig_ready_good    <= '1';							
					if i > 20 then
						i:= 0;
						handle_cc_only_instruct_state <= be_done;
					else
						i:= i+1;

					end if;
					
				when be_done =>
					i:=0;
					SOFT_TRIG_TMP 			<= '0';	 
					SOFT_TRIG_MASK_TMP 	<= (others=>'0');
					SOFT_TRIG_BIN_TMP    <= (others=>'0');
					done_with_cc_only_instruction <= '1';
				when others=>
					handle_cc_only_instruct_state <= get_instruct;
			
			end case;
		end if;
	end process;	
--------------------------------------------------------------------------------
------------------------------------------------------------------------------
--------------------------------------------------------------------------------	
	process(xRESET, CC_INSTRUCT_RDY)
	begin
		if xRESET = '0' or done_with_cc_instruction = '1' then
			ready_for_instruct <= '0';
		elsif rising_edge(CC_INSTRUCT_RDY) then
			ready_for_instruct <= '1';
		end if;
	end process;
	-----
	process(xCLK40, CC_SYNC_IN_REG, xRESET)
	variable i : integer range 50 downto 0;	
	begin
		if xRESET = '0' then 
			CC_INSTRUCTION_GOOD 	<= (others=>'0');
			CC_INSTRUCT_RDY_GOOD	<= '0';
			CC_INSTRUCTION_tmp 	<= (others=>'0');
			INSTRUCT_MASK_GOOD   <= (others=>'0');
			INSTRUCT_MASK_TMP    <= (others=>'0');
			done_with_cc_instruction <= '0';
			i := 0;
			handle_cc_instruct_state <= get_instruct;
		
		elsif falling_edge(xCLK40) and ready_for_instruct = '0' then	
			CC_INSTRUCTION_GOOD 	<= (others=>'0');
			CC_INSTRUCT_RDY_GOOD	<= '0';
			CC_INSTRUCTION_tmp 	<= (others=>'0');
			INSTRUCT_MASK_GOOD   <= (others=>'0');
			INSTRUCT_MASK_TMP    <= (others=>'0');
			done_with_cc_instruction <= '0';
			i := 0;
			handle_cc_instruct_state <= get_instruct;
			
		elsif falling_edge(xCLK40) and ready_for_instruct = '1' then
			case handle_cc_instruct_state is
			
				when get_instruct=>
					CC_INSTRUCTION_tmp 	<= CC_INSTRUCTION;
					INSTRUCT_MASK_TMP		<= INSTRUCT_MASK;
					if i > 2 then
						i := 0;
						handle_cc_instruct_state <= check_sync;
					else
						i:=i+1;
					end if;							
					
				when check_sync =>
					if CC_SYNC_REG = '1' or CC_SYNC_IN_REG = '1' then
						handle_cc_instruct_state <= get_synced;
				
					else 
						handle_cc_instruct_state <= send_instruct;
					end if;
		
				when get_synced =>
					i := 0;
					if CC_SYNC_REG = '0' and CC_SYNC_IN_REG = '0' then
						handle_cc_instruct_state <= send_instruct;
					else
						handle_cc_instruct_state <= get_synced;
					end if;
					
				when send_instruct =>
					INSTRUCT_MASK_GOOD	<= INSTRUCT_MASK_TMP;
					CC_INSTRUCTION_GOOD 	<= CC_INSTRUCTION_tmp;
					CC_INSTRUCT_RDY_GOOD <= '1';
					if i > 20 then
						i:= 0;
						handle_cc_instruct_state <= be_done;
					else
						i:= i+1;
					end if;
					
				when be_done =>
					INSTRUCT_MASK_GOOD	<= (others=>'0');
					CC_INSTRUCTION_GOOD 	<= (others=>'0');
					CC_INSTRUCT_RDY_GOOD <= '0';
					done_with_cc_instruction <= '1';
			
			end case;
		end if;
	end process;
--------------------------------------------------------------------------------				
--------------------------------------------------------------------------------
	process(xIFCLK, xRESET)
	variable delay : integer range 0 to 50;
	begin
		if xRESET = '0' then
			SYNC_USB		<= '0';
			SOFT_TRIG	<= '0';
			SLRD 			<= '1';
			SLOE 			<= '1';
			FIFOADR 		<= "10";
			TOGGLE 		<= '0';
			again 		<= "00";
			RBUSY 		<= '1';
			CC_INSTRUCTION <=(others=>'0');
			SOFT_TRIG_MASK <=(others=>'0');
			SOFT_TRIG_BIN  <=(others=>'0');
			CC_SOFT_DONE <= '0';
			CC_INSTRUCT_RDY<= '0';
			cc_only_instruct_rdy <= '0';
			CC_READ_MODE <= "000";
			ALIGN_LVDS <= '1';
			TRIG_MODE <= '0';
			TRIG_DELAY <= (others => '0');
			delay 		:= 0;	
			RESET_DLL_FLAG <= '0';
			read_cc_buffer <= '0';
			HARD_RESET     <= '0';
			WAKEUP_USB     <= '0';
			CC_SYNC        <= '0';
			trig_valid		<= '0';
			SYNC_TRIG				<= '0';
			SYNC_MODE				<= '0';
			SYNC_TIME				<= '0';
			SYNC_RESET				<= '0';
			state       <= st1_WAIT;
		elsif rising_edge(xIFCLK) then
			ALIGN_LVDS 	   <= '0';
			RESET_DLL_FLAG <= '0';
			SLOE 			   <= '1';
			SLRD 			   <= '1';
			CC_SOFT_DONE   <= '0';
			FIFOADR 		   <= "10";
			TOGGLE 		   <= '0';
			CC_INSTRUCT_RDY<= '0';
			cc_only_instruct_rdy <= '0';
			read_cc_buffer <= '0';
			SOFT_TRIG	   <= '0';
			HARD_RESET     <= '0';
			WAKEUP_USB     <= '0';
			SOFT_TRIG_MASK	<= (others=>'0');
			SOFT_TRIG_BIN  <=(others=>'0');
			SYNC_TRIG				<= '0';
			SYNC_MODE				<= '0';
			SYNC_TIME				<= '0';
			SYNC_RESET				<= '0';
			RBUSY 		   <= '1';
--------------------------------------------------------------------------------				
			case	state is	
--------------------------------------------------------------------------------
				when st1_WAIT =>
					RBUSY <= '0';						 
					if xFLAGA = '1' then	
						RBUSY <= '1';
						if xWBUSY = '0' then		
							RBUSY <= '1';
							state <= st1_READ;
						end if;
					end if;		 
--------------------------------------------------------------------------------		
				when st1_READ =>
					FIFOADR <= "00";	
					TOGGLE <= '1';		
					if delay = 2 then
						delay := 0;
						state <= st2_READ;
					else
						delay := delay +1;
					end if;
--------------------------------------------------------------------------------					
				when st2_READ =>	
					FIFOADR <= "00";
					TOGGLE <= '1';
					SLOE <= '0';
					if delay = 2 then
						delay := 0;
						state <= st3_READ;
					else
						delay := delay +1;
					end if;				
--------------------------------------------------------------------------------						
				when st3_READ =>					
					FIFOADR <= "00";
					TOGGLE <= '1';
					SLOE <= '0';
					SLRD <= '0';
					dbuffer <= xUSB_DATA;
					if delay = 2 then
						delay := 0;
						state <= st4_READ;
					else
						delay := delay +1;
					end if;					
--------------------------------------------------------------------------------					   
				when st4_READ =>					
					FIFOADR <= "00";
					TOGGLE <= '1';
					SLOE <= '0';
					if delay = 2 then
						delay := 0;
						state <= st1_SAVE;
					else
						delay := delay +1;
					end if;				
--------------------------------------------------------------------------------	
				when st1_SAVE	=>
					FIFOADR <= "00";
					TOGGLE <= '1';	
--------------------------------------------------------------------------------						
					case again is 
						when "00" =>	
							again <="01";	
							Locmd <= dbuffer;
							state <= ENDDELAY;
--------------------------------------------------------------------------------	
						when "01" =>
							again <="00";	
							Hicmd <= dbuffer;	
							state <= st1_TARGET;
--------------------------------------------------------------------------------	
						when others =>				
							state <= st1_WAIT;
					end case;
--------------------------------------------------------------------------------	
				when st1_TARGET =>
					RBUSY <= '0';
					--specifies which board(s) to send instruction
					INSTRUCT_MASK <= Hicmd(12 downto 9); 
					---------------------------------------------------------
					case Hicmd(3 downto 0) is
						when x"F" =>	--USE SYNC signal
							SYNC_USB <= Locmd(0); 
							state <= st1_WAIT;		
							
						when x"E" =>	--SOFT_TRIG
							cc_only_instruct_rdy <= '1';
							SYNC_TRIG <= '1';
							SOFT_TRIG <= '1';	 
							SOFT_TRIG_MASK <= Locmd(3 downto 0);
							SOFT_TRIG_BIN	<= Locmd(6 downto 4);
							if delay > 8 then
								delay := 0;
								state <= st1_WAIT;
							else
								delay := delay + 1;
							end if;		
						
						when x"D" =>
							ALIGN_LVDS <= '1';	 		
							state <= st1_WAIT;		
							
						when x"C" =>
							CC_READ_MODE <= Locmd(2 downto 0);
							if Locmd(4) = '1' then
								TRIG_MODE <= Locmd(3);
								TRIG_DELAY  (6 downto 0) <= Locmd(11 downto 5);
								TRIG_SOURCE (2 downto 0) <= Locmd(14 downto 12);
							end if;
						
							--CC_INSTRUCTION <= Hicmd & Locmd;
							--CC_INSTRUCTION <= (others => '0');
							--CC_INSTRUCT_RDY<= '1';
							if delay > 10 then
								delay := 0;
								state <= st1_WAIT;
								
						
							--this is a bad hack:
							-- basically, only want to send along to AC/DC if certain conditions apply
							-- also want to only read CC info buffer if read mode = 0b101
							else
								delay := delay + 1;
								if delay > 1 then
									case CC_READ_MODE is
										when "101" =>
											trig_valid <= trig_valid;
											--cc_only_instruct_rdy <= '0';
											read_cc_buffer <= '1';
											CC_SYNC <='0';
											CC_INSTRUCTION <= (others=>'0');
											SYNC_MODE <= '0';
											CC_INSTRUCT_RDY<= '0';
										when "110" =>
											trig_valid <= trig_valid;
											--cc_only_instruct_rdy <= '0';
											read_cc_buffer <= '0';
											CC_SYNC <= Locmd(14);
											CC_INSTRUCTION <= (others=>'0');
											--SYNC_MODE <= '0';
											CC_INSTRUCT_RDY<= '0';
										---only send-along data to AC/DC cards when 111 or 000
										when "111" =>	
											trig_valid <= '1';
											--cc_only_instruct_rdy <= '1';
											--SYNC_MODE <= '1';
											read_cc_buffer <= '0';
											CC_SYNC <='0';
											CC_INSTRUCTION <= Hicmd & Locmd;
											CC_INSTRUCT_RDY<= '1';
										when "000" =>
											trig_valid <= '0';
											--cc_only_instruct_rdy <= '1';
											SYNC_MODE <= '1';
											read_cc_buffer <= '0';
											CC_SYNC <='0';
											CC_INSTRUCTION <= Hicmd & Locmd;
											CC_INSTRUCT_RDY<= '1';
										------
										when others =>
											trig_valid <= trig_valid;
											SYNC_MODE <= '0';
											--cc_only_instruct_rdy <= '0';
											read_cc_buffer <= '0';
											CC_SYNC <=CC_SYNC;
											CC_INSTRUCTION <= (others=>'0');
											CC_INSTRUCT_RDY<= '0';
									end case;
								end if;
							end if;
						
										
						when x"B" =>
							--cc_only_instruct_rdy <= '1';
							--SYNC_RESET <= '1';
							CC_SOFT_DONE <= Locmd(0);
							CC_INSTRUCTION <= Hicmd & Locmd;
							CC_INSTRUCT_RDY<= '1';
							if delay > 5 then
								delay := 0;
								state <= st1_WAIT;
							else
								delay := delay + 1;
							end if;					
						
						when x"4" =>
							--hard reset conditions
							case Locmd(11 downto 0) is
								when x"FFF" =>
									cc_only_instruct_rdy <= '1';
									--SYNC_TRIG  <= '1';
									ALIGN_LVDS <= '1';
									SOFT_TRIG  <= '1';
									SOFT_TRIG_MASK <= "1111";
									HARD_RESET <= '1';
									WAKEUP_USB <= '0';
								when x"EFF" =>
									cc_only_instruct_rdy <= '0';
									--SYNC_TRIG  <= '0';
									ALIGN_LVDS <= '0';
									SOFT_TRIG  <= '0';
									SOFT_TRIG_MASK <= "0000";
									HARD_RESET <= '0';
									WAKEUP_USB <= '1';
								when others=>
									--SYNC_TRIG  <= '0';
									cc_only_instruct_rdy <= '0';
									ALIGN_LVDS <= '0';
									SOFT_TRIG  <= '0';
									SOFT_TRIG_MASK <= "0000";
									HARD_RESET <= '0';
									WAKEUP_USB <= '0';
							end case;
							
							--otherwise, send instructions over SERDES
							case Locmd(15 downto 12) is
								when x"1" =>
									--cc_only_instruct_rdy <= '1';
									--SYNC_TIME <= '1';
									RESET_DLL_FLAG <= '1';
								when x"3" => 
									--cc_only_instruct_rdy <= '1';
									--SYNC_TIME <= '1';
									RESET_DLL_FLAG <= '1';
								when x"F" =>
									--cc_only_instruct_rdy <= '1';
									--SYNC_TIME <= '1';
									RESET_DLL_FLAG <= '1';
								when others =>
									--SYNC_TIME <= '0';
									RESET_DLL_FLAG <= '0';
							end case;	
							
							CC_INSTRUCTION <= Hicmd & Locmd;
							CC_INSTRUCT_RDY<= '1';
							
							if delay > 20 then
								delay := 0;
								state <= st1_WAIT;
							else
								delay := delay + 1;
							end if;	
				
						when others =>
							CC_INSTRUCTION <= Hicmd & Locmd;
							CC_INSTRUCT_RDY<= '1';
							if delay > 8 then
								delay := 0;
								state <= st1_WAIT;
							else
								delay := delay + 1;
							end if;
							
					end case;
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------	
				when ENDDELAY =>	
					FIFOADR <= "00"; 
					if delay > 1 then
						if xFLAGA = '1' then
							delay := 0;
							state <= st1_READ;
						else
							delay := 0;
							state <= st1_WAIT;
						end if;
					else
						delay := delay +1;
					end if;
--------------------------------------------------------------------------------						
				when others =>
					state <= st1_WAIT;
			end case;	  
		end if;
	end process;
--------------------------------------------------------------------------------	
end Behavioral;
