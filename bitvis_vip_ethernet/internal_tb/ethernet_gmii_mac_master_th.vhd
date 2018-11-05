--========================================================================================================================
-- Copyright (c) 2018 by Bitvis AS.  All rights reserved.
-- You should have received a copy of the license file containing the MIT License (see LICENSE.TXT), if not,
-- contact Bitvis AS <support@bitvis.no>.
--
-- UVVM AND ANY PART THEREOF ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
-- WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
-- OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH UVVM OR THE USE OR OTHER DEALINGS IN UVVM.
--========================================================================================================================

------------------------------------------------------------------------------------------
-- Description   : See library quick reference (under 'doc') and README-file(s)
------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_gmii;
context bitvis_vip_gmii.vvc_context;

library bitvis_vip_ethernet;
context bitvis_vip_ethernet.hvvc_context;
use bitvis_vip_ethernet.ethernet_gmii_mac_master_pkg.all;

library mac_master;
use mac_master.ethernet_types.all;
use mac_master.utility.all;

--=================================================================================================
entity gmii_mac_master_test_harness is
  generic(
    GC_CLK_PERIOD  : time;
    GC_MAC_ADDRESS : unsigned(47 downto 0)
  );
  port(
    if_in  : in  t_if_in;
    if_out : out t_if_out
  );
end entity gmii_mac_master_test_harness;


--=================================================================================================
--=================================================================================================

architecture struct of gmii_mac_master_test_harness is

  signal clk              : std_logic;
  signal reset            : std_logic;
  signal gmii_to_dut_if   : t_gmii_to_dut_if;
  signal gmii_from_dut_if : t_gmii_from_dut_if;

begin

  reset <= '1' after 0 ns, '0' after 10 ns;

  p_clk : clock_generator(clk, GC_CLK_PERIOD);

  if_out.clk                   <= clk;
  gmii_to_dut_if.rxclk <= clk;

  -----------------------------
  -- vvc/executors
  -----------------------------
  i_ethernet_vvc : entity bitvis_vip_ethernet.ethernet_vvc
    generic map(
      GC_INSTANCE_IDX     => 1,
      GC_INTERFACE        => GMII,
      GC_VVC_INSTANCE_IDX => 1
    );

  i_gmii_vvc : entity bitvis_vip_gmii.gmii_vvc
    generic map(
      GC_INSTANCE_IDX                       => 1,
      GC_GMII_BFM_CONFIG                    => C_GMII_BFM_CONFIG_DEFAULT,
      GC_CMD_QUEUE_COUNT_MAX                => 500,
      GC_CMD_QUEUE_COUNT_THRESHOLD          => 450,
      GC_CMD_QUEUE_COUNT_THRESHOLD_SEVERITY => WARNING
    )
    port map(
      gmii_to_dut_if   => gmii_to_dut_if,
      gmii_from_dut_if => gmii_from_dut_if
    );

  -----------------------------
  -- Ethernet MAC
  -----------------------------
  i_ethernet_mac : entity mac_master.ethernet_with_fifos
    generic map(
      MIIM_DISABLE => TRUE
    )
    port map(
      -- Unbuffered 125 MHz clock input
      clock_125_i      => clk,
      -- Asynchronous reset
      reset_i          => reset,
      -- MAC address of this station
      -- Must not change after reset is deasserted
      mac_address_i    => t_mac_address(reverse_bytes(std_ulogic_vector(GC_MAC_ADDRESS))),
      -- MII (Media-independent interface)
      mii_tx_clk_i     => clk,
      mii_tx_er_o      => open,
      mii_tx_en_o      => gmii_from_dut_if.txen,
      mii_txd_o        => gmii_from_dut_if.txd,
      mii_rx_clk_i     => clk,
      mii_rx_er_i      => '0',
      mii_rx_dv_i      => gmii_to_dut_if.rxdv,
      mii_rxd_i        => gmii_to_dut_if.rxd,

    -- GMII (Gigabit media-independent interface)
    gmii_gtx_clk_o     => gmii_from_dut_if.gtxclk,

    -- RGMII (Reduced pin count gigabit media-independent interface)
    rgmii_tx_ctl_o     => open,
    rgmii_rx_ctl_i     => '0',

    -- MII Management Interface
    -- Clock, can be identical to clock_125_i
    -- If not, adjust MIIM_CLOCK_DIVIDER accordingly
    miim_clock_i       => clk,
    mdc_o              => open,
    mdio_io            => open,
    -- Status, synchronous to miim_clock_i
    link_up_o          => open,
    speed_o            => open,
    -- Also synchronous to miim_clock_i if used!
    speed_override_i   => SPEED_1000MBPS,

    -- TX FIFO
    tx_clock_i         => clk,
    -- Synchronous reset
    -- When asserted, the content of the buffer was lost.
    -- When full is deasserted the next time, a packet size must be written.
    -- The data of the packet previously being written is not available anymore then.
    tx_reset_o         => if_out.tx_reset_o,
    tx_data_i          => if_in.tx_data_i,
    tx_wr_en_i         => if_in.tx_wr_en_i,
    tx_full_o          => if_out.tx_full_o,

    -- RX FIFO
    rx_clock_i         => clk,
    -- Synchronous reset
    -- When asserted, the content of the buffer was lost.
    -- When empty is deasserted the next time, a packet size must be read out.
    -- The data of the packet previously being read out is not available anymore then.
    rx_reset_o         => if_out.rx_reset_o,
    rx_empty_o         => if_out.rx_empty_o,
    rx_rd_en_i         => if_in.rx_rd_en_i,
    rx_data_o          => if_out.rx_data_o
  );

end struct;