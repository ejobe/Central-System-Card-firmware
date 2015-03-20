--------------------------------------------------
-- University of Chicago
-- LAPPD system firmware
--------------------------------------------------
-- module		: 	DC_lvds_com
-- author		: 	ejo
-- date			: 	6/2012
-- description	:  lvds xfer manager CC side
--------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Definition_Pool.all;

entity DC_lvds_com is
	port(
		xCLR_ALL				: in	std_logic;
		xALIGN_ACTIVE		: in	std_logic;
		xALIGN_SUCCESS 	: out	std_logic;
		
		xCLK_40MHz			: in	std_logic;
		xCLK_FASTER			: in	std_logic;
		
		xRX_LVDS_DATA		: in	std_logic_vector(1 downto 0);
		xTX_LVDS_DATA		: out	std_logic;
		
		xCC_INSTRUCTION	: in	std_logic_vector(31 downto 0);
		xCC_INSTRUCT_RDY	: in	std_logic;
		xSOFT_TRIGGER		: in	std_logic;
		xHARD_TRIGGER		: in	std_logic;
		xCC_SEND_TRIGGER	: out	std_logic;
		
		xRAM_RD_EN			: in	std_logic;
		xRAM_ADDRESS		: in	std_logic_vector(14 downto 0);
		xRAM_CLK				: in	std_logic;		--slwr from USB	
		xRAM_STOP_ADRS		: out	std_logic_vector(15 downto 0);
		xRAM_FULL_FLAG		: out	std_logic;
		xRAM_DATA			: out	std_logic_vector(15 downto 0);
		xALIGN_INFO			: out std_logic_vector(2 downto 0);
		xCATCH_DC_PKT		: out std_logic;
		
		xUSB_DONE			: in	std_logic;
		xDC_MASK				: in	std_logic;
		xPLL_LOCKED			: in	std_logic;
		xDC_ALIGN_SUCCESS	: in	std_logic;
		xTRIG_MODE			: in	std_logic;
		xSOFT_RESET			: in  std_logic);
		
end DC_lvds_com;

architecture Behavioral of DC_lvds_com is

type 	LVDS_ALIGN_TYPE_1 is (CHECK_1, DOUBLE_CHECK_1, INCREMENT_1,  
								    ALIGN_DONE_1);
type 	LVDS_ALIGN_TYPE_2 is (CHECK_2, DOUBLE_CHECK_2, INCREMENT_2,  
								    ALIGN_DONE_2);
signal LVDS_ALIGN_STATE_1			: LVDS_ALIGN_TYPE_1;
signal LVDS_ALIGN_STATE_2			: LVDS_ALIGN_TYPE_2;

--type 	SEND_CC_INSTRUCT_TYPE is (IDLE, SEND_START_WORD, CATCH0, CATCH1, CATCH2, CATCH3, READY);
type 	SEND_CC_INSTRUCT_TYPE is (IDLE, SEND_START_WORD, SEND_START_WORD_2, CATCH0, CATCH1, CATCH2, CATCH3, READY);
signal SEND_CC_INSTRUCT_STATE	:	SEND_CC_INSTRUCT_TYPE;

type LVDS_GET_DATA_STATE_TYPE	is (MESS_IDLE, GET_DATA, MESS_END, GND_STATE);
signal LVDS_GET_DATA_STATE		:  LVDS_GET_DATA_STATE_TYPE;		

signal RX_ALIGN_BITSLIP			:	std_logic_vector(1 downto 0);
signal RX_DATA						:	std_logic_vector(15 downto 0);
signal CHECK_WORD_1				:	std_logic_vector(7 downto 0);
signal CHECK_WORD_2				:	std_logic_vector(7 downto 0);
signal TX_DATA						: 	std_logic_vector(7 downto 0);
signal ALIGN_SUCCESS				:  std_logic_vector(1 downto 0) := "00";
signal ALIGN_SUCCESSES			:  std_logic;
signal GOOD_DATA					:  std_logic_vector(7 downto 0);

signal INSTRUCT_READY			:	std_logic;

signal RX_OUTCLK					: 	std_logic;

signal WRITE_CLOCK				:	std_logic;
signal WRITE_ENABLE				:	std_logic;
signal WRITE_ENABLE_TEMP		:	std_logic;
signal RAM_FULL_FLAG				:	std_logic;
signal CHECK_RX_DATA				:	std_logic_vector(15 downto 0);
signal RX_DATA_TO_RAM			:	std_logic_vector(15 downto 0);
signal WRITE_COUNT				: 	std_logic_vector(15 downto 0);
signal WRITE_ADDRESS				:	std_logic_vector(14 downto 0);
signal WRITE_ADDRESS_TEMP		:	std_logic_vector(14 downto 0);
signal LAST_WRITE_ADDRESS		:	std_logic_vector(14 downto 0) := (others=>'0');

