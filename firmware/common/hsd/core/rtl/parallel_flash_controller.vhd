-------------------------------------------------------------------------------------
-- FILE NAME : parallel_flash_controller.vhd
--
-- AUTHOR    : Ingmar van Klink
--
-- COMPANY   : 4DSP
--
-- ITEM      : 1
--
-- UNITS     : Entity       - parallel_flash_controller
--             architecture - parallel_flash_controller_syn
--
-- LANGUAGE  : VHDL
--
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
--
-- parallel_flash_controller
-- Notes: parallel_flash_controller
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
  use ieee.math_real.all;
library unisim;
  use unisim.vcomponents.all;

entity parallel_flash_controller is
generic (
  START_ADDR              : std_logic_vector(27 downto 0) := x"0000000";
  STOP_ADDR               : std_logic_vector(27 downto 0) := x"00000FF"
);
port (
  -- Global signals
  rst              : in    std_logic;
  flash_clk        : in    std_logic;
  
  -- Fifo reset
  fifo_reset       : out   std_logic;

  -- Command Interface
  clk_cmd          : in    std_logic;
  in_cmd_val       : in    std_logic;
  in_cmd           : in    std_logic_vector(63 downto 0);
  out_cmd_val      : out   std_logic;
  out_cmd          : out   std_logic_vector(63 downto 0);
  cmd_busy         : out   std_logic;

  --Input ports for parallel programming data
  data_in_fifo_usedw        : in    std_logic_vector(12 downto 0);
  data_in_ack               : out   std_logic;
  data_in_val               : in    std_logic;
  data_in_data              : in    std_logic_vector(15 downto 0);

  --Output ports for parallel programming data readback
  data_out_fifo_almost_full : in    std_logic;
  data_out_dval             : out   std_logic;
  data_out_data             : out   std_logic_vector(15 downto 0);

  --External signals
  flash_address     : out   std_logic_vector(25 downto 0);
  flash_data_o      : out   std_logic_vector(15 downto 0); 
  flash_data_i      : in    std_logic_vector(15 downto 0); 
  flash_data_tri    : out   std_logic;
  flash_noe         : out   std_logic;
  flash_nwe         : out   std_logic;
  flash_nce         : out   std_logic
  );
end parallel_flash_controller;

architecture parallel_flash_controller_beh of parallel_flash_controller is

----------------------------------------------------------------------------------------------------
-- Constant declaration
----------------------------------------------------------------------------------------------------
                                
-- Memory Parameters                                
constant SECTOR_SIZE_BYTES       : std_logic_vector(31 downto 0) := x"00020000"; -- 128kB                                
constant PAGE_SIZE_BYTES         : std_logic_vector(15 downto 0) := x"0200";   -- 512 bytes 
constant DEFAULT_PAGE_SIZE_BYTES : integer := 512;     
constant DEFAULT_READ_SIZE_BYTES : integer := 12;
constant MEM_DENSITY_BYTES       : integer := 134217728; -- 1Gb                     
constant ADDRESS_RANGE           : integer := 26; -- 1Gb with 16 bit datawidth

-- Base addresses for 4FM data in 256Mb Micron flash device on sFMC820
constant USER_FLASH_BASE_ADDR           : std_logic_vector(31 downto 0) := x"00000000"; -- Starts in sector 0
constant SAVE_IMAGE_FLASH_BASE_ADDR     : std_logic_vector(31 downto 0) := x"02000000"; -- Starts at half the memory

constant ADDR_SRC_DEST                  : std_logic_vector(27 downto 0) := x"0000003";
constant ADDR_BURST_NO_BYTES_START_PROG : std_logic_vector(27 downto 0) := x"0000004";
constant ADDR_BURST_NO_BYTES_START_READ : std_logic_vector(27 downto 0) := x"0000006";

