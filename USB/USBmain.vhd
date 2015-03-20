---usb main
---e oberla april 2010
------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Definition_Pool.all;

entity USBmain is
	port( 
		IFCLK						: 	in		std_logic;
		WAKEUP					:	in 	std_logic;
		CTL     					:	in		std_logic_vector(2 downto 0);
		PA							: 	inout std_logic_vector(7 downto 0);
		
		CLKOUT					:	in		std_logic;
		xUSB_START				:	in		std_logic_vector(3 downto 0);
		xRESET					: 	in		std_logic;
		FD							:	inout	std_logic_vector(15 downto 0);
		RDY						:	out	std_logic_vector(1 downto 0);
		xUSB_DONE				:	out	std_logic_vector(3 downto 0);
		xSOFT_TRIG				:	out	std_logic_vector(3 downto 0);
		xALIGN_LVDS				:	out	std_logic;
		xSET_DC_MASK			:	out	std_logic_vector(3 downto 0);
		xSLWR						:	out	std_logic;
		
		xCLR_ALL					: 	in   	std_logic;
		
		xADC						: 	in   	CCData_array;
		xLAST_RD_ADR			: 	in	 	CCData_array;
		xTRIG_CLK				: 	in		std_logic;
		xALIGN_STAT 			: 	in		std_logic_vector(3 downto 0);
		
		xCLK_SYS					: 	in		std_logic;
		xRADDR					: 	out 	std_logic_vector (14 downto 0);
		xRAM_EN					: 	out	std_logic_vector (3 downto 0);
		
		xCC_INFO_0				: 	in		std_logic_vector(15 downto 0);
		xCC_INFO_1				: 	in 	std_logic_vector(15 downto 0);
		xCC_INFO_2				: 	in		std_logic_vector(15 downto 0);
		xCC_INFO_3				: 	in 	std_logic_vector(15 downto 0);
		xCC_INFO_4				: 	in 	std_logic_vector(15 downto 0);
		xCC_INFO_5				: 	in		std_logic_vector(15 downto 0);
		xCC_INFO_6				: 	in 	std_logic_vector(15 downto 0);
		xCC_INFO_7				: 	in 	std_logic_vector(15 downto 0);
		xCC_INFO_8				: 	in		std_logic_vector(15 downto 0);
		xCC_INFO_9				: 	in 	std_logic_vector(15 downto 0);
		
		xALIGN_INFO          :  in		std_logic_vector(11 downto 0);
		xDC_PKT					:  in		std_logic_vector(3 downto 0);
		xCC_SYNC_IN				:  in		std_logic;
				
		xDIGITIZING_FLAG_0  	:  in		std_logic;
		xDIGITIZING_FLAG_1  	:  in		std_logic;
		xDIGITIZING_FLAG_2  	:  in		std_logic;
		xDIGITIZING_FLAG_3  	:  in		std_logic;
		
		xCC_INSTRUCTION 		: 	out	std_logic_vector(31 downto 0);
		xINSTRUCT_RDY			: 	out	std_logic;
		xCC_READ_MODE			: 	out 	std_logic_vector(2 downto 0);
		xSET_TRIG_MODE			: 	out 	std_logic;
		xCC_SOFT_FIFO_MANAGE : 	out	std_logic;
		
		xUSBUSY					: 	out  	std_logic;
		xTRIG_DELAY 			: 	out  	std_logic_vector(6 downto 0);
		xRESET_TIMESTAMP 		: 	out  	std_logic;
		xSET_TRIG_SOURCE  	:  out 	std_logic_vector( 2 downto 0);
		xHARD_RESET       	: 	out 	std_logic;
		xWAKEUP_USB				:  out   std_logic;
		xCC_SYNC_OUT			:  out	std_logic;
		xTRIG_VALID				: 	out	std_logic;
	   xSOFT_TRIG_BIN			: out		std_logic_vector(2 downto 0));

		
end USBmain;
		
architecture BEHAVIORAL of USBmain is

	type 	ALIGN_LVDS_TYPE	is (RESETT, RELAXT);
	signal	ALIGN_LVDS_STATE:	ALIGN_LVDS_TYPE;
	
	type 	WAKEUP_USB_STATE_TYPE	is (RESETT, RELAXT);
	signal	WAKEUP_USB_STATE:	WAKEUP_USB_STATE_TYPE;