signal START_WRITE				:	std_logic;
signal STOP_WRITE					:	std_logic;

signal SOFT_TRIG					: 	std_logic;
signal SOFT_TRIG_TEMP			: 	std_logic;
signal HARD_TRIG					:	std_logic;
signal HARD_TRIG_TEMP			:	std_logic;

component cc_lvds_tranceivers
	port (
			TX_DATA			: in	std_logic_vector(7 downto 0);
			TX_CLK			: in	std_logic;
			RX_ALIGN			: in	std_logic_vector(1 downto 0);
			RX_LVDS_DATA	: in	std_logic_vector(1 downto 0);
			RX_CLK			: in	std_logic;
			TX_LVDS_DATA	: out	std_logic;
			RX_DATA			: out	std_logic_vector(15 downto 0);
			TX_OUTCLK		: out	std_logic;
			RX_OUTCLK		: out std_logic);
end component;

component CC_lvds_RAM
	port (
			xDATA				: in	std_logic_vector(15 downto 0);
			xWR_ADRS			: in	std_logic_vector(14 downto 0);
			xWR_EN			: in	std_logic;
			xRD_ADRS			: in	std_logic_vector(14 downto 0);
			xRD_EN			: in	std_logic;
			xRD_CLK			: in	std_logic;
			xWR_CLK			: in	std_logic;
			xRAM_DATA		: out	std_logic_vector(15 downto 0));
end component;

begin

xALIGN_INFO       <= ALIGN_SUCCESS(0) & ALIGN_SUCCESS(1) & xDC_ALIGN_SUCCESS;
ALIGN_SUCCESSES	<= ALIGN_SUCCESS(0) and ALIGN_SUCCESS(1) and xDC_ALIGN_SUCCESS;
xALIGN_SUCCESS 	<= ALIGN_SUCCESSES;
WRITE_CLOCK			<= RX_OUTCLK;
xRAM_FULL_FLAG		<= RAM_FULL_FLAG;
--SOFT_TRIG			<= xSOFT_TRIGGER;
--HARD_TRIG			<= xHARD_TRIGGER;
xCC_SEND_TRIGGER	<= (xSOFT_TRIGGER and (not xTRIG_MODE)) or xHARD_TRIGGER;
xCATCH_DC_PKT     <= START_WRITE; 