-- Registers to control the flash controller manually (not connected within the Host IF)
-- Most of the registers are not supported for this flash controller but reserved 
constant ADDR_COMMAND         : std_logic_vector(27 downto 0) := x"0000010";
constant ADDR_CONTROLLER      : std_logic_vector(27 downto 0) := x"0000011";
constant ADDR_DEV_INFO_REG    : std_logic_vector(27 downto 0) := x"0000012";
constant ADDR_STATUS_REG      : std_logic_vector(27 downto 0) := x"0000013";
constant ADDR_BURST_NO_BYTES  : std_logic_vector(27 downto 0) := x"0000014";
constant ADDR_SINGLE_ADDRESS  : std_logic_vector(27 downto 0) := x"0000015";
constant ADDR_VOL_REG         : std_logic_vector(27 downto 0) := x"0000016";
constant ADDR_ENH_VOL_REG     : std_logic_vector(27 downto 0) := x"0000017";
constant ADDR_NONVOL_REG      : std_logic_vector(27 downto 0) := x"0000018";
constant ADDR_PAGE_SIZE       : std_logic_vector(27 downto 0) := x"0000019";
constant ADDR_NO_PAGES        : std_logic_vector(27 downto 0) := x"000001A";
constant ADDR_DUMMY_CYCLES    : std_logic_vector(27 downto 0) := x"000001B";


constant CMD_WR      :std_logic_vector(3 downto 0) :=x"1";

----------------------------------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------------------------------

type mem_blk_states is (idleS, start_eraseS, poll_erase_statusS, program_page_startS,
                        program_pageS,poll_program_statusS, program_remainder_startS, 
                        program_remainderS, poll_rmdr_statusS, update_addressS1, update_addressS2);    
          
signal mem_access_sm      : mem_blk_states;

type get_binfo_states is (idleS, get_binfoS, get_userromS);
signal get_binfo_sm       : get_binfo_states;

signal out_reg_val       : std_logic;
signal out_reg_addr      : std_logic_vector(27 downto 0);
signal out_reg           : std_logic_vector(31 downto 0);

signal out_cmd_val_cmd   : std_logic;
signal out_cmd_cmd       : std_logic_vector(63 downto 0);

signal in_reg_req        : std_logic;
signal in_reg_addr       : std_logic_vector(27 downto 0);
signal in_reg_val        : std_logic;
signal in_reg            : std_logic_vector(31 downto 0);

signal delayed_cmd                  : std_logic_vector(15 downto 0);
signal cmd_reg                      : std_logic_vector(31 downto 0);
signal flash_cmd                    : std_logic_vector(31 downto 0);
signal flash_cmdi                   : std_logic_vector(31 downto 0);
signal address_reg_in               : std_logic_vector(ADDRESS_RANGE-1 downto 0);
signal dummy_cycles                 : std_logic_vector(7 downto 0);
signal burst_size_bytes_reg         : std_logic_vector(28 downto 0);
signal remainder_size_words         : std_logic_vector(7 downto 0);
signal mem_address                  : std_logic_vector(ADDRESS_RANGE downto 0);
signal mem_new_address              : std_logic_vector(ADDRESS_RANGE downto 0);
signal mem_access_addr              : std_logic_vector(ADDRESS_RANGE-1 downto 0);
signal flash_init                   : std_logic;
signal start_load_mem               : std_logic;

signal flash_reg_val                : std_logic;
signal flash_reg_pulse_i            : std_logic;
signal address_reg_in_flash_clk     : std_logic_vector(ADDRESS_RANGE-1 downto 0);
signal burst_size_words_flash_clk   : std_logic_vector(25 downto 0);

-- Pulses generated from Block memory access SM
signal mem_erase_pulse              : std_logic;
signal mem_progpage_pulse           : std_logic;
signal mem_progremainder_pulse      : std_logic;
signal mem_getstatus_pulse          : std_logic;
signal mem_block_access_busy        : std_logic;

signal state_busy                   : std_logic;

-- Flash input data
signal program_data_ack             : std_logic;
signal program_data_val             : std_logic;
signal program_data                 : std_logic_vector(15 downto 0); 

-- Receive data
signal data_byte_val                : std_logic;
signal data_byte_in                 : std_logic_vector(15 downto 0); 

signal out_reg_val_ack   : std_logic;
signal wr_ack            : std_logic;

----------------------------------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------------------------------

component pulse2pulse
port (
   in_clk   : in  std_logic;
   out_clk  : in  std_logic;
   rst      : in  std_logic;
   pulsein  : in  std_logic;
   inbusy   : out std_logic;
   pulseout : out std_logic
);
end component;

