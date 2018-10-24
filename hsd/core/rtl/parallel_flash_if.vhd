-------------------------------------------------------------------------------------
-- FILE NAME : parallel_flash_if.vhd
--
-- AUTHOR    : Ingmar van Klink
--
-- COMPANY   : 4DSP
--
-- ITEM      : 1
--
-- UNITS     : Entity       - parallel_flash_if
--             architecture - parallel_flash_if_syn
--
-- LANGUAGE  : VHDL
--
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
--
-- parallel_flash_if
-- Notes: parallel_flash_if
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
library unisim;
  use unisim.vcomponents.all;
library work;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
  
entity parallel_flash_if is
generic (
  START_ADDR              : std_logic_vector(27 downto 0) := x"0000000";
  STOP_ADDR               : std_logic_vector(27 downto 0) := x"00000FF"
);
port (
  -- Global signals
  flash_clk        : in    std_logic;

  axilClk          : in    sl;
  axilRst          : in    sl;
  axilWriteMaster  : in    AxiLiteWriteMasterType;
  axilWriteSlave   : out   AxiLiteWriteSlaveType;
  axilReadMaster   : in    AxiLiteReadMasterType;
  axilReadSlave    : out   AxiLiteReadSlaveType;

  --External signals
  flash_address     : out   std_logic_vector(25 downto 0);
  flash_data_o      : out   std_logic_vector(15 downto 0); 
  flash_data_i      : in    std_logic_vector(15 downto 0); 
  flash_data_tri    : out   std_logic;
  flash_noe         : out   std_logic;
  flash_nwe         : out   std_logic;
  flash_nce         : out   std_logic
);
end parallel_flash_if;

architecture parallel_flash_if_beh of parallel_flash_if is

constant CMD_WR      : std_logic_vector(3 downto 0) := x"1";
constant CMD_RD      : std_logic_vector(3 downto 0) := x"2";
constant CMD_RD_ACK  : std_logic_vector(3 downto 0) := x"4";
constant CMD_WR_ACK          : std_logic_vector(3 downto 0) := x"5";
constant CMD_WR_EXPECTS_ACK  : std_logic_vector(3 downto 0) := x"6";

