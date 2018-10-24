--------------------------------------------------------------------------------
-- file name : clkrst_pc821.vhd
--
-- author    : I. van Klink
--
-- company   : 4dsp
--
-- item      : number
--
-- units     : entity       -clkrst_pc821
--             arch_itecture - arch_clkrst_pc821
--
-- language  : vhdl
--
--------------------------------------------------------------------------------
-- description
-- ===========
--
--
-- notes:
--------------------------------------------------------------------------------
--
--  disclaimer: limited warranty and disclaimer. these designs are
--              provided to you as is.  4dsp specifically disclaims any
--              implied warranties of merchantability, non-infringement, or
--              fitness for a particular purpose. 4dsp does not warrant that
--              the functions contained in these designs will meet your
--              requirements, or that the operation of these designs will be
--              uninterrupted or error free, or that defects in the designs
--              will be corrected. furthermore, 4dsp does not warrant or
--              make any representations regarding use or the results of the
--              use of the designs in terms of correctness, accuracy,
--              reliability, or otherwise.
--
--              limitation of liability. in no event will 4dsp or its
--              licensors be liable for any loss of data, lost profits, cost
--              or procurement of substitute goods or services, or for any
--              special, incidental, consequential, or indirect damages
--              arising from the use or operation of the designs or
--              accompanying documentation, however caused and on any theory
--              of liability. this limitation will apply even if 4dsp
--              has been advised of the possibility of such damage. this
--              limitation shall apply not-withstanding the failure of the
--              essential purpose of any limited remedies herein.
--
--      from
-- ver  pcb mod    date      changes
-- ===  =======    ========  =======
--
-- 0.0    0        19-01-2009        new version
--
----------------------------------------------
--
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- specify libraries.
--------------------------------------------------------------------------------

library unisim;
   use unisim.vcomponents.all;
library ieee;
use ieee.std_logic_misc.all ;
   use ieee.std_logic_1164.all;
   use ieee.std_logic_unsigned.all;
   use ieee.numeric_std.all;
   
--------------------------------------------------------------------------------
-- entity declaration
--------------------------------------------------------------------------------
entity clkrst_pc821  is
generic ( reset_base :integer:=1024);
port
(

   sys_clk1_n                     : in    std_logic;-- This clock is 300MHz and used for DDR4 MIG(AK30/AK31)
   sys_clk1_p                     : in    std_logic;
   sys_clk2_n                     : in    std_logic;-- This clock is 300MHz (AW14/AW13)
   sys_clk2_p                     : in    std_logic;
   reset_in                       : in    std_logic;
   axi_clk_in						          : in    std_logic;
   
   --clk outputs
   clk200M_o                      :out std_logic;
   clk_125Mo                      :out std_logic;
   clk_100Mo                      :out std_logic;
   clk_50Mo                       :out std_logic;
   clk_10Mo                       :out std_logic;
   clk300_ddr4_gb                 :out std_logic;
   fpga_ref_clk_gb                :out std_logic;
   
   --reset outputs
   reset1_o                       :out std_logic;
   reset2_o                       :out std_logic;
   reset3_o                       :out std_logic
   );
end entity clkrst_pc821  ;

--------------------------------------------------------------------------------
-- arch_itecture declaration
--------------------------------------------------------------------------------
architecture arch_clkrst_pc821   of clkrst_pc821  is

-----------------------------------------------------------------------------------
--constant declarations
-----------------------------------------------------------------------------------
constant reset1_cnt     :integer :=reset_base*16-1;
constant reset2_cnt     :integer :=reset_base*8-1;
constant reset3_cnt     :integer :=reset_base*4-1;
type reset_sm_type  is  (reset_all, reset_dcm, wait_dcm_lock, wait_reset1, wait_reset2, wait_reset3, idle);
-----------------------------------------------------------------------------------
--signal declarations
-----------------------------------------------------------------------------------
signal reset_i_reg            :std_logic;
signal reset_i_reg2           :std_logic;

signal clk_10M               :std_logic;
signal clk_50M               :std_logic;
signal clk_100M              :std_logic;
signal clk_125M              :std_logic; 
signal clk_200M              :std_logic;
signal clk_250M              :std_logic;
signal clk_300M              :std_logic;   

signal clk300_gb             :std_logic;
signal clk300_i              :std_logic; 
signal fpga_ref_clk_i        :std_logic;