component parallel_flash_phy is
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
end component;

constant DEBUG_C : boolean := false;

signal mem_access_sm_slv : std_logic_vector(3 downto 0);

begin

----------------------------------------------------------------------------------------------------
-- Stellar Command Interface
----------------------------------------------------------------------------------------------------
parallel_stellar_cmd_inst : entity work.parallel_stellar_cmd
generic map (
  START_ADDR   => START_ADDR,
  STOP_ADDR    => STOP_ADDR
)
port map (
  reset        => rst,

  clk_cmd      => clk_cmd,
  in_cmd_val   => in_cmd_val,
  in_cmd       => in_cmd,
  out_cmd_val  => out_cmd_val_cmd,
  out_cmd      => out_cmd_cmd,
  out_reg_val_ack   => out_reg_val_ack,  
  clk_reg      => clk_cmd,
  out_reg_val  => out_reg_val,
  out_reg_addr => out_reg_addr,
  out_reg      => out_reg,

  in_reg_req   => in_reg_req,
  in_reg_addr  => in_reg_addr,
  in_reg_val   => in_reg_val,
  in_reg       => in_reg,
  wr_ack       => wr_ack, 
  mbx_in_val   => '0',
  mbx_in_reg   => (others => '0')
);

cmd_busy <= '0';

-- Output mux, the in_cmd is also copied back to the output the write the 
-- status registers inside the sip_pci_cmd block
out_cmd_val <= out_cmd_val_cmd;  
out_cmd     <= out_cmd_cmd;
                
