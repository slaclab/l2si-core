-------------------------------------------------------------------------------------
-- FILE NAME : parallel_flash_phy.vhd
--
-- AUTHOR    : Ingmar van Klink
--
-- COMPANY   : 4DSP
--
-- ITEM      : 1
--
-- UNITS     : Entity       - parallel_flash_phy
--             architecture - parallel_flash_phy_syn
--
-- LANGUAGE  : VHDL
--
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
--
-- parallel_flash_phy
-- Notes: parallel_flash_phy
-------------------------------------------------------------------------------------
--  Disclaimer: LIMITED WARRANTY AND DISCLAIMER. These designs are
--              provided to you as is.  4DSP specifically disclaims any
--              implied warranties of merchantability, non-infringement, or
--              fitness for a particular purpose. 4DSP does not warrant that
--              the functions contained in these designs will meet your
--              requirements, or that the operation of these designs will be
--              uninterrupted or error free, or that defects in the Designs
--              will be corrected. Furthermore, 4DSP does not warrant or
--              make any representations regarding use or the results of the
--              use of the designs in terms of correctness, accuracy,
--              reliability, or otherwise.
--
--              LIMITATION OF LIABILITY. In no event will 4DSP or its
--              licensors be liable for any loss of data, lost profits, cost
--              or procurement of substitute goods or services, or for any
--              special, incidental, consequential, or indirect damages
--              arising from the use or operation of the designs or
--              accompanying documentation, however caused and on any theory
--              of liability. This limitation will apply even if 4DSP
--              has been advised of the possibility of such damage. This
--              limitation shall apply not-withstanding the failure of the
--              essential purpose of any limited remedies herein.
--
----------------------------------------------

-- Library declarations
library ieee;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_misc.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;
library unisim;
  use unisim.vcomponents.all;

entity parallel_flash_phy is
port (
  -- Global signals
  rst                   : in  std_logic;
  init                  : in  std_logic;
  flash_clk             : in  std_logic;
  flash_cmd             : in  std_logic_vector(31 downto 0);
  flash_phy_busy        : out std_logic;
  flash_access_addr     : in  std_logic_vector(25 downto 0);
  burst_size_words      : in  std_logic_vector(25 downto 0);
  remainder_size_words  : in  std_logic_vector(7 downto 0); -- max 255 as page size is 512 byte
  --Input ports for spi programming data
  data_in_ack       : out std_logic;
  data_in_val       : in  std_logic;
  data_in           : in  std_logic_vector(15 downto 0);

  --Output ports for spi programming data readback
  data_out_fifo_aff : in  std_logic;
  data_out_dval     : out std_logic;
  data_out_data     : out std_logic_vector(15 downto 0);
                          
  --External signals
  flash_address     : out   std_logic_vector(25 downto 0);
  flash_data_o      : out   std_logic_vector(15 downto 0); 
  flash_data_i      : in    std_logic_vector(15 downto 0); 
  flash_data_tri    : out   std_logic;
  flash_noe         : out   std_logic;
  flash_nwe         : out   std_logic;
  flash_nce         : out   std_logic
);
end parallel_flash_phy;

architecture parallel_flash_phy_beh of parallel_flash_phy is