signal reset_i                : std_logic;
signal reset1_sig             :std_logic;
signal reset2_sig             :std_logic;
signal reset3_sig             :std_logic;
signal reset1_sigi            :std_logic;
signal reset2_sigi            :std_logic;
signal reset3_sigi            :std_logic;
signal dcm_reset              :std_logic;
signal dcm_reset_i_reg        :std_logic;
signal dcm_reset_i_reg2       :std_logic;
signal dcm_reseti             :std_logic;

signal reset_sm               :reset_sm_type;
signal reset_sm_prev          :reset_sm_type;

signal dly_ready_o_sig        :std_logic;

signal pll_locked        :std_logic;


signal clk_ddr_0o_sig         :std_logic;
signal clk_ddr_0_div2o_sig    :std_logic;

signal all_clk_locked          :std_logic;

-----------------------------------------------------------------------------------
--component declarations
-----------------------------------------------------------------------------------
    
component sys_clk_pll is
port
 (-- Clock in ports
  clk_in1           : in     std_logic;
  -- Clock out ports
  clk_out1          : out    std_logic;
  clk_out2          : out    std_logic;
  clk_out3          : out    std_logic;
  clk_out4          : out    std_logic;
  clk_out5          : out    std_logic;
  -- Status and control signals
  reset             : in     std_logic;
  locked            : out    std_logic
 );
end component;

begin

-----------------------------------------------------------------------------------
--component instantiations
-----------------------------------------------------------------------------------

clk_300_0buff : ibufds
  port map
  (
     i     =>sys_clk1_p,
     ib    =>sys_clk1_n,
     o     =>clk300_i
     );
     
clk_300_0buffg : bufg
  port map
  (
     i     =>clk300_i ,
     o     =>clk300_gb
     );
     
clk300_ddr4_gb <= clk300_gb;


-----------------------------------------------------------------------------------
-- FPGA ref clock coming from SI5338 device
-----------------------------------------------------------------------------------
   
fpgarefclk_0buff : ibufds
  port map
  (
     i     =>sys_clk2_p,
     ib    =>sys_clk2_n,
     o     =>fpga_ref_clk_i
     );
    
     
fpgarefclk_0buffg : bufg
  port map
  (
     i     =>fpga_ref_clk_i ,
     o     =>fpga_ref_clk_gb
     );    
          
-----------------------------------------------------------------------------------
-- System PLL
-----------------------------------------------------------------------------------
     
i_sys_clk_pll:sys_clk_pll
  port map
  (
    clk_in1           => clk300_gb,
    
    -- Clock out ports
    clk_out1          => clk_10M,
    clk_out2          => clk_50M,
    clk_out3          => clk_100M,
    clk_out4          => clk_125M,
    clk_out5          => clk_200M,
    
    -- Status and control signals
    reset             => reset_i,
    locked            => pll_locked
  );
  
dlyctrl0 : idelayctrl
  generic map (
    SIM_DEVICE => "ULTRASCALE"  -- Set the device version (7SERIES, ULTRASCALE)
  )
   port map
   (
      rdy      => dly_ready_o_sig,
      refclk   => clk300_gb ,
      rst      => dcm_reseti
   );
   
reset_i <= reset_in;