----------------------------------------------------------------------------------------------------
-- Registers
----------------------------------------------------------------------------------------------------
process (rst, clk_cmd)
begin
  if (rst = '1') then
    cmd_reg               <= (others => '0');
    in_reg_val            <= '0';
    in_reg                <= (others => '0');
    address_reg_in        <= (others => '0');
    dummy_cycles          <= x"08"; 
    burst_size_bytes_reg  <= conv_std_logic_vector(DEFAULT_READ_SIZE_BYTES,29); -- default to 12 bytes for board info
    wr_ack                <= '0'; 
    delayed_cmd           <= x"0000";
  elsif (rising_edge(clk_cmd)) then
    -- Write acknowledge
    if (out_reg_val_ack = '1') then
      wr_ack     <= '1';
    else
      wr_ack     <= '0';
    end if;

    -- Write
    if ((out_reg_val = '1'  or out_reg_val_ack = '1') and out_reg_addr = ADDR_COMMAND) then
      cmd_reg <= out_reg;
    elsif ((out_reg_val = '1'  or out_reg_val_ack = '1') and out_reg_addr = ADDR_BURST_NO_BYTES_START_PROG) then
      cmd_reg(17) <= '1'; 
    elsif ((out_reg_val = '1'  or out_reg_val_ack = '1') and out_reg_addr = ADDR_BURST_NO_BYTES_START_READ) then
      cmd_reg(15) <= '1'; 
    else
      cmd_reg     <= (others => '0');
    end if;
    -- Auto start memory load when burst size is written
    
    -- Configure the burst size and start address based on the 
    -- data that must be written to the flash
    if (out_reg_val = '1' or out_reg_val_ack = '1')  then
      case out_reg_addr is 
        when ADDR_BURST_NO_BYTES_START_PROG | ADDR_BURST_NO_BYTES_START_READ =>
          burst_size_bytes_reg <= out_reg(28 downto 0);
        when ADDR_BURST_NO_BYTES =>
          burst_size_bytes_reg <= out_reg(28 downto 0);
        when others => 
          burst_size_bytes_reg <= burst_size_bytes_reg;
      end case;
    end if;
    
    -- Configure the base address
    if (out_reg_val = '1' or out_reg_val_ack = '1')  then
      case out_reg_addr is 
        -- FPGA config image address
        when ADDR_SRC_DEST =>
          if (out_reg = x"11111111") then
            -- upper half of memory for safe image
            address_reg_in <= SAVE_IMAGE_FLASH_BASE_ADDR(ADDRESS_RANGE-1 downto 0);
          else
            address_reg_in <= USER_FLASH_BASE_ADDR(ADDRESS_RANGE-1 downto 0);
          end if;
        -- Low level access address setting option
        when ADDR_SINGLE_ADDRESS => 
          address_reg_in <= out_reg(ADDRESS_RANGE-1 downto 0);          
        when others => 
          address_reg_in <= address_reg_in;          
      end case;
    end if;
        
    -- Read
    if (in_reg_req = '1') then
      in_reg_val <= '1';
      case in_reg_addr is 
        when ADDR_CONTROLLER => 
          in_reg     <= conv_std_logic_vector(0, 25) & mem_block_access_busy & state_busy & 
                        '0' & x"0";
        when ADDR_STATUS_REG => 
          in_reg     <= (others => '0');
        when ADDR_SINGLE_ADDRESS => 
          in_reg     <= conv_std_logic_vector(0, 32-address_reg_in'length) & address_reg_in;
        when ADDR_BURST_NO_BYTES =>
          in_reg     <= "000" & burst_size_bytes_reg;
        when others => -- nothing
      end case;
    else
      in_reg_val <= '0';
    end if;    
      
  end if;
end process;

----------------------------------------------------------------------------------------------------
-- Transfer command pulses to other Flash clock domain
----------------------------------------------------------------------------------------------------
cmd_pls: for i in 0 to 31 generate
  pulse2pulse_inst : pulse2pulse
  port map (
    in_clk   => clk_cmd,
    out_clk  => flash_clk,
    rst      => rst,
    pulsein  => cmd_reg(i),
    inbusy   => open,
    pulseout => flash_cmd(i)
  );
end generate;

flash_reg_pulse_i <= out_reg_val or out_reg_val_ack;

pulse2pulse_inst_cmdval : pulse2pulse
  port map (
    in_clk   => clk_cmd,
    out_clk  => flash_clk,
    rst      => rst,
    pulsein  => flash_reg_pulse_i,
    inbusy   => open,
    pulseout => flash_reg_val
  );

----------------------------------------------------------------------------------------------------
-- Mem pulse
----------------------------------------------------------------------------------------------------
-- Map pulses to this statemachine
start_load_mem      <= flash_cmd(17);

----------------------------------------------------------------------------------------------------
-- Move control registers to the flash clock domain
----------------------------------------------------------------------------------------------------
  U_Sync_BurstSize : entity work.SynchronizerVector
    generic map ( WIDTH_G => 26 )
    port map ( clk     => flash_clk,
               dataIn  => burst_size_bytes_reg(26 downto 1),
               dataOut => burst_size_words_flash_clk );
         
  U_Sync_Address : entity work.SynchronizerVector
    generic map ( WIDTH_G => address_reg_in'length )
    port map ( clk     => flash_clk,
               dataIn  => address_reg_in,
               dataOut => address_reg_in_flash_clk );
         
-- process (rst, flash_clk, flash_init)
-- begin
  -- if (rst = '1') or (flash_init = '1') then
    -- burst_size_words_flash_clk  <= (others => '0');
    -- address_reg_in_flash_clk    <= (others => '0');
  -- elsif (rising_edge(flash_clk)) then
    
    -- if (flash_reg_val = '1') then
      -- -- Parallel flash IF width is 16 bit, so always write/read multiple of 2 byte
    -- end if;  
    
  -- end if;
-- end process;

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- Flash memory block write operation state machine
-- This statemachine:
-- - upon reception of a start_load_xxxxx pulse starts 
-- - 1. erase target sector
-- - 2. polls the flash status until the erase is completed
-- - 3. programs a single page
-- - 4. polls the flash status until the page program is completed
-- - 5. based on the number of bytes,step 1 to 4 are repeated
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

process (rst, flash_clk, flash_init)
  -- variable mem_new_address : std_logic_vector(ADDRESS_RANGE downto 0);
begin
  if (rst = '1') or (flash_init = '1') then
    mem_access_sm        <= idleS;
    mem_address          <= (others => '0');
    mem_new_address      <= (others => '0');
    remainder_size_words <= (others => '0');
  elsif (rising_edge(flash_clk)) then
  
    case mem_access_sm is
      when idleS =>
        remainder_size_words <= (others => '0');
        if (start_load_mem = '1')  then
          mem_access_sm <= start_eraseS;
          mem_address   <= '0' & address_reg_in_flash_clk;
        end if;
      
      when start_eraseS =>
        mem_access_sm       <= poll_erase_statusS;
        mem_address         <= mem_address;
        mem_new_address     <= mem_new_address;
      
      when poll_erase_statusS =>
        mem_address         <= mem_address;
        mem_new_address     <= mem_new_address;
        if (state_busy = '0') then
          -- Cover the case where the remainder is just after the page boundary
          if (mem_new_address >= ((burst_size_words_flash_clk(25 downto 8) & x"00") + address_reg_in_flash_clk)) and (burst_size_words_flash_clk(7 downto 0) /= x"00") then
            mem_access_sm        <= program_remainder_startS;
            remainder_size_words <= burst_size_words_flash_clk(7 downto 0);
          -- Else program the full page
          else
            mem_access_sm <= program_page_startS;
          end if;
        end if;
              
      -- Check if there is at least a complete page in the FIFO, do a minus one because it's a 
      -- First Word Fall Through FIFO
      when program_page_startS =>
        mem_address         <= mem_address;
        mem_new_address     <= mem_new_address;
        if (conv_integer(data_in_fifo_usedw) >= conv_integer(PAGE_SIZE_BYTES(15 downto 1))) then
          mem_access_sm       <= program_pageS;
        end if;
          
      when program_pageS =>
        mem_address        <= mem_address;
        mem_new_address    <= mem_new_address;
        mem_access_sm      <= poll_program_statusS;

      when poll_program_statusS =>
        mem_address         <= mem_address;
        mem_new_address     <= mem_new_address;
        if (state_busy = '0') then
          mem_access_sm <= update_addressS1;
        end if;
        
      -- Program the remainder of data (less then 512 bytes)
      when program_remainder_startS =>
        mem_address        <= mem_address;
        mem_new_address    <= mem_new_address;
        if (conv_integer(data_in_fifo_usedw) >= conv_integer(remainder_size_words)) then
          mem_access_sm    <= program_remainderS;
        end if;
        
      when program_remainderS =>
        mem_address        <= mem_address;
        mem_new_address    <= mem_new_address;
        mem_access_sm      <= poll_rmdr_statusS;

      when poll_rmdr_statusS =>
        mem_address         <= mem_address;
        mem_new_address     <= mem_new_address;
        if (state_busy = '0') then
          mem_access_sm <= idleS;
        end if;
        
      when update_addressS1 =>
        mem_new_address <= ('0' & mem_address(ADDRESS_RANGE-1 downto 0)) + PAGE_SIZE_BYTES(15 downto 1);-- div 2 because the interface is 2 bytes wide
        mem_access_sm   <= update_addressS2;
        
      when update_addressS2 =>
        -- If burst_size is exactly a multiple of 512 bytes, 
        -- and new mem address is equal to burst size + start address, stop and go to idle
        if (mem_new_address >= (burst_size_words_flash_clk + address_reg_in_flash_clk)) then
          mem_access_sm <= idleS;
        -- Erase next sector when crossing 128kB address
        elsif (mem_address(ADDRESS_RANGE downto 16) /= (mem_new_address(ADDRESS_RANGE downto 16))) then
          mem_access_sm <= start_eraseS;
        elsif (mem_new_address >= ((burst_size_words_flash_clk(25 downto 8) & x"00") + address_reg_in_flash_clk)) and (burst_size_words_flash_clk(7 downto 0) /= x"00") then
          mem_access_sm        <= program_remainder_startS;
          remainder_size_words <= burst_size_words_flash_clk(7 downto 0);
        -- when the burst size is not equal to a multiple of 512 bytes/256 words, write the remainder
        else
          mem_access_sm <= program_page_startS;
        end if;
        mem_address <= mem_new_address;
      
      when others =>
        mem_access_sm       <= idleS;
        mem_address         <= mem_address; 
        mem_new_address     <= mem_new_address;        
    
    end case;
  end if;
end process;

        
----------------------------------------------------------------------------------------------------
-- State machine output pulses to flash phy        
----------------------------------------------------------------------------------------------------
process (mem_access_sm)
begin
  case mem_access_sm is
    when start_eraseS =>
      mem_erase_pulse           <= '1';
      mem_progpage_pulse        <= '0';
      mem_progremainder_pulse   <= '0';
      mem_getstatus_pulse       <= '0';
    when program_pageS =>     
      mem_erase_pulse           <= '0';
      mem_progpage_pulse        <= '1';
      mem_progremainder_pulse   <= '0';
      mem_getstatus_pulse       <= '0';
    when program_remainderS =>
      mem_erase_pulse           <= '0';
      mem_progpage_pulse        <= '0';
      mem_progremainder_pulse   <= '1';
      mem_getstatus_pulse       <= '0';    
    when others =>
      mem_erase_pulse           <= '0';
      mem_progpage_pulse        <= '0';
      mem_progremainder_pulse   <= '0';
      mem_getstatus_pulse       <= '0';

   end case;
    
   if (mem_access_sm /= idleS) then
     mem_block_access_busy <= '1';
   else
     mem_block_access_busy <= '0';
   end if;
      
end process;
   
----------------------------------------------------------------------------------------------------
-- In/Output mapping, based on process above
----------------------------------------------------------------------------------------------------

-- Data input interface
-- Take data from the external port when the data is not boardinfo or userrom, else take local data
data_in_ack      <= program_data_ack;
program_data     <= data_in_data;
program_data_val <= data_in_val;

-- Data output interface
data_out_dval    <= data_byte_val;
data_out_data    <= data_byte_in;
  
-- Reset the fifo's
fifo_reset       <= flash_init;


----------------------------------------------------------------------------------------------------
-- Map command pulses to flash phy and locally generated pulses 
----------------------------------------------------------------------------------------------------
              
flash_init                <= flash_cmd(0) or rst;
flash_cmdi(3 downto 0)    <= flash_cmd(3 downto 0);
flash_cmdi(4)             <= flash_cmd(4) or mem_getstatus_pulse;
flash_cmdi(11 downto 5)   <= flash_cmd(11 downto 5);
flash_cmdi(12)            <= flash_cmd(12) or mem_erase_pulse;
flash_cmdi(13)            <= flash_cmd(13) or mem_progpage_pulse;
flash_cmdi(14)            <= flash_cmd(14) or mem_progremainder_pulse;
flash_cmdi(15)            <= flash_cmd(15);
flash_cmdi(16)            <= flash_cmd(16);
flash_cmdi(17)            <= flash_cmd(17);
flash_cmdi(18)            <= flash_cmd(18);
flash_cmdi(19)            <= flash_cmd(19);
flash_cmdi(31 downto 20)  <= flash_cmd(31 downto 20);

mem_access_addr     <= mem_address(ADDRESS_RANGE-1 downto 0)   when mem_block_access_busy = '1' else address_reg_in_flash_clk;
                                     

parallel_flash_phy_i : parallel_flash_phy
port map
(
  rst                   => rst,
  init                  => flash_init,
  flash_clk             => flash_clk,
  flash_cmd             => flash_cmdi,
  flash_phy_busy        => state_busy,
  flash_access_addr     => mem_access_addr,
  burst_size_words      => burst_size_words_flash_clk,
  remainder_size_words  => remainder_size_words,
  
  -- Data input interface, data to load to flash
  data_in_ack       => program_data_ack,
  data_in_val       => program_data_val,
  data_in           => program_data,
  -- Data read from flash
  data_out_fifo_aff => data_out_fifo_almost_full,
  data_out_dval     => data_byte_val,
  data_out_data     => data_byte_in,
  
  -- External ports
  flash_address => flash_address ,
  flash_data_o  => flash_data_o  ,
  flash_data_i  => flash_data_i  ,
  flash_data_tri=> flash_data_tri,
  flash_noe     => flash_noe     ,
  flash_nwe     => flash_nwe     ,
  flash_nce     => flash_nce     
);



----------------------------------------------------------------------------------------------------
-- End
----------------------------------------------------------------------------------------------------
end parallel_flash_controller_beh;
