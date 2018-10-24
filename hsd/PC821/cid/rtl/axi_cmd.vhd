-------------------------------------------------------------------------------------
-- FILE NAME : .vhd
-- AUTHOR    : Luis F. Munoz
-- COMPANY   : 4DSP
-- UNITS     : Entity       -
--             Architecture - Behavioral
-- LANGUAGE  : VHDL
-- DATE      : May 21, 2015
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-- DESCRIPTION
-- ===========
-- AXI4-Lite Register read/write interface
--
--   Version 0.1 - initial release with correction to S_AXI_RDATA defaulting back to '0'
--
--
--
-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------
-- LIBRARIES
-------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_unsigned.all;
    use ieee.std_logic_misc.all;
    use ieee.std_logic_arith.all;

-------------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------------
entity axi_cmd is
generic (
    START_ADDR : std_logic_vector(27 downto 0) := x"0000000";
    STOP_ADDR  : std_logic_vector(27 downto 0) := x"0000010"
);
port (
   S_AXI_ARESETN           : in std_logic;
   -- axi-lite: global
   S_AXI_ACLK              : in  std_logic;
   -- axi-lite: write address channel
   S_AXI_AWADDR            : in  std_logic_vector(31 downto 0);
   S_AXI_AWVALID           : in  std_logic;
   S_AXI_AWREADY           : out std_logic;
   -- axi-lite: write data channel
   S_AXI_WDATA             : in  std_logic_vector(31  downto 0);
   S_AXI_WSTRB             : in  std_logic_vector(3  downto 0);
   S_AXI_WVALID            : in  std_logic;
   S_AXI_WREADY            : out std_logic;
   -- axi-lite: write response channel
   S_AXI_BRESP             : out std_logic_vector(1 downto 0);
   S_AXI_BVALID            : out std_logic;
   S_AXI_BREADY            : in  std_logic;
   -- axi-lite: read address channel
   S_AXI_ARADDR            : in  std_logic_vector(31  downto 0);
   S_AXI_ARVALID           : in  std_logic;
   S_AXI_ARREADY           : out std_logic;
   -- axi-lite: read channel
   S_AXI_RDATA             : out std_logic_vector(31 downto 0);
   S_AXI_RRESP             : out std_logic_vector(1 downto 0);
   S_AXI_RVALID            : out std_logic;
   S_AXI_RREADY            : in  std_logic;
   -- Register Interface
   o_rst                   : out std_logic;
   out_reg_val             : out std_logic;
   out_reg_addr            : out std_logic_vector(27 downto 0);
   out_reg                 : out std_logic_vector(31 downto 0);
   out_wr_ack              : in  std_logic := '0';
   in_reg                  : in std_logic_vector(31 downto 0);
   in_reg_val              : in std_logic;
   in_reg_req              : out std_logic;
   in_reg_addr             : out std_logic_vector(27 downto 0)
);
end axi_cmd;

-------------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------------
architecture Behavioral of axi_cmd is

-------------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------------
constant RSP_OKAY        : std_logic_vector(1 downto 0) := "00";
constant RSP_EXOKAY      : std_logic_vector(1 downto 0) := "01"; -- Not supported by axi-lite
constant RSP_SLVERR      : std_logic_vector(1 downto 0) := "10";
constant RSP_DECERR      : std_logic_vector(1 downto 0) := "11";

constant TIME_OUT_CNT    : std_logic_vector(7 downto 0) := x"7f";

-----------------------------------------------------------------------------------
-- SIGNALS
-----------------------------------------------------------------------------------
signal local_rst            : std_logic := '1';
signal new_write_access     : std_logic;
signal new_read_access      : std_logic;
signal ongoing_write        : std_logic;
signal out_wr_ack_reg       : std_logic;
signal ongoing_read         : std_logic;
signal valid_wr_address     : std_logic;
signal valid_rd_address     : std_logic;
signal watch_dog_rst        : std_logic;
signal watch_dog_cnt        : std_logic_vector(7 downto 0);
signal s_axi_rvalid_i       : std_logic;
signal s_axi_arready_i      : std_logic;
signal s_axi_bvalid_i       : std_logic;
signal s_axi_wready_i       : std_logic;