----------------------------------------------------------------------------------------------------
-- Signal  declarations
----------------------------------------------------------------------------------------------------
  type RegType is record
    in_cmd_val     : sl;
    in_cmd         : slv(63 downto 0);
    wrfifo16_wr_en   : slv( 1 downto 0);
    wrfifo16_wr_data : slv(31 downto 0);
    rdfifo16_rd_en   : sl;
    axilWriteSlave : AxiLiteWriteSlaveType;
    axilReadSlave  : AxiLiteReadSlaveType;
  end record;
  constant REG_INIT_C : RegType := (
    in_cmd_val       => '0',
    in_cmd           => (others=>'0'),
    wrfifo16_wr_en   => (others=>'0'),
    wrfifo16_wr_data => (others=>'0'),
    rdfifo16_rd_en   => '0',
    axilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
    axilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
  signal fifo_reset_in          : sl;
  signal fifo_reset             : sl;

  signal wrfifo16_full            : sl;
  signal wrfifo16_rd_en           : sl;
  signal wrfifo16_rd_valid        : sl;
  signal wrfifo16_rd_data         : slv(15 downto 0);
  signal wrfifo16_data_cnt        : slv(12 downto 0);
  signal data_in_usedw            : slv(12 downto 0);
  
  signal rdfifo16_wr_en           : sl;
  signal rdfifo16_wr_stop         : sl;
  signal rdfifo16_wr_full         : sl;
  signal rdfifo16_wr_data         : slv(15 downto 0);
  signal rdfifo16_rd_valid        : sl;
  signal rdfifo16_rd_data         : slv(15 downto 0);
  signal rdfifo16_rd_count        : slv(13 downto 0);
  
  signal out_cmd_val            : sl;
  signal out_cmd                : slv(63 downto 0);

  constant DEBUG_C : boolean := false;

begin

  flash_ctrls : entity work.parallel_flash_controller 
    generic map(
      START_ADDR              => START_ADDR,
      STOP_ADDR               => STOP_ADDR
      )
    port map(
      -- Global signals           
      rst                         => axilRst                        , 
      flash_clk                   => flash_clk                  , 
      -- Fifo reset                            
      fifo_reset                  => fifo_reset                 , 
      -- Command Interf                   
      clk_cmd                     => axilClk,
      in_cmd_val                  => r.in_cmd_val,
      in_cmd                      => r.in_cmd,

      out_cmd_val                 => out_cmd_val                , 
      out_cmd                     => out_cmd                    , 
      cmd_busy                    => open                       , 
      --Input ports for               
      data_in_fifo_usedw          => data_in_usedw,
      data_in_ack                 => wrfifo16_rd_en,
      data_in_val                 => wrfifo16_rd_valid,
      data_in_data                => wrfifo16_rd_data,
      --Output ports fo                      
      data_out_fifo_almost_full   => rdfifo16_wr_stop,
      data_out_dval               => rdfifo16_wr_en,
      data_out_data               => rdfifo16_wr_data,
      -- External ports
      flash_address               => flash_address ,
      flash_data_o                => flash_data_o  ,
      flash_data_i                => flash_data_i  ,
      flash_data_tri              => flash_data_tri,
      flash_noe                   => flash_noe     ,
      flash_nwe                   => flash_nwe     ,
      flash_nce                   => flash_nce     
      );

  fifo_reset_in <= axilRst or fifo_reset;

  U_WRFIFO : entity work.FifoAsync
    generic map ( DATA_WIDTH_G => 16,
                  ADDR_WIDTH_G => 13,
                  FWFT_EN_G    => true )
    port map ( rst           => fifo_reset_in,
               wr_clk        => axilClk,
               wr_en         => r.wrfifo16_wr_en(0),
               din           => r.wrfifo16_wr_data(15 downto 0),
               almost_full   => wrfifo16_full,
               rd_clk        => flash_clk,
               rd_en         => wrfifo16_rd_en,
               dout          => wrfifo16_rd_data,
               rd_data_count => wrfifo16_data_cnt,
               valid         => wrfifo16_rd_valid );

  data_in_usedw <= wrfifo16_data_cnt+1;
  
  U_RDFIFO : entity work.FifoAsync
    generic map ( DATA_WIDTH_G => 16,
                  ADDR_WIDTH_G => 14,
                  FULL_THRES_G => 4096,
                  FWFT_EN_G    => true )
    port map ( rst           => fifo_reset_in,
               wr_clk        => flash_clk,
               wr_en         => rdfifo16_wr_en,
               din           => rdfifo16_wr_data,
               prog_full     => rdfifo16_wr_stop,
               full          => rdfifo16_wr_full,
               rd_clk        => axilClk,
               rd_en         => r.rdfifo16_rd_en,
               rd_data_count => rdfifo16_rd_count,
               dout          => rdfifo16_rd_data,
               valid         => rdfifo16_rd_valid );

  comb: process( r, out_cmd, out_cmd_val, wrfifo16_full, axilRst, axilWriteMaster, axilReadMaster, rdfifo16_rd_valid, rdfifo16_rd_data ) is
    variable v : RegType;
    variable axilStatus : AxiLiteStatusType;
  begin
    v := r;

    v.in_cmd_val     := '0';
    v.rdfifo16_rd_en := '0';
    
    axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

    if (axilStatus.writeEnable='1' and axilWriteMaster.awaddr(7 downto 2) < STOP_ADDR(5 downto 0)) then
      v.in_cmd_val := '1';
      v.in_cmd     := CMD_WR & x"00000" &
                      "00" & axilWriteMaster.awaddr(7 downto 2) &
                      axilWriteMaster.wdata;
      axiSlaveWriteResponse(v.axilWriteSlave);
    end if;

    --if (out_cmd_val='1' and out_cmd(63 downto 60)=CMD_RD_ACK) then
    --  v.axilReadSlave.rdata := out_cmd(31 downto 0);
    --  axiSlaveReadResponse(v.axilReadSlave);
    --end if;
    
    --if (out_cmd_val='1' and out_cmd(63 downto 60)=CMD_WR_ACK) then
    --  axiSlaveWriteResponse(v.axilWriteSlave);
    --end if;
    
    if (axilStatus.writeEnable='1' and std_match(axilWriteMaster.awaddr(7 downto 2), STOP_ADDR(5 downto 0)) and wrfifo16_full='0') then
      v.wrfifo16_wr_data := axilWriteMaster.wdata;
      v.wrfifo16_wr_en   := "11";
      axiSlaveWriteResponse(v.axilWriteSlave);
    else
      v.wrfifo16_wr_data := x"0000" & r.wrfifo16_wr_data(31 downto 16);
      v.wrfifo16_wr_en   := '0' & r.wrfifo16_wr_en(1);
    end if;
    
    if (axilStatus.readEnable='1' and std_match(axilReadMaster.araddr(7 downto 2), STOP_ADDR(5 downto 0))) then
      v.axilReadSlave.rdata := rdfifo16_rd_valid & toSlv(0,15) & rdfifo16_rd_data;
      v.rdfifo16_rd_en      := rdfifo16_rd_valid;
      axiSlaveReadResponse(v.axilReadSlave);
    end if;
    
    axiSlaveDefault(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, AXI_RESP_OK_C);
   
    if axilRst='1' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;

    axilWriteSlave <= r.axilWriteSlave;
    axilReadSlave  <= r.axilReadSlave;
  end process comb;

  seq: process(axilClk) is
  begin
    if rising_edge(axilClk) then
      r <= rin;
    end if;
  end process seq;
  
end parallel_flash_if_beh;