----------------------------------------------------------------------------------------------------
-- Constant declaration
----------------------------------------------------------------------------------------------------
-- Timing parameters
constant FLASH_CLK_PER_NS        : integer := 10; -- 100MHz         
constant FLASH_T_AH              : integer := integer(ceil(real(75)/real(FLASH_CLK_PER_NS))); -- tAH = 45ns                  
--constant FLASH_T_AH              : integer := integer(ceil(real(45)/real(FLASH_CLK_PER_NS))); -- tAH = 45ns                  
constant FLASH_T_WP              : integer := integer(ceil(real(25)/real(FLASH_CLK_PER_NS))); -- tWP = 25ns                  
constant FLASH_T_WPH             : integer := integer(ceil(real(20)/real(FLASH_CLK_PER_NS))); -- tWP = 25ns                  
constant FLASH_T_ACC             : integer := integer(ceil(real(130)/real(FLASH_CLK_PER_NS))); -- tACC = 110ns, a test with 110 failed, so build in 20 ns margin  
constant FLASH_T_PACC            : integer := integer(ceil(real(30)/real(FLASH_CLK_PER_NS))); -- tPACC = 25ns      
constant FLASH_T_OEH             : integer := integer(ceil(real(10)/real(FLASH_CLK_PER_NS))); -- tOEH = 10ns     
constant FLASH_T_CE              : integer := integer(ceil(real(140)/real(FLASH_CLK_PER_NS))); -- tCE = 130ns + 10 ns for A25 trough CPLD propagation     
constant FLASH_T_OE              : integer := integer(ceil(real(35)/real(FLASH_CLK_PER_NS))); -- tOE = 35ns     
constant FLASH_T_WC              : integer := integer(ceil(real(60)/real(FLASH_CLK_PER_NS))); -- tWC = 60ns     
constant FLASH_T_AS              : integer := 1; -- tAS = >0ns     
--constant FLASH_T_CS              : integer := integer(ceil(real(20)/real(FLASH_CLK_PER_NS))); -- 20 ns to guarentee 
constant FLASH_T_CS              : integer := integer(ceil(real(50)/real(FLASH_CLK_PER_NS))); -- 20 ns to guarentee 
                                                                                              -- valid A25 through CPLD

-- Memory Parameters                                
constant SECTOR_SIZE_BYTES       : std_logic_vector(31 downto 0) := x"00020000"; -- 128kB                                
constant PAGE_SIZE_BYTES         : std_logic_vector(15 downto 0) := x"0200";   -- 512 bytes 
constant DEFAULT_PAGE_SIZE_BYTES : integer := 512;     
constant DEFAULT_READ_SIZE_BYTES : integer := 12;
constant MEM_DENSITY_BYTES       : integer := 134217728; -- 1Gb                     
constant ADDRESS_RANGE           : integer := 26; -- 1Gb with 16 bit datawidth

-- Addr definitions
constant CFI_ENTER_ADDR          : std_logic_vector(25 downto 0) := conv_std_logic_vector(0, 10) & x"0055";
constant CFI_EXIT_ADDR           : std_logic_vector(25 downto 0) := (others => '0');
constant STATUS_REG_READ_ADDR    : std_logic_vector(25 downto 0) := conv_std_logic_vector(0, 10) & x"0555";
constant READ_DEVID_ADDR         : std_logic_vector(25 downto 0) := conv_std_logic_vector(0, 10) & x"0001";
constant SECT_ERASE_ADDR_BUS_SEQ : std_logic_vector(79 downto 0) := x"02AA_0555_0555_02AA_0555";
constant WR_BUFFER_ADDR_BUS_SEQ  : std_logic_vector(31 downto 0) := x"02AA_0555";

-- Command definitions
constant CFI_ENTER               : std_logic_vector(15 downto 0) := x"0098";
constant CFI_EXIT                : std_logic_vector(15 downto 0) := x"00F0";
constant STATUS_REG_READ         : std_logic_vector(15 downto 0) := x"0070";
constant SECT_ERASE_BUS_SEQ      : std_logic_vector(95 downto 0) := x"0030_0055_00AA_0080_0055_00AA";
constant WR_BUFFER_BUS_SEQ       : std_logic_vector(63 downto 0) := x"00FF_0025_0055_00AA";
constant PROG_BUF_TO_FLASH       : std_logic_vector(15 downto 0) := x"0029";

-- Interface States
-- Bit2: CE#
-- Bit1: OE#
-- Bit0: WE#
constant IF_STANDBY               : std_logic_vector(2 downto 0) := "111";
constant IF_CELOW                 : std_logic_vector(2 downto 0) := "011";
constant IF_READ                  : std_logic_vector(2 downto 0) := "001";
constant IF_WRITE                 : std_logic_vector(2 downto 0) := "010";

----------------------------------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------------------------------
type states is (idle, cmd_enter_cfi, cmd_get_devid,cmd_exit_cfi, cmd_sector_erase,
                cmd_read_status_cmd, cmd_receive_status,cmd_read_status_cmd_wait,
                cmd_program_buffer, cmd_program_buffer_remainder,
                cmd_program_buf_to_flash, cmd_read_data,cmd_pageread_data);

signal flash_sm       : states;
signal flash_sm_next  : states;
signal flash_sm_prev  : states;
signal flash_sm_prev2 : states;