signal wr_watch_dog_rst     : std_logic;
signal wr_watch_dog_cnt     : std_logic_vector(7 downto 0);

signal out_reg_val_reg      : std_logic;
signal out_reg_val_dly      : std_logic;
signal in_reg_req_reg       : std_logic;
signal in_reg_req_dly       : std_logic;


--***********************************************************************************
begin
--***********************************************************************************

-------------------------------------------------------------------------------
-- Local reset
-------------------------------------------------------------------------------
process(S_AXI_ACLK, s_axi_aresetn)
begin
    if S_AXI_ARESETN = '0' then
        local_rst <= '1';
    elsif rising_edge(S_AXI_ACLK) then
        local_rst <= '0';
    end if;
end process;

o_rst  <= local_rst;
-------------------------------------------------------------------------------
-- Write interface
-------------------------------------------------------------------------------
-- A write is only accept if data and address are written at the exact same time.
valid_wr_address  <= '1' when (s_axi_awaddr(27 downto 0) >= START_ADDR and s_axi_awaddr(27 downto 0) <= STOP_ADDR) else '0';
new_write_access  <= s_axi_wready_i and S_AXI_AWVALID and S_AXI_WVALID and valid_wr_address;

-- Combinatorial logic and mapping to comply to AXI waveforms
S_AXI_BVALID  <= s_axi_bvalid_i;

-- AXI rule of write dependencies allows to assert AWREADY and WREADY
-- exactly under similar conditions. Therefore AWREADY is a copy of WREADY
S_AXI_AWREADY <= s_axi_wready_i and S_AXI_AWVALID and S_AXI_WVALID;
S_AXI_WREADY  <= s_axi_wready_i and S_AXI_AWVALID and S_AXI_WVALID;

-- Implement rising edge detection on valid output to ensure that this is a strobe
-- for every single access.
out_reg_val <= out_reg_val_reg and not out_reg_val_dly;

process (S_AXI_ACLK)
begin
   if rising_edge(S_AXI_ACLK) then
      if local_rst = '1' then
         out_reg            <= (others=>'0');
         out_reg_addr       <= (others=>'0');
         out_reg_val_reg    <= '0';
         out_reg_val_dly    <= '0';
         out_wr_ack_reg     <= '0';
         ongoing_write      <= '0';
         -- We implement according to AXI rules, therefore WREADY and AWREADY are the same
         s_axi_wready_i     <= '0';

         S_AXI_BRESP        <= RSP_OKAY;
         s_axi_bvalid_i     <= '0'; -- BVALID is internal signal because it's used in the process as well
         wr_watch_dog_rst   <= '1';
      else

         s_axi_wready_i     <= '0'; -- default
         out_reg_val_reg    <= '0';

         out_reg_val_dly    <= out_reg_val_reg;

        -- a write command has been accepted
        if (S_AXI_AWVALID = '1' and S_AXI_WVALID = '1') and valid_wr_address = '1'  then
            ongoing_write    <= '1';
            wr_watch_dog_rst <= '0';  -- start watchdog timer
            s_axi_wready_i   <= '1';  -- write channel ready, transfer occurs
            s_axi_bvalid_i   <= '0';
            S_AXI_BRESP      <= RSP_OKAY;
            out_reg          <= s_axi_wdata(31 downto 0);
            out_reg_addr     <= s_axi_awaddr(27 downto 0) - START_ADDR;
            out_reg_val_reg      <= '1';
        -- write response channel is available and we got a write acknowledge (write success)
        elsif ongoing_write = '1' and out_wr_ack_reg = '1' then
            ongoing_write    <= '0';
            wr_watch_dog_rst <= '1';  -- reset watchdog timer
            s_axi_bvalid_i   <= '1';
            S_AXI_BRESP      <= RSP_OKAY;
        -- didn't get a write acknowledge within the allowed time (write fail)
        -- or the write response channel didn't become available
        elsif wr_watch_dog_cnt = TIME_OUT_CNT then
            ongoing_write    <= '0';
            wr_watch_dog_rst <= '1';  -- reset watchdog timer
            s_axi_bvalid_i   <= '1';
            S_AXI_BRESP      <= RSP_SLVERR;
        elsif (S_AXI_BREADY = '1' and s_axi_bvalid_i = '1') then
            S_AXI_BRESP      <= RSP_OKAY;
            s_axi_bvalid_i   <= '0';
        end if;

        -- wait for a write acknowledge and remember regardless if the response channel
        -- is available or not (S_AXI_BREADY).
        if ongoing_write = '1' and out_wr_ack = '1' then
            out_wr_ack_reg <= '1';
        elsif ongoing_write = '0' then
            out_wr_ack_reg <= '0';
        end if;

      end if;
   end if;
