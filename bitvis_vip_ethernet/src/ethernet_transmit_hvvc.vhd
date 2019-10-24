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

library uvvm_vvc_framework;
use uvvm_vvc_framework.ti_vvc_framework_support_pkg.all;

library bitvis_vip_scoreboard;
use bitvis_vip_scoreboard.generic_sb_support_pkg.all;

library bitvis_vip_hvvc_to_vvc_bridge;
use bitvis_vip_hvvc_to_vvc_bridge.common_methods_pkg.all;

use work.ethernet_bfm_pkg.all;
use work.vvc_methods_pkg.all;
use work.vvc_cmd_pkg.all;
use work.td_target_support_pkg.all;
use work.td_vvc_entity_support_pkg.all;
use work.td_cmd_queue_pkg.all;
use work.td_result_queue_pkg.all;

--========================================================================================================================
entity ethernet_transmit_vvc is
  generic(
    GC_INSTANCE_IDX                          : natural;
    GC_INTERFACE                             : t_interface;
    GC_VVC_INSTANCE_IDX                      : natural;
    GC_DUT_IF_FIELD_CONFIG                   : t_dut_if_field_config_direction_array;
    GC_ETHERNET_BFM_CONFIG                   : t_ethernet_bfm_config := C_ETHERNET_BFM_CONFIG_DEFAULT;
    GC_CMD_QUEUE_COUNT_MAX                   : natural               := 1000;
    GC_CMD_QUEUE_COUNT_THRESHOLD             : natural               := 950;
    GC_CMD_QUEUE_COUNT_THRESHOLD_SEVERITY    : t_alert_level         := WARNING;
    GC_RESULT_QUEUE_COUNT_MAX                : natural               := 1000;
    GC_RESULT_QUEUE_COUNT_THRESHOLD          : natural               := 950;
    GC_RESULT_QUEUE_COUNT_THRESHOLD_SEVERITY : t_alert_level         := WARNING
  );
end entity ethernet_transmit_vvc;

--========================================================================================================================
--========================================================================================================================
architecture behave of ethernet_transmit_vvc is

  constant C_CHANNEL    : t_channel     := TX;
  constant C_SCOPE      : string        := C_VVC_NAME & "," & to_string(GC_INSTANCE_IDX);
  constant C_VVC_LABELS : t_vvc_labels  := assign_vvc_labels(C_SCOPE, C_VVC_NAME, GC_INSTANCE_IDX, C_CHANNEL);

  signal executor_is_busy       : boolean := false;
  signal queue_is_increasing    : boolean := false;
  signal last_cmd_idx_executed  : natural := 0;
  signal terminate_current_cmd  : t_flag_record;
  signal hvvc_to_bridge         : t_hvvc_to_bridge(data_bytes(0 to C_MAX_PACKET_LENGTH-1));
  signal bridge_to_hvvc         : t_bridge_to_hvvc(data_bytes(0 to C_MAX_PACKET_LENGTH-1));

  -- Instantiation of the element dedicated executor
  shared variable command_queue : work.td_cmd_queue_pkg.t_generic_queue;
  shared variable result_queue  : work.td_result_queue_pkg.t_generic_queue;

  alias vvc_config       : t_vvc_config       is shared_ethernet_vvc_config(C_CHANNEL, GC_INSTANCE_IDX);
  alias vvc_status       : t_vvc_status       is shared_ethernet_vvc_status(C_CHANNEL, GC_INSTANCE_IDX);
  alias transaction_info : t_transaction_info is shared_ethernet_transaction_info(C_CHANNEL, GC_INSTANCE_IDX);
  -- Activity Watchdog
  signal vvc_idx_for_activity_watchdog : integer;

begin

--========================================================================================================================
-- HVVC-to-VVC Bridge
--========================================================================================================================
  i_hvvc_to_vvc_bridge : entity bitvis_vip_hvvc_to_vvc_bridge.hvvc_to_vvc_bridge
    generic map(
      GC_INTERFACE           => GC_INTERFACE,
      GC_INSTANCE_IDX        => GC_VVC_INSTANCE_IDX,
      GC_DUT_IF_FIELD_CONFIG => GC_DUT_IF_FIELD_CONFIG,
      GC_MAX_NUM_BYTES       => C_MAX_PACKET_LENGTH,
      GC_SCOPE               => C_SCOPE
    )
    port map(
      hvvc_to_bridge => hvvc_to_bridge,
      bridge_to_hvvc => bridge_to_hvvc
    );