type bus_states is (idle, wr_bus_ce_low, wr_bus_we_low,wr_bus_we_high, rd_bus_ce_low,
                rd_bus_oe_low, rd_bus_oe_high,pagerd_bus_ce_low,
                pagerd_bus_oe_low, rd_bus_oe_low_nextword,rd_bus_oe_low_nextpage);

signal bus_cycle_sm   : bus_states;

type mem_blk_states is (idleS, start_eraseS, poll_statusS, get_statusS1, get_statusS2,program_page_startS,
                        program_pageS,update_addressS);    
          
signal mem_access_sm      : mem_blk_states;
signal mem_access_sm_next : mem_blk_states;


signal data_out           : std_logic_vector(15 downto 0);
signal data_out_val       : std_logic;

signal flash_init             : std_logic;
signal read_id_start          : std_logic;
signal ramp_reset             : std_logic;
signal get_status_reg         : std_logic;
signal get_flag_status_reg    : std_logic;
signal set_status_reg         : std_logic;
signal set_nonvol_reg         : std_logic;
signal set_enh_vol_reg        : std_logic;
signal start_sect_erase       : std_logic;
signal start_program_page     : std_logic;
signal start_program_remainder: std_logic;
signal start_read_data        : std_logic;
signal start_page_read        : std_logic;

signal state_cnt                    : integer; -- range TBD
signal async_state_cnt              : integer; -- range TBD
signal bus_cycle_cnt                : integer;
signal page_read_word_cnt           : integer;
signal page_addr_cnt                : integer;

-- Flash input data
signal program_data_ack             : std_logic;

-- Receive data
signal data_byte_val                : std_logic;
signal data_byte_in                 : std_logic_vector(15 downto 0); 

signal parallel_addr                : std_logic_vector(25 downto 0);
signal parallel_data                : std_logic_vector(15 downto 0);
signal parallel_if_state            : std_logic_vector(2 downto 0);

signal page_read_val                : std_logic;
signal read_data                    : std_logic_vector(15 downto 0);

signal async_bus_cycle_done         : std_logic;
signal async_write_bus_cycle        : std_logic;
signal async_read_bus_cycle         : std_logic;
signal page_read_bus_cycle          : std_logic;

signal remainder_page               : std_logic;

constant DEBUG_C : boolean := true;

component ila_0
  port ( clk     : in std_logic;
         probe0  : in std_logic_vector(255 downto 0) );
end component;

signal flash_sm_slv : std_logic_vector(3 downto 0);
signal bus_cycle_cnt_slv : std_logic_vector(3 downto 0);
signal bus_cycle_sm_slv : std_logic_vector(3 downto 0);
signal async_state_cnt_slv : std_logic_vector(3 downto 0);
begin

  GEN_DEBUG : if DEBUG_C generate
    flash_sm_slv <= x"0" when flash_sm = idle else
                    x"1" when flash_sm = cmd_enter_cfi else
                    x"2" when flash_sm = cmd_get_devid else
                    x"3" when flash_sm = cmd_exit_cfi else
                    x"4" when flash_sm = cmd_sector_erase else
                    x"5" when flash_sm = cmd_read_status_cmd else
                    x"6" when flash_sm = cmd_receive_status else
                    x"7" when flash_sm = cmd_read_status_cmd_wait else
                    x"8" when flash_sm = cmd_program_buffer else
                    x"9" when flash_sm = cmd_program_buffer_remainder else
                    x"A" when flash_sm = cmd_program_buf_to_flash else
                    x"B" when flash_sm = cmd_read_data else
                    x"C" when flash_sm = cmd_pageread_data else
                    x"D";
    bus_cycle_cnt_slv <= std_logic_vector(to_unsigned(bus_cycle_cnt,4));
    bus_cycle_sm_slv <= x"0" when bus_cycle_sm = idle else
                        x"1" when bus_cycle_sm = wr_bus_ce_low else
                        x"2" when bus_cycle_sm = wr_bus_we_low else
                        x"3" when bus_cycle_sm = wr_bus_we_high else
                        x"4" when bus_cycle_sm = rd_bus_ce_low else
                        x"5" when bus_cycle_sm = rd_bus_oe_low else
                        x"6" when bus_cycle_sm = rd_bus_oe_high else
                        x"7" when bus_cycle_sm = pagerd_bus_ce_low else
                        x"8" when bus_cycle_sm = pagerd_bus_oe_low else
                        x"9" when bus_cycle_sm = rd_bus_oe_low_nextword else
                        x"A" when bus_cycle_sm = rd_bus_oe_low_nextpage else
                        x"B";
    async_state_cnt_slv <= std_logic_vector(to_unsigned(async_state_cnt,4));
    U_ILA : ila_0
      port map ( clk                  => flash_clk,
                 probe0( 3 downto  0) => flash_sm_slv,
                 probe0( 7 downto  4) => bus_cycle_cnt_slv,
                 probe0(11 downto  8) => bus_cycle_sm_slv,
                 probe0(15 downto 12) => async_state_cnt_slv,
                 probe0(255 downto 16) => (others=>'0') );
  end generate;
  
