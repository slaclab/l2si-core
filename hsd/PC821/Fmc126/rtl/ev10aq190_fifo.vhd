-------------------------------------------------------------------------------------
-- FILE NAME : ev10aq190_fifo.vhd
--
-- AUTHOR    : Peter Kortekaas
--
-- COMPANY   : 4DSP
--
-- ITEM      : 1
--
-- UNITS     : Entity       - ev10aq190_fifo
--             architecture - ev10aq190_fifo_syn
--
-- LANGUAGE  : VHDL
--
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
--
-- ev10aq190_fifo
-- Notes: ev10aq190_fifo
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
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
library unisim;
  use unisim.vcomponents.all;

entity ev10aq190_fifo is
  port (
    rst        : in  std_logic;
    -- Input port
    phy_clk    : in  std_logic;
    phy_data   : in  std_logic_vector(127 downto 0);

    fifo_wr_en : in  std_logic;
    fifo_usedw : out std_logic_vector(31 downto 0);
    fifo_empty : out std_logic;
    -- Output port
    if_clk     : in  std_logic;
    if_offload : in  std_logic;
    if_stop    : in  std_logic;
    if_dval    : out std_logic;
    if_data    : out std_logic_vector(63 downto 0)
  );
end ev10aq190_fifo;

architecture ev10aq190_fifo_syn of ev10aq190_fifo is

----------------------------------------------------------------------------------------------------
-- Components
----------------------------------------------------------------------------------------------------
component ev10aq190_storage_fifo is
port (
  rst           : in  std_logic;
  wr_clk        : in  std_logic;
  rd_clk        : in  std_logic;
  din           : in  std_logic_vector(127 downto 0);
  wr_en         : in  std_logic;
  rd_en         : in  std_logic;
  dout          : out std_logic_vector(63 downto 0);
  full          : out std_logic;
  empty         : out std_logic;
  valid         : out std_logic;
  rd_data_count : out std_logic_vector(11 downto 0);
  wr_data_count : out std_logic_vector(10 downto 0)
);
end component;

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------------------------------
signal phy_data_int  : std_logic_vector(127 downto 0);
signal if_rd_en      : std_logic;
signal wr_data_count : std_logic_vector(10 downto 0);

begin

----------------------------------------------------------------------------------------------------
-- FIFO
----------------------------------------------------------------------------------------------------
phy_data_int <= phy_data(63 downto 0) & phy_data(127 downto 64);

ev10aq190_storage_fifo_inst : ev10aq190_storage_fifo
port map (
  rst           => rst,
  wr_clk        => phy_clk,
  rd_clk        => if_clk,
  din           => phy_data_int,
  wr_en         => fifo_wr_en,
  rd_en         => if_rd_en,
  dout          => if_data,
  full          => open,
  empty         => fifo_empty,
  valid         => if_dval,
  rd_data_count => open,
  wr_data_count => wr_data_count
);

if_rd_en   <= (not if_stop) and if_offload;
fifo_usedw <= conv_std_logic_vector(conv_integer(wr_data_count), 32);

----------------------------------------------------------------------------------------------------
-- End
----------------------------------------------------------------------------------------------------
end ev10aq190_fifo_syn;