-- Sync dcm_reset to refclk according to datasheet
dcmreset_proc: process(clk300_gb , pll_locked)
begin
   if (pll_locked = '0') then
      dcm_reset_i_reg    <= '1';
      dcm_reset_i_reg2   <= '1';  
      dcm_reseti         <= '1';  
   elsif(clk300_gb'event and clk300_gb='1') then
      dcm_reset_i_reg    <= dcm_reset;
      dcm_reset_i_reg2   <= dcm_reset_i_reg;
      dcm_reseti         <= dcm_reset_i_reg2;
   end if;  
end process;
     
-----------------------------------------------------------------------------------
--synchronous processes
-----------------------------------------------------------------------------------
      
reset_sm_proc: process(clk_200M , pll_locked)
variable wait_cnt :integer range 0 to reset1_cnt;
begin
   if (pll_locked = '0') then
      reset_i_reg    <= '1';
      reset_i_reg2   <= '1';    
   elsif(clk_200M'event and clk_200M='1') then
      reset_i_reg    <=reset_i;
      reset_i_reg2   <= reset_i_reg;
      
      if (reset_i_reg2= '1') then
         reset_sm       <= reset_all;
         reset_sm_prev  <= reset_all;
         wait_cnt       := 0;
         all_clk_locked <= '0';

      else

         all_clk_locked <=  (pll_locked);
         reset_sm_prev <= reset_sm;
         case reset_sm  is
            when reset_all =>
               if (all_clk_locked = '1' and wait_cnt = 16) then
                  reset_sm <= reset_dcm;
                  wait_cnt :=0;
               elsif (all_clk_locked = '1') then
                  reset_sm <= reset_all;
                  wait_cnt := wait_cnt+1;
               else
                  reset_sm <= reset_all;
                  wait_cnt := wait_cnt;
               end if;

            when reset_dcm =>
               if (wait_cnt = 8) then
                  reset_sm <= wait_dcm_lock;
                  wait_cnt :=0;
               else
                  reset_sm <= reset_dcm;
                  wait_cnt := wait_cnt +1;
               end if;
            when wait_dcm_lock =>
               if (all_clk_locked = '1' and wait_cnt = 16 and (dly_ready_o_sig='1' or reset_i_reg2='0')) then
                  reset_sm <= wait_reset1;
                  wait_cnt :=0;
               elsif (all_clk_locked = '1' and (dly_ready_o_sig='1' or reset_i_reg2='0')) then
                  reset_sm <= wait_dcm_lock;
                  wait_cnt := wait_cnt+1;
               else
                  reset_sm <= wait_dcm_lock;
                  wait_cnt := wait_cnt;
               end if;

            when wait_reset1 =>
               if (all_clk_locked = '0' ) then
                  reset_sm <= reset_all;
               elsif(wait_cnt = reset1_cnt) then
                  reset_sm <= wait_reset2;
                  wait_cnt :=0;
               else
                  reset_sm <= wait_reset1;
                  wait_cnt := wait_cnt+1;
               end if;
            when wait_reset2 =>
               if (all_clk_locked = '0' ) then
                  reset_sm <= reset_all;
               elsif(wait_cnt = reset2_cnt) then
                  reset_sm <= wait_reset3;
                  wait_cnt :=0;
               else
                  reset_sm <= wait_reset2;
                  wait_cnt := wait_cnt+1;
               end if;
            when wait_reset3 =>
               if (all_clk_locked = '0' ) then
                  reset_sm <= reset_all;
               elsif(wait_cnt = reset3_cnt) then
                  reset_sm <= idle;
                  wait_cnt :=0;
               else
                  reset_sm <= wait_reset3;
                  wait_cnt := wait_cnt+1;
               end if;
            when idle =>
               if (all_clk_locked = '0' ) then
                  reset_sm <= reset_all;
               else
                  reset_sm <= idle;
               end if;
            when others=>
               reset_sm <= reset_all;
         end case;
      end if;
   end if;
end process;

reset_proc: process(clk_200M )
begin
   if(clk_200M'event and clk_200M='1') then
      if (reset_i_reg2= '1') then
         reset1_sig      <= '1';
         reset2_sig      <= '1';
         reset3_sig      <= '1';
         dcm_reset       <= '1';
      else
         --reset the DCM only when the SM asks to do so
         if (reset_sm = reset_dcm) then
            dcm_reset      <= '1';
         else
            dcm_reset      <= '0';
         end if;

         --reset1 is deaserted when the reset_sm exits the wait_reset1 state
         if (reset_sm = wait_reset2 and reset_sm_prev = wait_reset1) then
            reset1_sig      <= '0';
         elsif (reset_sm = reset_all) then
            reset1_sig     <= '1';
         end if;

         --reset2 is deaserted when the reset_sm exits the wait_reset2 state
         if (reset_sm = wait_reset3 and reset_sm_prev = wait_reset2) then
            reset2_sig      <= '0';
         elsif (reset_sm = reset_all) then
            reset2_sig     <= '1';
         end if;
         --reset2 is deaserted when the reset_sm exits the wait_reset2 state
         if (reset_sm = idle and reset_sm_prev = wait_reset3) then
            reset3_sig      <= '0';
         elsif (reset_sm = reset_all) then
            reset3_sig     <= '1';
         end if;

      end if;
   end if;
end process;

-- double sync
reset_proc2: process(axi_clk_in )
begin
   if(axi_clk_in'event and axi_clk_in='1') then
        reset1_sigi <= reset1_sig;
        reset1_o    <= reset1_sigi;
        reset2_sigi <= reset2_sig;
		reset2_o    <= reset2_sigi;
        reset3_sigi <= reset3_sig;
		reset3_o    <= reset3_sigi;
   end if;
end process;


-----------------------------------------------------------------------------------
--asynchronous processes
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--asynchronous mapping
-----------------------------------------------------------------------------------

clk200M_o   <= clk_200M;
clk_125Mo   <= clk_125M;
clk_100Mo   <= clk_100M;
clk_50Mo    <= clk_50M;
clk_10Mo    <= clk_10M;

end architecture arch_clkrst_pc821   ; -- of clkrst_pc821

