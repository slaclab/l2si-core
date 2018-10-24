
library ieee;
use ieee.std_logic_1164.all ;
use ieee.std_logic_arith.all ;
use ieee.std_logic_unsigned.all ;
use ieee.std_logic_misc.all ;

entity pulse2pulse is
port (
   in_clk      :in std_logic;
   out_clk     :in std_logic;
   rst         :in std_logic;
   pulsein     :in std_logic;
   inbusy      :out std_logic;
   pulseout    :out std_logic
   );
end pulse2pulse;

architecture syn of pulse2pulse is
-----------------------------------------------------------------------------------
--constant declarations
-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
--constant declarations
-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
--signal declarations
-----------------------------------------------------------------------------------
signal out_set       :std_logic;
signal out_set_prev  :std_logic;
signal out_set_prev2 :std_logic;
signal in_set        :std_logic;
signal outreset      :std_logic;
signal in_reset      :std_logic;
signal in_reset_prev :std_logic;
signal in_reset_prev2:std_logic;

constant STAGES_G : integer := 3;
signal crossDomainSyncReg : std_logic_vector(STAGES_G-1 downto 0) := (others=>'0');

   attribute ASYNC_REG                       : string;
   attribute ASYNC_REG of crossDomainSyncReg : signal is "TRUE";
   attribute syn_srlstyle                       : string;
   attribute syn_srlstyle of crossDomainSyncReg : signal is "registers";
   attribute MSGON                       : string;
   attribute MSGON of crossDomainSyncReg : signal is "FALSE";
   attribute shreg_extract                       : string;
   attribute shreg_extract of crossDomainSyncReg : signal is "no";
   attribute register_balancing                       : string;
   attribute register_balancing of crossDomainSyncReg : signal is "no";
   attribute altera_attribute                       : string;
   attribute altera_attribute of crossDomainSyncReg : signal is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";

-----------------------------------------------------------------------------------
--component declarations
-----------------------------------------------------------------------------------



--*********************************************************************************
begin
--*********************************************************************************


-----------------------------------------------------------------------------------
--component instantiations
-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
--synchronous processes
-----------------------------------------------------------------------------------
in_proc:process(in_clk,rst)
begin
   if(rst = '1') then
      in_reset      <= '0';
      in_reset_prev <= '0';
      in_reset_prev2<= '0';
      in_set        <= '0';

   elsif(in_clk'event and in_clk = '1') then
      --regitser a pulse on the pulse in port
      --reset the signal when the ouput has registerred the pulse
      if (in_reset_prev = '1' and in_reset_prev2 = '1') then
         in_set <= '0';
      elsif (pulsein = '1') then
         in_set <= '1';
      end if;

      --register the reset signal from the other clock domain
      --three times. double stage synchronising circuit
      --reduces the MTB
      in_reset       <=  outreset;
      in_reset_prev  <= in_reset;
      in_reset_prev2 <= in_reset_prev;


   end if;
end process in_proc;

out_proc:process(out_clk,rst)
begin
   if(rst = '1') then
      crossDomainSyncReg <= (others=>'0');
      outreset      <= '0';
      pulseout      <= '0';
   elsif(out_clk'event and out_clk = '1') then
      --generate a pulse on the outpput when the
      --set signal has travelled through the synchronising fip flops
      if (out_set_prev = '1' and out_set_prev2 = '0') then
         pulseout <= '1';
      else
         pulseout <= '0';
      end if;

      --feedback the corret reception of the set signal to reset the set pulse
      if (out_set_prev = '1' and out_set_prev2 = '1') then
         outreset <= '1';
      elsif (out_set_prev = '0' and out_set_prev2 = '0') then
         outreset <= '0';
      end if;

      --register the reset signal from the other clock domain
      --three times. double stage synchronising circuit
      --reduces the MTB
      crossDomainSyncReg <= crossDomainSyncReg(STAGES_G-2 downto 0) & in_set;

   end if;
end process out_proc;

out_set       <= crossDomainSyncReg(0);
out_set_prev  <= crossDomainSyncReg(1);
out_set_prev2 <= crossDomainSyncReg(2);

-----------------------------------------------------------------------------------
--asynchronous processes
-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
--asynchronous mapping
-----------------------------------------------------------------------------------
 inbusy <= in_set or in_reset_prev;

-------------------
-------------------
end syn;