flash_init    <= flash_cmd(0);
read_id_start <= flash_cmd(1);
ramp_reset    <= flash_cmd(2);

get_status_reg            <= flash_cmd(4);
get_flag_status_reg       <= flash_cmd(5);
set_status_reg            <= flash_cmd(8);
set_nonvol_reg            <= flash_cmd(9);
-- reserved               <= flash_cmd(10);
set_enh_vol_reg           <= flash_cmd(11);
start_sect_erase          <= flash_cmd(12) ;
start_program_page        <= flash_cmd(13) ;
start_program_remainder   <= flash_cmd(14) ;
start_page_read           <= flash_cmd(15);
start_read_data           <= flash_cmd(16);



----------------------------------------------------------------------------------------------------
-- Synchronous process
----------------------------------------------------------------------------------------------------

-- Flash interface state machine
process (rst, flash_clk,flash_init)
begin
  if (rst = '1') or (flash_init = '1') then
    flash_sm        <= idle;
    state_cnt       <= 0;
    
    parallel_data   <= (others => '0');
    parallel_addr   <= (others => '0');
    
    async_write_bus_cycle <= '0';
    async_read_bus_cycle  <= '0';
    page_read_bus_cycle   <= '0';
    
    data_out      <= (others => '0'); 
    data_out_val  <= '0';
  elsif (rising_edge(flash_clk)) then

    case flash_sm is
      when idle =>
        parallel_data <= (others => '0');
        parallel_addr <= (others => '0');
        state_cnt     <= 0;
        bus_cycle_cnt <= 0;
        data_out_val  <= '0';
        if (read_id_start = '1') then
          flash_sm <= cmd_enter_cfi;
        elsif (start_sect_erase = '1') then
          flash_sm <= cmd_sector_erase;
        elsif (start_program_page = '1') then
          flash_sm  <= cmd_program_buffer;
        elsif (start_program_remainder = '1') then
          flash_sm        <= cmd_program_buffer_remainder;
        elsif (start_read_data = '1') then
          flash_sm <= cmd_read_data; 
        elsif (start_page_read = '1') then
          flash_sm <= cmd_pageread_data;         
        end if;
            
      -- Read ID fields       
      when cmd_enter_cfi =>
        parallel_data     <= CFI_ENTER; 
        parallel_addr     <= CFI_ENTER_ADDR;  
        if (async_bus_cycle_done = '1') then
          flash_sm  <= cmd_get_devid;
          async_write_bus_cycle <= '0';
        else
          async_write_bus_cycle <= '1';
        end if;
        
      when cmd_get_devid =>
        parallel_data     <= CFI_ENTER; 
        parallel_addr     <= READ_DEVID_ADDR;  
        if (async_bus_cycle_done = '1') then
          flash_sm  <= cmd_exit_cfi;
          async_read_bus_cycle <= '0';
        else
          async_read_bus_cycle <= '1';
        end if;
      
      when cmd_exit_cfi =>
        parallel_data     <= CFI_EXIT; 
        parallel_addr     <= CFI_EXIT_ADDR;  
        if (async_bus_cycle_done = '1') then
          flash_sm    <= idle;
          async_write_bus_cycle <= '0';
        else
          async_write_bus_cycle <= '1';
        end if;
        
      ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
      -- Sector Erase
      ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
      when cmd_sector_erase =>
        for i in 0 to 5 loop
          if (i = bus_cycle_cnt) then
            parallel_data     <= SECT_ERASE_BUS_SEQ(i*16+15 downto i*16); 
          end if;
        end loop;     
        if (bus_cycle_cnt <= 4) then
          for i in 0 to 4 loop
            if (i = bus_cycle_cnt) then
              parallel_addr     <= conv_std_logic_vector(0, 10) & SECT_ERASE_ADDR_BUS_SEQ(i*16+15 downto i*16);   
            end if;
          end loop;      
        else
          parallel_addr <= flash_access_addr(25 downto 16) & x"0000"; -- sector addr
        end if;
        
        if (async_bus_cycle_done = '1') then
          if (bus_cycle_cnt = 5) then
            flash_sm              <= cmd_read_status_cmd;
            async_write_bus_cycle <= '0'; 
            bus_cycle_cnt         <= 0;
          else
            bus_cycle_cnt         <= bus_cycle_cnt + 1;
            async_write_bus_cycle <= '1';
          end if;          
        else
          async_write_bus_cycle <= '1';
        end if;
        
      ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
      -- Poll Status Reg
      ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
      when cmd_read_status_cmd =>
        parallel_data <= STATUS_REG_READ; 
        parallel_addr <= STATUS_REG_READ_ADDR;  
        if (async_bus_cycle_done = '1') then
          flash_sm    <= cmd_receive_status;
          async_write_bus_cycle <= '0';
        else
          async_write_bus_cycle <= '1';
        end if;
        state_cnt         <= 0;
      when cmd_receive_status =>
        if (async_bus_cycle_done = '1') then
          async_read_bus_cycle <= '0';
          -- Erase finished and succesfull
          if (read_data(7 downto 0) = x"80") then
            flash_sm    <= idle;
          -- If not done yet, poll again
          else
              flash_sm <= cmd_read_status_cmd_wait;
          end if;         
        else
          async_read_bus_cycle <= '1';
        end if;
      -- added a wait state of 100 clock cycles because the
      -- sim  model froze when directly re-poll the status
      -- register
      when cmd_read_status_cmd_wait => 
        async_read_bus_cycle <= '0';
        if (state_cnt = 100) then
          state_cnt         <= 0;
          flash_sm <= cmd_read_status_cmd;
        else
          state_cnt <= state_cnt + 1;
        end if;
      
      ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
      -- Program 256 words buffer, 512 byte
      ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
      when cmd_program_buffer =>
        if (bus_cycle_cnt <= 3) then
          for i in 0 to 3 loop
            if (i = bus_cycle_cnt) then
              parallel_data     <= WR_BUFFER_BUS_SEQ(i*16+15 downto i*16); 
            end if;
          end loop;  
        else
          if (data_in_val = '1') then
            parallel_data <= data_in;       
          end if;
        end if;
        
        if (bus_cycle_cnt <= 1) then
          for i in 0 to 1 loop
            if (i = bus_cycle_cnt) then
              parallel_addr     <= conv_std_logic_vector(0, 10) & WR_BUFFER_ADDR_BUS_SEQ(i*16+15 downto i*16);   
            end if;
          end loop;    
        elsif (bus_cycle_cnt <= 3) then      
          -- sector addr , addr 25 downto 16
          parallel_addr <= flash_access_addr(25 downto 16) & x"0000";     
        else
          -- Write Buffer Location, must be within the write-buffer-line of 256 words
          parallel_addr <= flash_access_addr(25 downto 8) & conv_std_logic_vector(bus_cycle_cnt-4, 8); 
        end if;
        
        if (async_bus_cycle_done = '1') then
          if (bus_cycle_cnt = 256+3) then
            flash_sm              <= cmd_program_buf_to_flash;
            async_write_bus_cycle <= '0'; 
            bus_cycle_cnt         <= 0;
          else
            bus_cycle_cnt         <= bus_cycle_cnt + 1;
            async_write_bus_cycle <= '1';
          end if; 
        else
          async_write_bus_cycle <= '1';
        end if;
                
     ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
      -- Program N remainder words buffer, N*2 byte
      ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
      when cmd_program_buffer_remainder =>
        if (bus_cycle_cnt <= 2) then
          for i in 0 to 2 loop
            if (i = bus_cycle_cnt) then
              parallel_data     <= WR_BUFFER_BUS_SEQ(i*16+15 downto i*16); 
            end if;
          end loop;  
        elsif (bus_cycle_cnt = 3) then
          parallel_data <= x"00" & remainder_size_words - '1';         
        else
          if (data_in_val = '1') then
            parallel_data <= data_in;  
          end if;    
        end if;
        
        if (bus_cycle_cnt <= 1) then
          for i in 0 to 1 loop
            if (i = bus_cycle_cnt) then
              parallel_addr     <= conv_std_logic_vector(0, 10) & WR_BUFFER_ADDR_BUS_SEQ(i*16+15 downto i*16);   
            end if;
          end loop;    
        elsif (bus_cycle_cnt <= 3) then      
          -- sector addr , addr 25 downto 16
          parallel_addr <= flash_access_addr(25 downto 16) & x"0000";     
        else
          -- Write Buffer Location, must be within the write-buffer-line of 256 words
          parallel_addr <= flash_access_addr(25 downto 8) & conv_std_logic_vector(bus_cycle_cnt-4, 8); 
        end if;
        
        if (async_bus_cycle_done = '1') then
          if (bus_cycle_cnt = remainder_size_words+3) then
            flash_sm              <= cmd_program_buf_to_flash;
            async_write_bus_cycle <= '0'; 
            bus_cycle_cnt         <= 0;
          else
            bus_cycle_cnt         <= bus_cycle_cnt + 1;
            async_write_bus_cycle <= '1';
          end if; 
        else
          async_write_bus_cycle <= '1';
        end if;
                
      ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
      -- Send to program flash command to the device
      ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
      when cmd_program_buf_to_flash =>
        parallel_data   <= PROG_BUF_TO_FLASH; 
        parallel_addr   <= flash_access_addr(25 downto 16) & x"0000"; -- sector addr 
        if (async_bus_cycle_done = '1') then
          flash_sm    <= cmd_read_status_cmd;
          async_write_bus_cycle <= '0';
        else
          async_write_bus_cycle <= '1';
        end if;
      
      ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
      -- Read 256 words
      ------------------------------------------------------------------------------------------------------
      ------------------------------------------------------------------------------------------------------
       when cmd_read_data =>
        parallel_addr <=  flash_access_addr + conv_std_logic_vector(bus_cycle_cnt, 26); 
        if (async_bus_cycle_done = '1') then
          data_out_val <= '1';
          data_out     <= read_data;
          if (bus_cycle_cnt = conv_integer(burst_size_words)-1) then
            flash_sm             <= idle;
            async_read_bus_cycle <= '0'; 
            bus_cycle_cnt        <= 0;
          elsif (data_out_fifo_aff = '0') then
            bus_cycle_cnt        <= bus_cycle_cnt + 1;
            async_read_bus_cycle <= '1';
          else
            -- Already increment the address for next read.
            bus_cycle_cnt        <= bus_cycle_cnt + 1;
            async_read_bus_cycle <= '0';
          end if;          
        elsif (data_out_fifo_aff = '0') then
          async_read_bus_cycle <= '1';
          data_out_val         <= '0';
        else
          async_read_bus_cycle <= '0';
          data_out_val         <= '0';
        end if;

        
      when cmd_pageread_data =>
        parallel_addr <= flash_access_addr + (conv_std_logic_vector(page_addr_cnt, 22) & x"0") +
                          conv_std_logic_vector(page_read_word_cnt, 4); 
        data_out_val  <= page_read_val;
        data_out      <= read_data;
        if (async_bus_cycle_done = '1') then
          flash_sm              <= idle;
          page_read_bus_cycle   <= '0'; 
        else 
          page_read_bus_cycle   <= '1';         
        end if;          
      
      when others =>
        flash_sm  <= idle;
        
    end case;

  end if;