-----signals-----------		
	signal SYNC_USB				: 	std_logic;
	signal WBUSY					:	std_logic;
	signal RBUSY					:	std_logic;
	signal TOGGLE					:	std_logic;
	signal USB_DATA				:	std_logic_vector(15 downto 0);
	signal USB_START				:  std_logic;
	signal USB_START_MASK 		:  std_logic_vector(3 downto 0);
	signal CC_USB_START			:  std_logic;
	signal SLWR						:	std_logic;
	signal FPGA_DATA				:	std_logic_vector(15 downto 0);
	signal usb_done				: 	std_logic;
	signal CC_READ_MODE			:	std_logic_vector(2 downto 0);
	signal CC_INSTRUCT_RDY 		: std_logic;
	signal NUM_USB_SAMPLES_IN_PACKET	:	std_logic_vector(19 downto 0);
	
	signal ALIGN_LVDS_FLAG		:	std_logic;
	signal ALIGN_LVDS_FROM_SOFTWARE : std_logic := '0';
	signal ALIGN_LVDS_COUNT				: std_logic := '1';
	signal read_cc_buffer		: std_logic;		
	signal WAKEUP_USB				: std_logic;
	signal RESET_USB_FROM_SOFTWARE : std_logic;
	signal WAKEUP_USB_DONE		: std_logic;
	signal SET_TRIG_SOURCE		: std_logic_vector(2 downto 0);

-----components--------
	
	component IO16
		port( 	
				xTOGGLE	:	in		std_logic;
				FDIN		:	in		std_logic_vector(15 downto 0);
				FD			:	inout	std_logic_vector(15 downto 0);
				FDOUT		:	out	std_logic_vector(15 downto 0));
	end component;	
	
	component USBread
		port( 
			xIFCLK     		: in    std_logic;
			xUSB_DATA  		: in    std_logic_vector (15 downto 0);
			xFLAGA    		: in    std_logic;
			xRESET    		: in    std_logic;
			xWBUSY    		: in    std_logic;
			xCLK40					: in		std_logic;
			xCC_SYNC_IN			: in		std_logic;
			xCC_SYNC_OUT			: out		std_logic;
			xFIFOADR  		: out   std_logic_vector (1 downto 0);
			xRBUSY    		: out   std_logic;
			xSLOE     		: out   std_logic;
			xSLRD     		: out   std_logic;
			xSYNC_USB 		: out   std_logic;
			xSOFT_TRIG		: out   std_logic_vector(3 downto 0);
			xSOFT_TRIG_BIN		: out		std_logic_vector(2 downto 0);
			xALIGN			: out		std_logic;
			xCC_INSTRUCTION: out		std_logic_vector(31 downto 0);
			xCC_INSTRUCT_RDY:out		std_logic;
			xCC_READ_MODE	: out		std_logic_vector(2 downto 0);
			xTRIG_MODE		: out		std_logic;
			xTRIG_DELAY		: out		std_logic_vector(6 downto 0);
			xCC_SOFT_DONE 	: out	std_logic;
			xTOGGLE   		: out   std_logic;
			xRESET_TIMESTAMP 	: out  std_logic;
			xREAD_CC_BUFFER	: out  std_logic;
			xTRIG_SOURCE      : out  std_logic_vector(2 downto 0);
			xINSTRUCT_MASK		: out std_logic_vector(3 downto 0);
			xHARD_RESET         : out 	std_logic;
			xWAKEUP_USB				: out std_logic;
			xTRIG_VALID			: out		std_logic);
	end component;
	
	component USBwrite
		port ( 
			xIFCLK    : in    std_logic;
			xFLAGB    : in    std_logic;	
			xFLAGC    : in    std_logic;	
			xRBUSY    : in    std_logic;	
			xRESET    : in    std_logic;	
			xSTART    : in    std_logic;	
			xSYNC_USB : in    std_logic; 
			xNUM_SAMPLES:in	std_logic_vector(19 downto 0);
			xDONE     : out   std_logic; 	
			xPKTEND   : out   std_logic;	
			xSLWR     : out   std_logic;	
			xWBUSY    : out   std_logic);	
     end component;
    
    component MESS
		port(
			 xSLWR				: in   std_logic;
			 xSTART		 		: in   std_logic;
			 xRAM_FULL			: in 	std_logic_vector(3 downto 0);
			 xSTART_VEC			: in	 std_logic_vector(3 downto 0);
			 xCC_ONLY_START	: in	std_logic;
			 xALIGN_STATUS 	: in	std_logic_vector(3 downto 0);
			 xALIGN_INFO   	: in  std_logic_vector(11 downto 0);
			 xDONE		 		: in   std_logic;
			 xCLR_ALL	 		: in   std_logic;
			 xADC					: in   CCData_array;
			 xCC_READ_MODE		: in	std_logic_vector(2 downto 0);
			 xNUM_USB_SAMPLES	: in	std_logic_vector(19 downto 0);
			 xCC_INFO_0			: in	std_logic_vector(15 downto 0);
			 xCC_INFO_1			: in 	std_logic_vector(15 downto 0);
			 xCC_INFO_2			: in	std_logic_vector(15 downto 0);
			 xCC_INFO_3			: in 	std_logic_vector(15 downto 0);
			 xCC_INFO_4			: in 	std_logic_vector(15 downto 0);
			 xCC_INFO_5			: in	std_logic_vector(15 downto 0);
			 xCC_INFO_6			: in 	std_logic_vector(15 downto 0);
			 xCC_INFO_7			: in 	std_logic_vector(15 downto 0);
			 xCC_INFO_8			: in	std_logic_vector(15 downto 0);
			 xCC_INFO_9			: in 	std_logic_vector(15 downto 0);
			 xDIGITIZING_FLAG_0  :  in		std_logic;
			 xDIGITIZING_FLAG_1  :  in		std_logic;
			 xDIGITIZING_FLAG_2  :  in		std_logic;
			 xDIGITIZING_FLAG_3  :  in		std_logic;
			 xFPGA_DATA     	: out  std_logic_vector (15 downto 0);
			 xLAST_RD_ADDR		: in	CCData_array;
			 xDC_PKT				: in	std_logic_vector(3 downto 0);
			 xTRIG_INFO			: in	std_logic_vector(2 downto 0);
			 xRADDR				: out  std_logic_vector (14 downto 0);
			 xRAM_READ_EN		: out	std_logic_vector(3 downto 0));
		end component;