--========================================================================================================================
-- Constructor
-- - Set up the defaults and show constructor if enabled
--========================================================================================================================
  vvc_constructor(C_SCOPE, GC_INSTANCE_IDX, vvc_config, command_queue, result_queue, GC_ETHERNET_BFM_CONFIG,
                  GC_CMD_QUEUE_COUNT_MAX, GC_CMD_QUEUE_COUNT_THRESHOLD, GC_CMD_QUEUE_COUNT_THRESHOLD_SEVERITY,
                  GC_RESULT_QUEUE_COUNT_MAX, GC_RESULT_QUEUE_COUNT_THRESHOLD, GC_RESULT_QUEUE_COUNT_THRESHOLD_SEVERITY);
--========================================================================================================================


--========================================================================================================================
-- Command interpreter
-- - Interpret, decode and acknowledge commands from the central sequencer
--========================================================================================================================
  cmd_interpreter : process
     variable v_cmd_has_been_acked : boolean; -- Indicates if acknowledge_cmd() has been called for the current shared_vvc_cmd
     variable v_local_vvc_cmd      : t_vvc_cmd_record := C_VVC_CMD_DEFAULT;
     variable v_msg_id_panel       : t_msg_id_panel;
  begin

    -- 0. Initialize the process prior to first command
    initialize_interpreter(terminate_current_cmd, global_awaiting_completion);
    -- initialise shared_vvc_last_received_cmd_idx for channel and instance
    shared_vvc_last_received_cmd_idx(C_CHANNEL, GC_INSTANCE_IDX) := 0;
    -- Register VVC in activity watchdog register
    vvc_idx_for_activity_watchdog <= shared_inactivity_watchdog.priv_register_vvc(name      => "Ethernet_transmit",
                                                                                  instance  => GC_INSTANCE_IDX);
    -- Set initial value of v_msg_id_panel to msg_id_panel in config
    v_msg_id_panel := vvc_config.msg_id_panel;

    -- Then for every single command from the sequencer
    loop  -- basically as long as new commands are received

      -- 1. wait until command targeted at this VVC. Must match VVC name, instance and channel (if applicable)
      --    releases global semaphore
      -------------------------------------------------------------------------
      await_cmd_from_sequencer(C_VVC_LABELS, vvc_config, THIS_VVCT, VVC_BROADCAST, global_vvc_busy, global_vvc_ack, v_local_vvc_cmd, v_msg_id_panel);
      v_cmd_has_been_acked := false; -- Clear flag
      -- Update shared_vvc_last_received_cmd_idx with received command index
      shared_vvc_last_received_cmd_idx(C_CHANNEL, GC_INSTANCE_IDX) := v_local_vvc_cmd.cmd_idx;
      -- Update v_msg_id_panel
      v_msg_id_panel := get_msg_id_panel(v_local_vvc_cmd, vvc_config);

      -- 2a. Put command on the executor if intended for the executor
      -------------------------------------------------------------------------
      if v_local_vvc_cmd.command_type = QUEUED then
        put_command_on_queue(v_local_vvc_cmd, command_queue, vvc_status, queue_is_increasing);

      -- 2b. Otherwise command is intended for immediate response
      -------------------------------------------------------------------------
      elsif v_local_vvc_cmd.command_type = IMMEDIATE then
        case v_local_vvc_cmd.operation is

          when AWAIT_COMPLETION =>
            -- Await completion of all commands in the cmd_executor executor
            interpreter_await_completion(v_local_vvc_cmd, command_queue, vvc_config, executor_is_busy, C_VVC_LABELS, last_cmd_idx_executed);

          when AWAIT_ANY_COMPLETION =>
            if not v_local_vvc_cmd.gen_boolean then
              -- Called with lastness = NOT_LAST: Acknowledge immediately to let the sequencer continue
              acknowledge_cmd(global_vvc_ack,v_local_vvc_cmd.cmd_idx);
              v_cmd_has_been_acked := true;
            end if;
            interpreter_await_any_completion(v_local_vvc_cmd, command_queue, vvc_config, executor_is_busy, C_VVC_LABELS, last_cmd_idx_executed, global_awaiting_completion);

          when DISABLE_LOG_MSG =>
            disable_log_msg(v_local_vvc_cmd.msg_id, vvc_config.msg_id_panel, to_string(v_local_vvc_cmd.msg) & format_command_idx(v_local_vvc_cmd), C_SCOPE, v_local_vvc_cmd.quietness);

          when ENABLE_LOG_MSG =>
            enable_log_msg(v_local_vvc_cmd.msg_id, vvc_config.msg_id_panel, to_string(v_local_vvc_cmd.msg) & format_command_idx(v_local_vvc_cmd), C_SCOPE, v_local_vvc_cmd.quietness);

          when FLUSH_COMMAND_QUEUE =>
            interpreter_flush_command_queue(v_local_vvc_cmd, command_queue, vvc_config, vvc_status, C_VVC_LABELS);

          when TERMINATE_CURRENT_COMMAND =>
            interpreter_terminate_current_command(v_local_vvc_cmd, vvc_config, C_VVC_LABELS, terminate_current_cmd);

          when others =>
            tb_error("Unsupported command received for IMMEDIATE execution: '" & to_string(v_local_vvc_cmd.operation) & "'", C_SCOPE);

        end case;

      else
        tb_error("command_type is not IMMEDIATE or QUEUED", C_SCOPE);
      end if;

      -- 3. Acknowledge command after runing or queuing the command
      -------------------------------------------------------------------------
      if not v_cmd_has_been_acked then
        acknowledge_cmd(global_vvc_ack,v_local_vvc_cmd.cmd_idx);
      end if;

    end loop;
  end process;