end process;

-- Data ack to the data FIFO
program_data_ack <= '1' when (async_bus_cycle_done = '1') and (bus_cycle_cnt >= 4) and 
                              (flash_sm = cmd_program_buffer or flash_sm = cmd_program_buffer_remainder) 
                              else '0';

 
-- Flash interface state machine outputs
process (rst, flash_clk)
begin
  if (rst = '1') then
    

    data_byte_val                 <= '0';
    data_byte_in                  <= x"0000";  
    
    parallel_if_state   <= IF_STANDBY;
    
    async_state_cnt       <= 0;
    page_read_word_cnt    <= 0;
    page_addr_cnt         <= 0;
    async_bus_cycle_done  <= '0';
    bus_cycle_sm <= idle;
  elsif (rising_edge(flash_clk)) then
        
      
    case bus_cycle_sm is
      when idle =>
        parallel_if_state     <= IF_STANDBY;
        async_bus_cycle_done  <= '0';
        async_state_cnt       <= 0;
        page_read_word_cnt    <= 0;
        page_addr_cnt         <= 0;
        if (async_bus_cycle_done = '0') then
          if (async_write_bus_cycle = '1') then
            bus_cycle_sm <= wr_bus_ce_low;
          elsif (async_read_bus_cycle = '1') then
            bus_cycle_sm <= rd_bus_ce_low;
          elsif (page_read_bus_cycle = '1') then
            bus_cycle_sm <= pagerd_bus_ce_low;
          end if;
        end if;
      -----------------------------------------------------------
      -- Asynchronous Write Bus Cycle
      -----------------------------------------------------------
      when wr_bus_ce_low =>
          parallel_if_state <= IF_CELOW;
          if (async_state_cnt >= FLASH_T_CS - 1) then
            bus_cycle_sm    <= wr_bus_we_low;
            async_state_cnt <= 0;
          else
            bus_cycle_sm    <= bus_cycle_sm;
            async_state_cnt <= async_state_cnt + 1;
          end if;
          
      when wr_bus_we_low =>
          parallel_if_state <= IF_WRITE;
          if (async_state_cnt >= FLASH_T_WP - 1) and
              (async_state_cnt >= FLASH_T_WC - FLASH_T_CS - 1) then
            bus_cycle_sm    <= wr_bus_we_high;
            async_state_cnt <= 0;
          else
            bus_cycle_sm    <= bus_cycle_sm;
            async_state_cnt <= async_state_cnt + 1;
          end if;
       
      when wr_bus_we_high =>
          parallel_if_state <= IF_CELOW;
          if (async_state_cnt >= FLASH_T_AH-FLASH_T_WP - 1) then
            bus_cycle_sm          <= idle;
            async_bus_cycle_done  <= '1';
            async_state_cnt       <= 0;
          else
            bus_cycle_sm          <= bus_cycle_sm;
            async_bus_cycle_done  <= '0';
            async_state_cnt       <= async_state_cnt + 1;
          end if;
       
       -----------------------------------------------------------
      -- Asynchronous Read Bus Cycle
      -----------------------------------------------------------
      when rd_bus_ce_low =>
          parallel_if_state <= IF_CELOW;
          if (async_state_cnt >= FLASH_T_CE - FLASH_T_OE - 1) then
            bus_cycle_sm    <= rd_bus_oe_low;
            async_state_cnt <= 0;
          else
            bus_cycle_sm    <= bus_cycle_sm;
            async_state_cnt <= async_state_cnt + 1;
          end if;
          
      when rd_bus_oe_low =>
          parallel_if_state <= IF_READ;
          if (async_state_cnt >= FLASH_T_OE - 1) then
            bus_cycle_sm    <= rd_bus_oe_high;
            async_state_cnt <= 0;
          else
            bus_cycle_sm    <= bus_cycle_sm;
            async_state_cnt <= async_state_cnt + 1;
          end if;
       

      -----------------------------------------------------------
      -- Page Read Bus Cycle
      -----------------------------------------------------------
      -- CE low
      when pagerd_bus_ce_low =>
          parallel_if_state <= IF_CELOW;
          if (async_state_cnt >= FLASH_T_CE - FLASH_T_OE - 1) then
            bus_cycle_sm    <= pagerd_bus_oe_low;
            async_state_cnt <= 0;
          else
            bus_cycle_sm    <= bus_cycle_sm;
            async_state_cnt <= async_state_cnt + 1;
          end if;
          
      -- OE low
      when pagerd_bus_oe_low =>
          parallel_if_state <= IF_READ;
          if (async_state_cnt >= FLASH_T_ACC - 1) then
            bus_cycle_sm        <= rd_bus_oe_low_nextword;
            page_read_word_cnt  <= 1;
            async_state_cnt     <= 0;
          else
            bus_cycle_sm    <= bus_cycle_sm;
            async_state_cnt <= async_state_cnt + 1;
          end if;
            
      -- Read 16 words (one page)
      when rd_bus_oe_low_nextword => 
          parallel_if_state <= IF_READ;
          
          if (async_state_cnt >= FLASH_T_PACC - 1) then
            if (page_read_word_cnt >= 15) then
              bus_cycle_sm        <= rd_bus_oe_low_nextpage;
              async_state_cnt     <= 0;
              page_read_word_cnt  <= 0;
              if (page_addr_cnt >= conv_integer(burst_size_words(25 downto 4))-1) then 
                page_addr_cnt <= 0;
                bus_cycle_sm  <= rd_bus_oe_high;
              else
                page_addr_cnt       <= page_addr_cnt + 1;
              end if;
            else
              bus_cycle_sm        <= bus_cycle_sm;
              async_state_cnt     <= 0;
              page_read_word_cnt  <= page_read_word_cnt + 1;
            end if;
          else 
            async_state_cnt <= async_state_cnt + 1;
          end if;            
          
      -- When start reading the next page, wait for the full FLASH_T_ACC time
      -- to give the higher address bits the time to settle
      when rd_bus_oe_low_nextpage =>
          parallel_if_state <= IF_READ;
          if (data_out_fifo_aff = '0') then
            if (async_state_cnt >= FLASH_T_ACC - 1) then
                bus_cycle_sm        <= rd_bus_oe_low_nextword;
                page_read_word_cnt  <= 1;
                async_state_cnt     <= 0;
            else
              async_state_cnt     <= async_state_cnt + 1;
              page_read_word_cnt  <= 0;
            end if;  
          else
            page_read_word_cnt  <= 0;
          end if;  
          
        
      -----------------------------------------------------------
      -- Page/Async Read Bus OE High Cycle
      -----------------------------------------------------------
      
      when rd_bus_oe_high =>
          parallel_if_state     <= IF_CELOW;
          bus_cycle_sm          <= idle;
          async_bus_cycle_done  <= '1';
          async_state_cnt       <= 0;
          
        when others =>
          page_read_word_cnt  <= 0;
      end case;


      -----------------------------------------------------------
      -----------------------------------------------------------
      -- Read data valid depending on state machine state and counters
      -----------------------------------------------------------
      -----------------------------------------------------------      
      -- Read data valid
      case bus_cycle_sm is
        -- Async single Read
        when rd_bus_oe_low =>
          page_read_val   <= '0';     
          if (async_state_cnt >= FLASH_T_OE - 1) then
            read_data       <=flash_data_i;
          end if;
          
        -- Page Read
        when pagerd_bus_oe_low  =>
          if (async_state_cnt >= FLASH_T_ACC - 1) then
            read_data       <=flash_data_i;
            page_read_val   <= '1';
          else
            page_read_val   <= '0';          
          end if;
        when rd_bus_oe_low_nextword  =>
          if (async_state_cnt >= FLASH_T_PACC - 1) then
            read_data       <=flash_data_i;
            page_read_val   <= '1';
          else
            page_read_val   <= '0';          
          end if;
          
        when rd_bus_oe_low_nextpage  =>
          if (data_out_fifo_aff = '0') then
            if (async_state_cnt >= FLASH_T_ACC - 1) then
              read_data       <=flash_data_i;
              page_read_val   <= '1';
            else
              page_read_val   <= '0';          
            end if;
          else
            page_read_val   <= '0';          
          end if;
        
        when others =>
          page_read_val   <= '0'; 
      end case;
    
  end if;
end process;
        
flash_phy_busy <= '1' when flash_sm /= idle else '0';
       
----------------------------------------------------------------------------------------------------
-- In/Output mapping
----------------------------------------------------------------------------------------------------

flash_address     <= parallel_addr; 
flash_data_o      <= parallel_data;
flash_nwe         <= parallel_if_state(0);
flash_data_tri    <= not parallel_if_state(1);
flash_noe         <= parallel_if_state(1);
flash_nce         <= parallel_if_state(2);


-- Data input interface
-- Take data from the external port when the data is not boardinfo or userrom, else take local data
data_in_ack      <= program_data_ack;

-- Data output interface
data_out_dval    <= data_out_val;
data_out_data    <= data_out;
  

----------------------------------------------------------------------------------------------------
-- End
----------------------------------------------------------------------------------------------------
end parallel_flash_phy_beh;