-----------------------------
--begin-------
begin	
--------------	
	RDY(1) <= SLWR;
	xSLWR <= SLWR;
--	xUSB_DONE <= usb_done;
	xUSBUSY <= (WBUSY or RBUSY);
	xCC_READ_MODE <= CC_READ_MODE;
	xINSTRUCT_RDY <= CC_INSTRUCT_RDY;

--	xUSB_SYNC_MODE <= SYNC_USB;
	xALIGN_LVDS <= ALIGN_LVDS_FLAG or ALIGN_LVDS_FROM_SOFTWARE;
	
	xWAKEUP_USB <= not RESET_USB_FROM_SOFTWARE;
	xSET_TRIG_SOURCE <= SET_TRIG_SOURCE;
	
	
	
	process(usb_done, xUSB_START, CC_READ_MODE)
	begin
	if usb_done = '1' or xCLR_ALL = '1' then	
		USB_START <= '0';
		USB_START_MASK <= "0000";
	elsif (xUSB_START(0) = '1' and CC_READ_MODE = "001") or
			(xUSB_START(1) = '1' and CC_READ_MODE = "010") or
			(xUSB_START(2) = '1' and CC_READ_MODE = "011") or
			(xUSB_START(3) = '1' and CC_READ_MODE = "100") then	
			
				USB_START <= '1';
				
				if CC_READ_MODE = "001" then	
					USB_START_MASK <= "0001";
				
				elsif CC_READ_MODE = "010" then	
					USB_START_MASK <= "0010";
				
				elsif CC_READ_MODE = "011" then	
					USB_START_MASK <= "0100";
				
				elsif CC_READ_MODE = "100" then	
					USB_START_MASK <= "1000";
				
				else
					USB_START_MASK <= "0000";
				end if;

	else
		USB_START <= '0';
		USB_START_MASK <= "0000";
	end if;
	end process;
		
	
	process(usb_done, CC_READ_MODE)
	begin
		if usb_done = '0' then
			xUSB_DONE <= "0000";
		elsif usb_done = '1' then
			
			case CC_READ_MODE is
				when "001" =>
					xUSB_DONE <= "0001";
				when "010" =>
					xUSB_DONE <= "0010";
				when "011" =>
					xUSB_DONE <= "0100";
				when "100" =>
					xUSB_DONE <= "1000";
				when "101" =>
					xUSB_DONE <= "0000";  --CC only read mode, don't reset RAM buffers
				when others=>
					xUSB_DONE <= "0000";
			end case;
		end if;
	end process;
	
	process(CC_READ_MODE)
		begin
		case CC_READ_MODE is
			when "001" =>
				NUM_USB_SAMPLES_IN_PACKET <= x"01F40";   --standard DC read
			when "010" =>
				NUM_USB_SAMPLES_IN_PACKET <= x"01F40";	 --get DC info
			when "011" =>
				NUM_USB_SAMPLES_IN_PACKET <= x"01F40";	 	 --loopback test
			when "100" =>
				NUM_USB_SAMPLES_IN_PACKET <= x"01F40";		 
			when "101"=>
				NUM_USB_SAMPLES_IN_PACKET <= x"0001F";     --read CC info
			when others=>
				NUM_USB_SAMPLES_IN_PACKET <= x"01F40";
		end case;
	end process;
		
	process(read_cc_buffer, usb_done, xCLR_ALL)
		begin 
			if xCLR_ALL = '1' or usb_done = '1'  then
				CC_USB_START <= '0';
			elsif falling_edge(read_cc_buffer) and CC_READ_MODE = "101" then
				CC_USB_START <= '1';
			end if;
	end process;

	process(IFCLK, ALIGN_LVDS_FLAG)
		begin
			if xCLR_ALL = '1' then
				ALIGN_LVDS_FROM_SOFTWARE <= '0';
			elsif falling_edge(IFCLK) and (ALIGN_LVDS_COUNT = '0') then
				ALIGN_LVDS_FROM_SOFTWARE<= '0';
			elsif falling_edge(IFCLK) and ALIGN_LVDS_FLAG = '1' then
				ALIGN_LVDS_FROM_SOFTWARE <= '1';
			end if;
	end process;
	
	process(IFCLK, ALIGN_LVDS_FROM_SOFTWARE)
	variable i : integer range 100000002 downto 0 := 0;
		begin
			if rising_edge(IFCLK) and ALIGN_LVDS_FROM_SOFTWARE = '0' then
				i := 0;
				ALIGN_LVDS_STATE <= RESETT;
				ALIGN_LVDS_COUNT <= '1';
			elsif rising_edge(IFCLK) and ALIGN_LVDS_FROM_SOFTWARE  = '1' then
				case ALIGN_LVDS_STATE is
					when RESETT =>
						i:=i+1;
						if i > 100000000 then
							i := 0;
							ALIGN_LVDS_STATE <= RELAXT;
						end if;
						
					when RELAXT =>
						ALIGN_LVDS_COUNT <= '0';

				end case;
			end if;
	end process;
	
	process(IFCLK, WAKEUP_USB)
		begin
			if xCLR_ALL = '1' then
				RESET_USB_FROM_SOFTWARE <= '0';
			elsif falling_edge(IFCLK) and WAKEUP_USB_DONE = '0' then
				RESET_USB_FROM_SOFTWARE <= '0';
			elsif falling_edge(IFCLK) and WAKEUP_USB = '1' then
				RESET_USB_FROM_SOFTWARE <= '1';
			end if;
	end process;
	
	process(IFCLK, RESET_USB_FROM_SOFTWARE)
	variable i : integer range 100000008 downto 0 := 0;
		begin
			if rising_edge(IFCLK) and RESET_USB_FROM_SOFTWARE = '0' then
				i := 0;
				WAKEUP_USB_STATE <= RESETT;
				WAKEUP_USB_DONE <= '1';
			elsif rising_edge(IFCLK) and RESET_USB_FROM_SOFTWARE  = '1' then
				case WAKEUP_USB_STATE is
					when RESETT =>
						i:=i+1;
						if i > 100000000 then
							i := 0;
							WAKEUP_USB_STATE <= RELAXT;	
						end if;
					
					when RELAXT =>
						WAKEUP_USB_DONE <= '0';

				end case;
			end if;
	end process;
	IOBUF : IO16
	port map( 	xTOGGLE => TOGGLE,
				FDIN(15 downto 0)	=>  FPGA_DATA(15 downto 0),	
				FD(15 downto 0)		=>	FD(15 downto 0),
				FDOUT(15 downto 0)	=>	USB_DATA(15 downto 0));

	xUSBread : USBread
	port map(  	xIFCLK     		=> IFCLK,
				xUSB_DATA(15 downto 0)  => USB_DATA(15 downto 0),
				xFLAGA    		=> CTL(0),
				xRESET    		=> xRESET,
				xWBUSY    		=> WBUSY,
				xCLK40			=> xCLK_SYS,
			   xCC_SYNC_IN		=> xCC_SYNC_IN,
			   xCC_SYNC_OUT	=> xCC_SYNC_OUT,
				xFIFOADR(1 downto 0)	=> PA(5 downto 4),
				xRBUSY    		=> RBUSY,
				xSLOE     		=> PA(2),
				xSLRD     		=> RDY(0),
				xSYNC_USB 		=> SYNC_USB,
				xSOFT_TRIG		=> xSOFT_TRIG,
				xSOFT_TRIG_BIN	=> xSOFT_TRIG_BIN,	
				xALIGN			=> ALIGN_LVDS_FLAG,
				xCC_INSTRUCTION=> xCC_INSTRUCTION,
				xCC_INSTRUCT_RDY=> CC_INSTRUCT_RDY,
				xCC_READ_MODE  => CC_READ_MODE,
				xTRIG_MODE 		=> xSET_TRIG_MODE,
				xTRIG_DELAY    => xTRIG_DELAY,
				xCC_SOFT_DONE  => xCC_SOFT_FIFO_MANAGE,
				xTOGGLE   		=> TOGGLE,
				xRESET_TIMESTAMP => xRESET_TIMESTAMP,
				xREAD_CC_BUFFER  => read_cc_buffer,
			   xTRIG_SOURCE     => SET_TRIG_SOURCE,
			   xINSTRUCT_MASK	  => xSET_DC_MASK,
				xHARD_RESET      => xHARD_RESET,
				xWAKEUP_USB      => WAKEUP_USB,
				xTRIG_VALID			=> xTRIG_VALID);
				
	xUSBwrite : USBwrite
	port map(	xIFCLK    => IFCLK,
				xFLAGB    => CTL(1),	
				xFLAGC    => CTL(2),	
				xRBUSY    => RBUSY,	
				xRESET    => xRESET,	
				xSTART    => (USB_START or CC_USB_START),	 
				xSYNC_USB => SYNC_USB, 
				xNUM_SAMPLES=> NUM_USB_SAMPLES_IN_PACKET,
				xDONE     => usb_done, 	
				xPKTEND   => PA(6),	
				xSLWR     => SLWR,	
				xWBUSY    => WBUSY);
	
	xMESS	: MESS
	port map(
			 xSLWR			=> SLWR,
			 xSTART		 	=> USB_START,
			 xRAM_FULL		=> xUSB_START,
			 xSTART_VEC    => USB_START_MASK,
			 xCC_ONLY_START=> CC_USB_START,
			 xALIGN_STATUS => xALIGN_STAT,
			 xALIGN_INFO   => xALIGN_INFO,
			 xDONE		 	=> usb_done,
			 xCLR_ALL	 	=> xCLR_ALL,
			 xADC				=> xADC,
			 xCC_READ_MODE	=> CC_READ_MODE,
			 xNUM_USB_SAMPLES=>	NUM_USB_SAMPLES_IN_PACKET,
			 xCC_INFO_0		=> xCC_INFO_0,	 
			 xCC_INFO_1		=> xCC_INFO_1,		
			 xCC_INFO_2		=> xCC_INFO_2,		
			 xCC_INFO_3		=> xCC_INFO_3,	
			 xCC_INFO_4		=> xCC_INFO_4,			
			 xCC_INFO_5		=> xCC_INFO_5,				
			 xCC_INFO_6		=> xCC_INFO_6,				
			 xCC_INFO_7		=> xCC_INFO_7,				
			 xCC_INFO_8		=> xCC_INFO_8,				
			 xCC_INFO_9		=> xCC_INFO_9, 
			 xDIGITIZING_FLAG_0  => xDIGITIZING_FLAG_0,
			 xDIGITIZING_FLAG_1  => xDIGITIZING_FLAG_1,
			 xDIGITIZING_FLAG_2  => xDIGITIZING_FLAG_2,
			 xDIGITIZING_FLAG_3  => xDIGITIZING_FLAG_3,
			 xFPGA_DATA    => FPGA_DATA,
			 xLAST_RD_ADDR	=> xLAST_RD_ADR,
			 xDC_PKT			=> xDC_PKT,
 			 xTRIG_INFO		=> SET_TRIG_SOURCE,
			 xRADDR			=> xRADDR,
			 xRAM_READ_EN	=> xRAM_EN);
				
end BEHAVIORAL;