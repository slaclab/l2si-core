-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : hsd_dualv2_sim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2017-06-16
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 DAQ Software'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 DAQ Software', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
--use work.TimingPkg.all;
--use work.TPGPkg.all;
use work.QuadAdcPkg.all;
use work.SsiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity hsd_dualv2_sim is
end hsd_dualv2_sim;

architecture top_level_app of hsd_dualv2_sim is

   constant NCHAN_C : integer := CHANNELS_C;
   
   signal phyClk   : sl;
   signal rst      : sl;
   
   signal adcInput         :    AdcInputArray(NCHAN_C-1 downto 0);

    -- AXI-Lite and IRQ Interface
   signal regClk    : sl;
   signal regRst    : sl;
   signal regWriteMaster     : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal regWriteSlave      : AxiLiteWriteSlaveType;
   signal regReadMaster      : AxiLiteReadMasterType := AXI_LITE_READ_MASTER_INIT_C;
   signal regReadSlave       : AxiLiteReadSlaveType;
    -- DMA
   signal dmaClk            : sl;
   signal dmaRst            : sl;
   signal dmaIbMaster       : AxiStreamMasterType;
   signal dmaIbSlave        : AxiStreamSlaveType := AXI_STREAM_SLAVE_FORCE_C;

   signal adcI, adcO        : AdcDataArray(NCHAN_C-1 downto 0);

   type TrigType is record
     lopen   : sl;
     lclose  : sl;
     lphase  : slv(2 downto 0);
     l1in    : sl;
     l1a     : sl;
   end record;

   signal r    : TrigType;
   signal r_in : TrigType;
   
   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);

   signal dmaData           : slv(127 downto 0);
   signal axilDone : sl;
   