--========================================================================================================================



--========================================================================================================================
-- Command executor
-- - Fetch and execute the commands
--========================================================================================================================
  cmd_executor : process
    constant C_TRANSMIT_PROC_CALL                    : string := "Ethernet transmit";

    variable v_cmd                                   : t_vvc_cmd_record;
    variable v_timestamp_start_of_current_bfm_access : time := 0 ns;
    variable v_timestamp_start_of_last_bfm_access    : time := 0 ns;
    variable v_timestamp_end_of_last_bfm_access      : time := 0 ns;
    variable v_command_is_bfm_access                 : boolean := false;
    variable v_prev_command_was_bfm_access           : boolean := false;
    variable v_msg_id_panel                          : t_msg_id_panel;
    variable v_ethernet_packet_raw                   : t_byte_array(0 to C_MAX_PACKET_LENGTH-1);
    variable v_length                                : std_logic_vector(15 downto 0);
    variable v_payload_length                        : natural;
    variable v_crc_32                                : std_logic_vector(31 downto 0);
    variable v_cmd_idx                               : natural;
    variable v_ethernet_frame                        : t_ethernet_frame;

    procedure activity_watchdog_register_vvc_state(busy : boolean) is
    begin
      shared_inactivity_watchdog.priv_report_vvc_activity(vvc_idx               => vvc_idx_for_activity_watchdog,
                                                          busy                  => busy,
                                                          last_cmd_idx_executed => last_cmd_idx_executed);
      gen_pulse(global_trigger_testcase_inactivity_watchdog, 0 ns, "pulsing global trigger for inactivity watchdog");
    end procedure;
  
    -- Local overload
    procedure blocking_send_to_bridge(
      constant data_bytes                : in  t_byte_array;
      constant dut_if_field_idx          : in  integer
    ) is
      constant C_CURRENT_BYTE_IDX_IN_FIELD : natural := 0;
    begin
      blocking_send_to_bridge(hvvc_to_bridge, bridge_to_hvvc, TRANSMIT, data_bytes, dut_if_field_idx, C_CURRENT_BYTE_IDX_IN_FIELD, v_msg_id_panel, vvc_config.field_timeout_margin);
    end procedure blocking_send_to_bridge;

  begin

    -- Notify activity watchdog
    activity_watchdog_register_vvc_state(false);

    -- 0. Initialize the process prior to first command
    -------------------------------------------------------------------------
    initialize_executor(terminate_current_cmd);

    -- Notify activity watchdog
    activity_watchdog_register_vvc_state(true);

    -- Set initial value of v_msg_id_panel to msg_id_panel in config
    v_msg_id_panel := vvc_config.msg_id_panel;

    loop

      -- 1. Set defaults, fetch command and log
      -------------------------------------------------------------------------
      fetch_command_and_prepare_executor(v_cmd, command_queue, vvc_config, vvc_status, queue_is_increasing, executor_is_busy, C_VVC_LABELS, v_msg_id_panel);

      -- Reset the transaction info for waveview
      transaction_info := C_TRANSACTION_INFO_DEFAULT;
      transaction_info.operation := v_cmd.operation;
      transaction_info.msg := pad_string(to_string(v_cmd.msg), ' ', transaction_info.msg'length);

      -- Update v_msg_id_panel
      v_msg_id_panel := get_msg_id_panel(v_cmd, vvc_config);

      -- Check if command is a BFM access
      v_prev_command_was_bfm_access := v_command_is_bfm_access; -- save for inter_bfm_delay

      if v_cmd.operation = TRANSMIT then  -- Replace this line with actual check
        v_command_is_bfm_access := true;
      else
        v_command_is_bfm_access := false;
      end if;

      -- Insert delay if needed
      insert_inter_bfm_delay_if_requested(vvc_config                         => vvc_config,
                                          command_is_bfm_access              => v_prev_command_was_bfm_access,
                                          timestamp_start_of_last_bfm_access => v_timestamp_start_of_last_bfm_access,
                                          timestamp_end_of_last_bfm_access   => v_timestamp_end_of_last_bfm_access,
                                          scope                              => C_SCOPE,
                                          msg_id_panel                       => v_msg_id_panel);

      if v_command_is_bfm_access then
        v_timestamp_start_of_current_bfm_access := now;
      end if;

      -- 2. Execute the fetched command
      -------------------------------------------------------------------------
      case v_cmd.operation is  -- Only operations in the dedicated record are relevant

        -- VVC dedicated operations
        --===================================

        when TRANSMIT =>
          -- Preamble
          for i in 0 to 6 loop
            v_ethernet_packet_raw(i) := C_PREAMBLE(55-(i*8) downto 55-(i*8)-7);
          end loop;

          -- SFD
          v_ethernet_packet_raw(7) := C_SFD;

          -- MAC destination
          v_ethernet_packet_raw(8 to 13)   := to_byte_array(std_logic_vector(v_cmd.mac_destination));
          v_ethernet_frame.mac_destination := v_cmd.mac_destination;

          -- MAC source
          v_ethernet_packet_raw(14 to 19) := to_byte_array(std_logic_vector(v_cmd.mac_source));
          v_ethernet_frame.mac_source     := v_cmd.mac_source;

          -- Length
          v_payload_length          := v_cmd.length;
          v_length                  := std_logic_vector(to_unsigned(v_cmd.length, 16));
          v_ethernet_packet_raw(20) := v_length(15 downto 8);
          v_ethernet_packet_raw(21) := v_length( 7 downto 0);
          v_ethernet_frame.length   := v_cmd.length;

          -- Payload
          v_ethernet_packet_raw(22 to 22+v_cmd.length-1) := v_cmd.payload(0 to v_cmd.length-1);
          v_ethernet_frame.payload := v_cmd.payload;

          -- Pad if length is less than C_MIN_PAYLOAD_LENGTH(46)
          if v_cmd.length < C_MIN_PAYLOAD_LENGTH then
            v_payload_length := C_MIN_PAYLOAD_LENGTH;
            v_ethernet_packet_raw(22+v_cmd.length to 22+v_payload_length) := (others => (others => '0'));
          end if;


          -- FCS
          v_crc_32 := generate_crc_32_complete(reverse_vectors_in_array(v_ethernet_packet_raw(8 to 22+v_payload_length-1)));
          v_crc_32 := not(v_crc_32);
          v_ethernet_packet_raw(22+v_payload_length to 22+v_payload_length+3) := reverse_vectors_in_array(to_byte_array(v_crc_32));
          v_ethernet_frame.fcs := v_crc_32;

          -- Add info to the transaction_for_waveview_struct
          transaction_info.ethernet_frame := v_ethernet_frame;

          -- Send to bridge
          log(ID_PACKET_INITIATE, C_TRANSMIT_PROC_CALL & ": Start transmitting ethernet packet. " & complete_to_string(v_ethernet_frame) & format_command_idx(v_cmd.cmd_idx), C_SCOPE, v_msg_id_panel);
          blocking_send_to_bridge(v_ethernet_packet_raw( 0 to  7),                                     C_IF_FIELD_NUM_ETHERNET_PREAMBLE_SFD);

          log(ID_PACKET_HDR, C_TRANSMIT_PROC_CALL & ": Transmitting header." & format_command_idx(v_cmd.cmd_idx) & hdr_to_string(v_ethernet_frame), C_SCOPE, v_msg_id_panel);
          blocking_send_to_bridge(v_ethernet_packet_raw( 8 to 13),                                     C_IF_FIELD_NUM_ETHERNET_MAC_DESTINATION);
          blocking_send_to_bridge(v_ethernet_packet_raw(14 to 19),                                     C_IF_FIELD_NUM_ETHERNET_MAC_SOURCE);
          blocking_send_to_bridge(v_ethernet_packet_raw(20 to 21),                                     C_IF_FIELD_NUM_ETHERNET_LENTGTH);

          log(ID_PACKET_DATA, C_TRANSMIT_PROC_CALL & ": Transmitting payload." & format_command_idx(v_cmd.cmd_idx) & data_to_string(v_ethernet_frame), C_SCOPE, v_msg_id_panel);
          blocking_send_to_bridge(v_ethernet_packet_raw(22 to 22+v_payload_length-1),                  C_IF_FIELD_NUM_ETHERNET_PAYLOAD);
          blocking_send_to_bridge(v_ethernet_packet_raw(22+v_payload_length to 22+v_payload_length+3), C_IF_FIELD_NUM_ETHERNET_FCS);

          -- Interpacket gap
          wait for vvc_config.bfm_config.interpacket_gap_time;

          log(ID_PACKET_COMPLETE, C_TRANSMIT_PROC_CALL & ": Finished transmitting ethernet packet." & format_command_idx(v_cmd.cmd_idx), C_SCOPE, v_msg_id_panel);


        -- UVVM common operations
        --===================================
        when INSERT_DELAY =>
          log(ID_INSERTED_DELAY, "Running: " & to_string(v_cmd.proc_call) & " " & format_command_idx(v_cmd), C_SCOPE, v_msg_id_panel);
          if v_cmd.gen_integer_array(0) = -1 then
            -- Delay specified using time
            wait until terminate_current_cmd.is_active = '1' for v_cmd.delay;
          else
            -- Delay specified using integer
            --wait until terminate_current_cmd.is_active = '1' for v_cmd.gen_integer_array(0) * vvc_config.bfm_config.clock_period;
          end if;

        when others =>
          tb_error("Unsupported local command received for execution: '" & to_string(v_cmd.operation) & "'", C_SCOPE);
      end case;

      if v_command_is_bfm_access then
        v_timestamp_end_of_last_bfm_access := now;
        v_timestamp_start_of_last_bfm_access := v_timestamp_start_of_current_bfm_access;
        if ((vvc_config.inter_bfm_delay.delay_type = TIME_START2START) and
           ((now - v_timestamp_start_of_current_bfm_access) > vvc_config.inter_bfm_delay.delay_in_time)) then
          alert(vvc_config.inter_bfm_delay.inter_bfm_delay_violation_severity, "BFM access exceeded specified start-to-start inter-bfm delay, " &
                to_string(vvc_config.inter_bfm_delay.delay_in_time) & ".", C_SCOPE);
        end if;
      end if;

      -- Reset terminate flag if any occurred
      if (terminate_current_cmd.is_active = '1') then
        log(ID_CMD_EXECUTOR, "Termination request received", C_SCOPE, v_msg_id_panel);
        uvvm_vvc_framework.ti_vvc_framework_support_pkg.reset_flag(terminate_current_cmd);
      end if;

      last_cmd_idx_executed <= v_cmd.cmd_idx;
      -- Reset the transaction info for waveview
      transaction_info   := C_TRANSACTION_INFO_DEFAULT;

    end loop;
  end process;
--========================================================================================================================



--========================================================================================================================
-- Command termination handler
-- - Handles the termination request record (sets and resets terminate flag on request)
--========================================================================================================================
  cmd_terminator : uvvm_vvc_framework.ti_vvc_framework_support_pkg.flag_handler(terminate_current_cmd);  -- flag: is_active, set, reset
--========================================================================================================================

end behave;