--bitslip RX align process
process(xCLK_40MHz, xALIGN_ACTIVE, xCLR_ALL)
variable i : integer range 5 downto 0;	
variable j : integer range 5 downto 0;	
begin
	if xCLR_ALL = '1' then
		ALIGN_SUCCESS <= "00";
		TX_DATA <= (others=>'0');
		LVDS_ALIGN_STATE_1 <= CHECK_1;
		LVDS_ALIGN_STATE_2 <= CHECK_2;
		RX_ALIGN_BITSLIP <= "00";
		i := 0;
		j := 0;
	elsif falling_edge(xCLK_40MHz) and xALIGN_ACTIVE = '1' and xPLL_LOCKED = '1' then
		TX_DATA <= ALIGN_WORD_8;
		--LVDS_ALIGN_STATE_1 <= CHECK_1;
		--LVDS_ALIGN_STATE_2 <= CHECK_2;
		
		case LVDS_ALIGN_STATE_1 is
				
				when CHECK_1 =>
					RX_ALIGN_BITSLIP(0) <= '0';
					CHECK_WORD_1 <= RX_DATA(7 downto 0);
					if CHECK_WORD_1 = ALIGN_WORD_8 then
						i := 0;
						LVDS_ALIGN_STATE_1 <= DOUBLE_CHECK_1;

					else
						ALIGN_SUCCESS(0) <= '0';
						i := i + 1;
						if i > 3 then
							i := 0;
							LVDS_ALIGN_STATE_1 <= INCREMENT_1;
						end if;
					end if;
				
				when  DOUBLE_CHECK_1 =>
					CHECK_WORD_1 <= RX_DATA(7 downto 0);
					if CHECK_WORD_1 = ALIGN_WORD_8 then
						LVDS_ALIGN_STATE_1 <= ALIGN_DONE_1;

					else
						i := i + 1;
						if i > 3 then
							i := 0;
							LVDS_ALIGN_STATE_1 <= CHECK_1;
						end if;
					end if;
				
				when INCREMENT_1 =>
					i := i+1;
					RX_ALIGN_BITSLIP(0) <= '1';
					if i > 1 then
						i := 0;
						RX_ALIGN_BITSLIP(0) <= '0';
						LVDS_ALIGN_STATE_1 <= CHECK_1;
					end if;
										
				when ALIGN_DONE_1 =>
					ALIGN_SUCCESS(0) <= '1';
					LVDS_ALIGN_STATE_1 <= CHECK_1;
		end case;

		case LVDS_ALIGN_STATE_2 is
				
				when CHECK_2 =>
					RX_ALIGN_BITSLIP(1) <= '0';
					CHECK_WORD_2 <= RX_DATA(15 downto 8);
					if CHECK_WORD_2 = ALIGN_WORD_8 then
						LVDS_ALIGN_STATE_2 <= DOUBLE_CHECK_2;

					else
						ALIGN_SUCCESS(1) <= '0';
						j := j + 1;
						if j > 3 then
							j := 0;
							LVDS_ALIGN_STATE_2 <= INCREMENT_2;
						end if;
					end if;
				
				when  DOUBLE_CHECK_2 =>
					CHECK_WORD_2 <= RX_DATA(15 downto 8);
					if CHECK_WORD_2 = ALIGN_WORD_8 then
						LVDS_ALIGN_STATE_2 <= ALIGN_DONE_2;

					else
						j := j + 1;
						if j > 3 then
							j := 0;
							LVDS_ALIGN_STATE_2 <= CHECK_2;
						end if;
					end if;
				
				when INCREMENT_2 =>
					j := j+1;
					RX_ALIGN_BITSLIP(1) <= '1';
					if j > 1 then
						j := 0;
						RX_ALIGN_BITSLIP(1) <= '0';
						LVDS_ALIGN_STATE_2 <= CHECK_2;
					end if;
										
				when ALIGN_DONE_2=>
					ALIGN_SUCCESS(1) <= '1';
					LVDS_ALIGN_STATE_2 <= CHECK_2;
		end case;
				
	elsif falling_edge(xCLK_40MHz) and ALIGN_SUCCESS(0) = '1' 
			and ALIGN_SUCCESS(1) = '1' and xALIGN_ACTIVE = '0' then
		TX_DATA <= GOOD_DATA;
		--LVDS_ALIGN_STATE_1 <= CHECK_1;
		--LVDS_ALIGN_STATE_2 <= CHECK_2;
	end if;
end process;

process(xCLK_40MHz, ALIGN_SUCCESSES, xDC_MASK, xCLR_ALL)
variable i : integer range 50 downto 0;	
begin
	if xCLR_ALL = '1' or xCC_INSTRUCT_RDY = '0' then
		--CC_INSTRUCTION <= (others=>'0');
		INSTRUCT_READY <= '0';
		i := 0;
		GOOD_DATA <= (others=>'0');
		SEND_CC_INSTRUCT_STATE <= IDLE;
		
	elsif rising_edge(xCLK_40MHz) and ALIGN_SUCCESSES = '1' and xCC_INSTRUCT_RDY = '1' and xDC_MASK = '1' then
		case SEND_CC_INSTRUCT_STATE is
			
			when IDLE =>
				i := 0;
				INSTRUCT_READY <= '0';
				--if xCC_INSTRUCT_RDY = '1' then
				SEND_CC_INSTRUCT_STATE <= SEND_START_WORD;       
				--end if;
			--send 32 bit word 8 bits at a time	
			when SEND_START_WORD =>
				GOOD_DATA <= STARTWORD_8a;
				--SEND_CC_INSTRUCT_STATE <= CATCH0;
				SEND_CC_INSTRUCT_STATE <= SEND_START_WORD_2;
			when SEND_START_WORD_2 =>
				GOOD_DATA <= STARTWORD_8b;
				SEND_CC_INSTRUCT_STATE <= CATCH0;
			when CATCH0 =>
				GOOD_DATA <= xCC_INSTRUCTION(31 downto 24);
				SEND_CC_INSTRUCT_STATE <= CATCH1;
			when CATCH1 =>
				GOOD_DATA <= xCC_INSTRUCTION(23 downto 16);
				SEND_CC_INSTRUCT_STATE <= CATCH2;
			when CATCH2 =>
				GOOD_DATA <= xCC_INSTRUCTION(15 downto 8);  
				SEND_CC_INSTRUCT_STATE <= CATCH3;
			when CATCH3 =>
				GOOD_DATA <= xCC_INSTRUCTION(7 downto 0);
				SEND_CC_INSTRUCT_STATE <= READY;
				
			when READY =>
				GOOD_DATA <= (others=>'0');
				INSTRUCT_READY <= '1';
				--i := i + 1;
				--if i = 10 then
				--	i := 0;
				--	SEND_CC_INSTRUCT_STATE <= IDLE;
				--end if;
		end case;
	end if;