begin

   dmaRst <= rst;
   dmaData <= dmaIbMaster.tData(dmaData'range);
   
   process (phyClk) is
     variable s : slv(7 downto 0) := (others=>'0');
     variable d : slv(2 downto 0) := (others=>'0');
     variable t : integer         := 0;
--     constant PERIOD_C : integer := 1348;
     constant PERIOD_C : integer := 13480;
   begin
     for ch in 0 to NCHAN_C-1 loop
       adcInput(ch).clkp <= phyclk;
       adcInput(ch).clkn <= not phyClk;
     end loop;
     if rising_edge(phyClk) then
       for ch in 0 to NCHAN_C-1 loop
         adcInput(ch).datap <= toSlv(ch,3) & s;
         adcInput(ch).datan <= toSlv(ch,3) & (s xor toSlv(255,8));
         adcI(ch).data(7) <= toSlv(ch,3) & s;
         adcI(ch).data(6 downto 0) <= adcI(ch).data(7 downto 1);
       end loop;

       if t = PERIOD_C-1 then
         adcI(2).data(7)(10) <= '1';
       else
         adcI(2).data(7)(10) <= '0';
       end if;

       for ch in 0 to 1 loop
         adcI(ch).data(7)(10) <= adcI(ch+1).data(0)(10);
       end loop;
       
       if t = PERIOD_C-1 then
         t := 0;
       else
         t := t+1;
       end if;
--       trigIn(0) <= d(0) & trigIn(0)(7 downto 1);
--       d := trigSel & d(2 downto 1);
       s := s+1;
     end if;
   end process;

   process is
   begin
     phyClk <= '1';
     wait for 0.4 ns;
     phyClk <= '0';
     wait for 0.4 ns;
   end process;

   process (dmaClk) is
   begin
     if rising_edge(dmaClk) then
       for ch in 0 to NCHAN_C-1 loop
         adcO(ch) <= adcI(ch);
       end loop;
     end if;
   end process;
   
   process is
   begin
     dmaClk <= '1';
     wait for 3.2 ns;
     dmaClk <= '0';
     wait for 3.2 ns;
   end process;

   process is
     variable lcount : slv(1 downto 0) := (others=>'0');
   begin
     r_in.lopen  <= '0';
     r_in.lclose <= '0';
     r_in.lphase <= (others=>'0');
     r_in.l1in   <= '0';
     r_in.l1a    <= '0';

     wait until axilDone='1';

     for k in 0 to 15 loop
       wait until adcI(2).data(0)(10)='1';
       wait until dmaClk='0';
       r_in.lopen <= '1';
       for j in 0 to 7 loop
         if adcO(2).data(j)(10)='1' then
           r_in.lphase <= toSlv(j,3);
         end if;
       end loop;
       wait until dmaClk='1';
       wait until dmaClk='0';
       r_in.lopen <= '0';
       
       for i in 0 to 3 loop
         wait until adcI(2).data(0)(10)='1';
         wait until dmaClk='0';
         if i<3 then
           r_in.lopen <= '1';
           for j in 0 to 7 loop
             if adcO(2).data(j)(10)='1' then
               r_in.lphase <= toSlv(j,3);
             end if;
           end loop;
         end if;
         wait until dmaClk='1';
         wait until dmaClk='0';
         r_in.lopen <= '0';
         
         wait for 100 ns;
         wait until dmaClk='0';
         r_in.lclose <= '1';
         r_in.l1in   <= '1';
         lcount := lcount+1;
         if lcount = toSlv(0,lcount'length) then
           r_in.l1a    <= '0';
         else
           r_in.l1a    <= '1';
         end if;
         if lcount(0)='1' then
           r_in.lphase <= toSlv(0,3);
         else
           r_in.lphase <= toSlv(4,3);
         end if;
         wait until dmaClk='1';
         wait until dmaClk='0';
         r_in.lclose <= '0';
         r_in.l1in   <= '0';
       end loop;
       
       wait for 200 us;
     end loop;
   end process;

   process (dmaClk) is
   begin
     if rising_edge(dmaClk) then
       r <= r_in;
     end if;
   end process;
   
   process is
   begin
     rst <= '1';
     wait for 100 ns;
     rst <= '0';
     wait;
   end process;
   
   regRst <= rst;

   process is
   begin
     regClk <= '0';
     wait for 3.2 ns;
     regClk <= '1';
     wait for 3.2 ns;
   end process;
     
   --U_DUT : configuration work.raw_cfg 
   --  generic map ( AXIS_CONFIG_G => AXIS_CONFIG_C )
   --  port map ( clk              => dmaClk,
   --             rst              => dmaRst,
   --             din              => adcO(0).data,
   --             lopen            => r.lopen,
   --             lclose           => r.lclose,
   --             lphase           => r.lphase,
   --             l1in             => r.l1in,
   --             l1a              => r.l1a,
   --             axisMaster       => dmaIbMaster,
   --             axisSlave        => dmaIbSlave,
   --             axilReadMaster   => regReadMaster,
   --             axilReadSlave    => regReadSlave,
   --             axilWriteMaster  => regWriteMaster,
   --             axilWriteSlave   => regWriteSlave );

--   U_DUT : configuration work.raw_chfifo_cfg
   U_DUT : entity work.QuadAdcChannelFifov2
     port map ( clk              => dmaClk,
                rst              => dmaRst,
                clear            => dmaRst,
                start            => r.lopen,
                shift            => r.lphase,
                din              => adcO(0).data,
                l1in             => r.l1in,
                l1ina            => r.l1a,
                l1a              => open,
                l1v              => open,
                axisMaster       => dmaIbMaster,
                axisSlave        => dmaIbSlave,
                axilClk          => regClk,
                axilRst          => regRst,
                axilReadMaster   => regReadMaster,
                axilReadSlave    => regReadSlave,
                axilWriteMaster  => regWriteMaster,
                axilWriteSlave   => regWriteSlave );

process is
  procedure wreg(addr : integer; data : slv(31 downto 0)) is
     begin
       wait until regClk='0';
       regWriteMaster.awaddr  <= toSlv(addr,32);
       regWriteMaster.awvalid <= '1';
       regWriteMaster.wdata   <= data;
       regWriteMaster.wvalid  <= '1';
       regWriteMaster.bready  <= '1';
       wait until regClk='1';
       wait until regWriteSlave.bvalid='1';
       wait until regClk='0';
       wait until regClk='1';
       wait until regClk='0';
       regWriteMaster.awvalid <= '0';
       regWriteMaster.wvalid  <= '0';
       regWriteMaster.bready  <= '0';
       wait for 50 ns;
     end procedure;
  begin
    axilDone <= '0';
    wait until regRst='0';
    wait for 200 ns;
    wreg(16,x"00000001"); -- prescale
    wreg(20,x"08000004"); -- fexLength/Delay
    wreg(24,x"00040C00"); -- almostFull
    wreg(32,x"00000000"); -- prescale
    wreg(36,x"00800784"); -- fexLength/Delay
    wreg(40,x"00040100"); -- almostFull
    wreg( 0,x"00000003"); -- fexEnable
    wait for 600 ns;
    axilDone <= '1';
    wait;
  end process;
   
end top_level_app;