end process;

-- write watchdog timer
process(S_AXI_ACLK)
begin
   if rising_edge(S_AXI_ACLK) then
      if wr_watch_dog_rst = '1' then
         wr_watch_dog_cnt <= (others=>'0');
      else
        wr_watch_dog_cnt <= wr_watch_dog_cnt + 1;
      end if;
   end if;
end process;

-------------------------------------------------------------------------------
-- Read Interface
-------------------------------------------------------------------------------
valid_rd_address  <= '1' when (s_axi_araddr(27 downto 0) >= START_ADDR and s_axi_araddr(27 downto 0) <= STOP_ADDR) else '0';
new_read_access   <= s_axi_arready_i and S_AXI_ARVALID and valid_rd_address;

-- dummy signal so we can use it internally
S_AXI_RVALID  <= s_axi_rvalid_i;
S_AXI_ARREADY <= s_axi_arready_i and S_AXI_ARVALID;

-- Implement rising edge detection on request output to ensure that this is a strobe
-- for every single access.
in_reg_req <= in_reg_req_reg and not in_reg_req_dly;

process (S_AXI_ACLK)
begin
    if rising_edge(S_AXI_ACLK) then
        if local_rst = '1' then
            ongoing_read    <= '0';
            in_reg_req_reg  <= '0';
            in_reg_req_dly  <= '0';
            in_reg_addr     <= (others=>'0');
            s_axi_rvalid_i  <= '0';
            watch_dog_rst   <= '1';
            S_AXI_RRESP     <= (others=>'0');
            S_AXI_RDATA     <= (others=>'0');
            s_axi_arready_i <= '0';
        else
            watch_dog_rst   <= '1'; --default
            s_axi_arready_i <= '0'; --default
            in_reg_req_reg  <= '0';
            in_reg_req_dly  <= in_reg_req_reg;

            if S_AXI_ARVALID = '1' and valid_rd_address = '1' then
                ongoing_read    <= '1';
                s_axi_arready_i <= '1';
                in_reg_req_reg  <= '1';
                in_reg_addr     <= s_axi_araddr(27 downto 0) - START_ADDR;
            elsif ongoing_read = '1' then
                watch_dog_rst <= '0';
                -- read completed successfully
                if in_reg_val = '1' then
                    s_axi_rvalid_i <= '1';
                    S_AXI_RDATA    <= in_reg(31 downto 0);
                    S_AXI_RRESP    <= RSP_OKAY;
                -- didn't get a read response quickly enough
                elsif watch_dog_cnt = TIME_OUT_CNT then
                    s_axi_rvalid_i <= '1';
                    S_AXI_RDATA    <= in_reg(31 downto 0);
                    S_AXI_RRESP    <= RSP_SLVERR;
                -- read transaction has completed
                elsif S_AXI_RREADY = '1' and s_axi_rvalid_i = '1' then
                    s_axi_rvalid_i <= '0';
                    S_AXI_RDATA    <= (others=>'0');
                    S_AXI_RRESP    <= RSP_OKAY;
                    ongoing_read   <= '0';
                end if;
            end if;
        end if;
    end if;
end process;


-- Watch dog timer for errors
process(S_AXI_ACLK)
begin
   if rising_edge(S_AXI_ACLK) then
      if watch_dog_rst = '1' then
         watch_dog_cnt <= (others=>'0');
      else
        watch_dog_cnt <= watch_dog_cnt + 1;
      end if;
   end if;
end process;

--***********************************************************************************
end architecture Behavioral;
--***********************************************************************************