end process;

--look for start/stop word to write lvds data to CC ram.
process(WRITE_CLOCK, xCLR_ALL, RX_DATA)
begin
	if xCLR_ALL = '1' or xUSB_DONE = '1' or xSOFT_RESET = '1' then
		START_WRITE <= '0';
		STOP_WRITE	<= '0';
	elsif falling_edge(WRITE_CLOCK) and ALIGN_SUCCESSES = '1' 
		and xALIGN_ACTIVE = '0' then
		CHECK_RX_DATA <= RX_DATA;
		if CHECK_RX_DATA = STARTWORD then
			START_WRITE <= '1';
		elsif CHECK_RX_DATA = ENDWORD then
			STOP_WRITE <= '1';
		end if;
	end if;
end process;

process(WRITE_CLOCK, xCLR_ALL, xUSB_DONE)
begin
	if xCLR_ALL ='1' or xUSB_DONE = '1' or ALIGN_SUCCESSES = '0' or xSOFT_RESET = '1' then
		WRITE_ENABLE_TEMP <= '0';
		WRITE_ENABLE		<= '0';
		WRITE_COUNT			<= (others=>'0');
		WRITE_ADDRESS_TEMP<= (others=>'0');
		WRITE_ADDRESS		<= (others=>'0');
		LAST_WRITE_ADDRESS<= (others=>'0');
		RX_DATA_TO_RAM		<= (others=>'0') ;
		RAM_FULL_FLAG		<=	'0';
		LVDS_GET_DATA_STATE <= MESS_IDLE;
	elsif rising_edge(WRITE_CLOCK) and START_WRITE = '1' then
		case LVDS_GET_DATA_STATE is
			
			when MESS_IDLE =>
				WRITE_ENABLE_TEMP <= '1' ;
				LVDS_GET_DATA_STATE <= GET_DATA;
				
			when GET_DATA =>
				RX_DATA_TO_RAM <= RX_DATA;
				WRITE_COUNT		<= WRITE_COUNT + 1;
				WRITE_ADDRESS_TEMP <= WRITE_ADDRESS_TEMP + 1;
				--if STOP_WRITE = '1' or WRITE_COUNT > 4094 then
				if WRITE_COUNT > 7998 then
					WRITE_ENABLE_TEMP <= '0';
					LAST_WRITE_ADDRESS <= WRITE_ADDRESS_TEMP;
					LVDS_GET_DATA_STATE<= MESS_END;
				end if;
			
			when MESS_END =>
				RAM_FULL_FLAG <= '1';
				LVDS_GET_DATA_STATE<= GND_STATE;
				
			when GND_STATE =>
				WRITE_ADDRESS_TEMP <= (others=>'0');
		end case;
					
	elsif falling_edge(WRITE_CLOCK) and START_WRITE = '1' 
						and STOP_WRITE = '0' then
		WRITE_ADDRESS 	<= WRITE_ADDRESS_TEMP;
		WRITE_ENABLE 	<= WRITE_ENABLE_TEMP;	
	end if;
end process;


xCC_lvds_tranceivers : cc_lvds_tranceivers
port map(
			TX_DATA			=>		TX_DATA,
			TX_CLK			=>		xCLK_40MHz,
			RX_ALIGN			=>		RX_ALIGN_BITSLIP,
			RX_LVDS_DATA	=>		xRX_LVDS_DATA,
			RX_CLK			=>		xCLK_40MHz,
			TX_LVDS_DATA	=>		xTX_LVDS_DATA,
			RX_DATA			=>		RX_DATA,
			TX_OUTCLK		=>		open,
			RX_OUTCLK		=>		RX_OUTCLK);	
			
xCC_lvds_RAM	:	CC_lvds_RAM
port map(
			xDATA				=>			RX_DATA_TO_RAM,
			xWR_ADRS			=>			WRITE_ADDRESS,
			xWR_EN			=>			WRITE_ENABLE,
			xRD_ADRS			=>			xRAM_ADDRESS,
			xRD_EN			=>			xRAM_RD_EN,
			xRD_CLK			=>			xRAM_CLK,
			xWR_CLK			=>			WRITE_CLOCK,
			xRAM_DATA		=>			xRAM_DATA);
			
end Behavioral;
