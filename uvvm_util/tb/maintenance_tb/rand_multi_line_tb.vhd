--================================================================================================================================
-- Copyright 2020 Bitvis
-- Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 and in the provided LICENSE.TXT.
--
-- Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
-- an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and limitations under the License.
--================================================================================================================================
-- Note : Any functionality not explicitly described in the documentation is subject to change at any time
----------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------
-- Description : See library quick reference (under 'doc') and README-file(s)
---------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use work.rand_tb_pkg.all;

--HDLUnit:TB
entity rand_multi_line_tb is
  generic(
    GC_TESTCASE : string
  );
end entity;

architecture func of rand_multi_line_tb is

  constant C_NUM_RAND_REPETITIONS   : natural := 7;
  --constant C_NUM_WEIGHT_REPETITIONS : natural := 1000; -- Changing this value affects check_weight_distribution() C_MARGIN.
  --constant C_NUM_CYCLIC_REPETITIONS : natural := 3;

begin

  --------------------------------------------------------------------------------
  -- PROCESS: p_main
  --------------------------------------------------------------------------------
  p_main : process
    variable v_rand          : t_rand;
    variable v_seeds         : t_positive_vector(0 to 1);
    variable v_int           : integer;
    variable v_prev_int      : integer := 0;
    variable v_real          : real;
    --variable v_time          : time;
    variable v_int_vec       : integer_vector(0 to 4);
    variable v_prev_int_vec  : integer_vector(0 to 4) := (others => 0);
    --variable v_real_vec      : real_vector(0 to 4);
    --variable v_time_vec      : time_vector(0 to 4);
    variable v_uns           : unsigned(3 downto 0);
    --variable v_uns_long      : unsigned(127 downto 0);
    --variable v_uns_long_min  : unsigned(127 downto 0);
    --variable v_uns_long_max  : unsigned(127 downto 0);
    --variable v_prev_uns_long : unsigned(127 downto 0) := (others => '0');
    --variable v_sig           : signed(3 downto 0);
    --variable v_sig_long      : signed(127 downto 0);
    --variable v_sig_long_min  : signed(127 downto 0);
    --variable v_sig_long_max  : signed(127 downto 0);
    --variable v_prev_sig_long : signed(127 downto 0) := (others => '0');
    --variable v_slv           : std_logic_vector(3 downto 0);
    --variable v_slv_long      : std_logic_vector(127 downto 0);
    --variable v_slv_long_min  : std_logic_vector(127 downto 0);
    --variable v_slv_long_max  : std_logic_vector(127 downto 0);
    --variable v_prev_slv_long : std_logic_vector(127 downto 0) := (others => '0');
    --variable v_std           : std_logic;
    --variable v_bln           : boolean;
    variable v_value_cnt     : t_integer_cnt(-32 to 31) := (others => 0);
    variable v_num_values    : natural;
    --variable v_bit_check     : std_logic_vector(1 downto 0);
    --variable v_mean          : real;
    --variable v_std_deviation : real;

  begin

    -------------------------------------------------------------------------------------
    log(ID_LOG_HDR_LARGE, "Start Simulation of Randomization package - " & GC_TESTCASE);
    -------------------------------------------------------------------------------------
    enable_log_msg(ID_RAND_GEN);
    enable_log_msg(ID_RAND_CONF);

    v_rand.report_config(VOID);

    --===================================================================================
    if GC_TESTCASE = "rand_basic" then
    --===================================================================================
      v_rand.set_name("long_string_abcdefghijklmnopqrstuvwxyz");
      check_value(v_rand.get_name(VOID), "long_string_abcdefgh", ERROR, "Checking name"); -- C_RAND_MAX_NAME_LENGTH = 20
      v_rand.set_scope("long_string_abcdefghijklmnopqrstuvwxyz");
      check_value(v_rand.get_scope(VOID), "long_string_abcdefghijklmnopqr", ERROR, "Checking scope"); -- C_LOG_SCOPE_WIDTH = 30

      v_rand.set_name("MY_RAND_GEN");
      check_value(v_rand.get_name(VOID), "MY_RAND_GEN", ERROR, "Checking name");
      v_rand.set_scope("MY SCOPE");
      check_value(v_rand.get_scope(VOID), "MY SCOPE", ERROR, "Checking scope");

      ------------------------------------------------------------
      log(ID_LOG_HDR, "Testing seeds");
      ------------------------------------------------------------
      log(ID_SEQUENCER, "Check default seed values");
      v_seeds := v_rand.get_rand_seeds(VOID);
      check_value(v_seeds(0), C_RAND_INIT_SEED_1, ERROR, "Checking initial seed 1");
      check_value(v_seeds(1), C_RAND_INIT_SEED_2, ERROR, "Checking initial seed 2");

      log(ID_SEQUENCER, "Set and get seeds with vector value");
      v_seeds(0) := 500;
      v_seeds(1) := 5000;
      v_rand.set_rand_seeds(v_seeds);
      v_seeds := v_rand.get_rand_seeds(VOID);
      check_value(v_seeds(0), 500, ERROR, "Checking seed 1");
      check_value(v_seeds(1), 5000, ERROR, "Checking seed 2");

      log(ID_SEQUENCER, "Set and get seeds with positive values");
      v_seeds(0) := 800;
      v_seeds(1) := 8000;
      v_rand.set_rand_seeds(v_seeds(0), v_seeds(1));
      v_rand.get_rand_seeds(v_seeds(0), v_seeds(1));
      check_value(v_seeds(0), 800, ERROR, "Checking seed 1");
      check_value(v_seeds(1), 8000, ERROR, "Checking seed 2");

      log(ID_SEQUENCER, "Set seeds with string value");
      v_rand.set_rand_seeds(v_rand'instance_name);
      v_seeds := v_rand.get_rand_seeds(VOID);
      check_value(v_seeds(0) /= 800, ERROR, "Checking initial seed 1");
      check_value(v_seeds(1) /= 8000, ERROR, "Checking initial seed 2");

      ------------------------------------------------------------
      -- Integer
      ------------------------------------------------------------
      log(ID_LOG_HDR, "Testing integer (unconstrained)");
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, (0 => (integer'left,integer'right)));
        -- Since range of values is too big, we only check that the value is different than the previous one
        check_value(v_int /= v_prev_int, TB_ERROR, "Checking value is different than previous one");
        v_prev_int := v_int;
      end loop;

      log(ID_LOG_HDR, "Testing integer (range)");
      v_num_values := 5;
      v_rand.add_range(-2, 2);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, (0 => (-2,2)));
        count_rand_value(v_value_cnt, v_int);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 12;
      v_rand.add_range(8, 9);
      v_rand.add_range(15, 16);
      v_rand.add_range(-7, -5);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS*2 loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, ((-2,2),(8,9),(15,16),(-7,-5)));
        count_rand_value(v_value_cnt, v_int);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer (set of values)");
      v_num_values := 7;
      v_rand.add_val(10);
      v_rand.add_val(20);
      v_rand.add_val((-5,-3,4));
      v_rand.add_val((6,8));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, ONLY,(-5,-3,4,6,8,10,20));
        count_rand_value(v_value_cnt, v_int);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer (range + set of values)");
      v_num_values := 4;
      v_rand.add_range(-1, 1);
      v_rand.add_val(10);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, (0 => (-1,1)), ADD,(0 => 10));
        count_rand_value(v_value_cnt, v_int);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 9;
      v_rand.add_range(8, 9);
      v_rand.add_val((-5,-3,4));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, ((-1,1),(8,9)), ADD,(-5,-3,4,10));
        count_rand_value(v_value_cnt, v_int);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer (range + exclude values)");
      v_num_values := 2;
      v_rand.add_range(-2, 2);
      v_rand.excl_val((-1,0,1));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, (0 => (-2,2)), EXCL,(-1,0,1));
        count_rand_value(v_value_cnt, v_int);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 4;
      v_rand.add_range(8, 10);
      v_rand.excl_val(10);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, ((-2,2),(8,10)), EXCL,(-1,0,1,10));
        count_rand_value(v_value_cnt, v_int);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer (set of values + exclude values)");
      v_num_values := 4;
      v_rand.add_val((-6,-4,-2,0,2,4,6));
      v_rand.excl_val((-2,0,2));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, ONLY,(-6,-4,4,6));
        count_rand_value(v_value_cnt, v_int);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer (range + set of values + exclude values)");
      v_num_values := 5;
      v_rand.add_range(-2, 2);
      v_rand.add_val((-5,-3,4));
      v_rand.excl_val((-5,-1,1));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, (0 => (-2,2)), ADD,(-5,-3,4), EXCL,(-5,-1,1));
        count_rand_value(v_value_cnt, v_int);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 8;
      v_rand.add_range(8, 10);
      v_rand.add_val((20,30,40));
      v_rand.excl_val((9,30,40));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, ((-2,2),(8,10)), ADD,(-5,-3,4,20,30,40), EXCL,(-5,-1,1,9,30,40));
        count_rand_value(v_value_cnt, v_int);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer (full range)");
      v_rand.add_range(integer'left, -1);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, (0 => (integer'left,-1)));
        -- Since range of values is too big, we only check that the value is different than the previous one
        check_value(v_int /= v_prev_int, TB_ERROR, "Checking value is different than previous one");
        v_prev_int := v_int;
      end loop;

      v_rand.add_range(0, integer'right);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int := v_rand.rand(VOID);
        check_rand_value(v_int, (0 => (integer'left,integer'right)));
        -- Since range of values is too big, we only check that the value is different than the previous one
        check_value(v_int /= v_prev_int, TB_ERROR, "Checking value is different than previous one");
        v_prev_int := v_int;
      end loop;

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer (invalid parameters)");
      increment_expected_alerts_and_stop_limit(TB_ERROR, 2);
      v_rand.add_range(10, 0);
      v_rand.add_range(integer'left, 0);
      v_rand.add_range(0, integer'right);
      v_int := v_rand.rand(VOID);

      v_rand.clear_config(VOID);

      ------------------------------------------------------------
      -- Integer Vector
      ------------------------------------------------------------
      log(ID_LOG_HDR, "Testing integer_vector (unconstrained)");
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, (0 => (integer'left,integer'right)));
        -- Since range of values is too big, we only check that the value is different than the previous one
        check_value(v_int_vec /= v_prev_int_vec, TB_ERROR, "Checking value is different than previous one");
        v_prev_int_vec := v_int_vec;
      end loop;

      log(ID_LOG_HDR, "Testing integer_vector (range)");
      v_num_values := 12;
      v_rand.add_range(-2, 2);
      v_rand.add_range(8, 9);
      v_rand.add_range(15, 16);
      v_rand.add_range(-7, -5);
      v_rand.set_uniqueness(NON_UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS*2 loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ((-2,2),(8,9),(15,16),(-7,-5)));
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.set_uniqueness(UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ((-2,2),(8,9),(15,16),(-7,-5)));
        check_uniqueness(v_int_vec);
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer_vector (set of values)");
      v_num_values := 7;
      v_rand.add_val((-5,-3,4));
      v_rand.add_val((6,8));
      v_rand.add_val(10);
      v_rand.add_val(20);
      v_rand.set_uniqueness(NON_UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ONLY,(-5,-3,4,6,8,10,20));
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.set_uniqueness(UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ONLY,(-5,-3,4,6,8,10,20));
        check_uniqueness(v_int_vec);
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer_vector (range + set of values)");
      v_num_values := 9;
      v_rand.add_range(-1, 1);
      v_rand.add_val((-5,-3));
      v_rand.add_range(8, 9);
      v_rand.add_val((4,10));
      v_rand.set_uniqueness(NON_UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ((-1,1),(8,9)), ADD,(-5,-3,4,10));
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.set_uniqueness(UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ((-1,1),(8,9)), ADD,(-5,-3,4,10));
        check_uniqueness(v_int_vec);
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer_vector (range + exclude values)");
      v_num_values := 7;
      v_rand.add_range(-3, 4);
      v_rand.excl_val((-1,0,1));
      v_rand.add_range(8, 10);
      v_rand.excl_val(10);
      v_rand.set_uniqueness(NON_UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ((-3,4),(8,10)), EXCL,(-1,0,1,10));
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.set_uniqueness(UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ((-3,4),(8,10)), EXCL,(-1,0,1,10));
        check_uniqueness(v_int_vec);
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer_vector (set of values + exclude values)");
      v_num_values := 6;
      v_rand.add_val((-8,-6,-4,-2,0,2,4,6,8));
      v_rand.excl_val((-2,0,2));
      v_rand.set_uniqueness(NON_UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ONLY,(-8,-6,-4,4,6,8));
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.set_uniqueness(UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ONLY,(-8,-6,-4,4,6,8));
        check_uniqueness(v_int_vec);
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer_vector (range + set of values + exclude values)");
      v_num_values := 8;
      v_rand.add_range(-2, 2);
      v_rand.add_val((-5,-3,4));
      v_rand.excl_val((-5,-1,1));
      v_rand.add_range(8, 10);
      v_rand.add_val((20,30,40));
      v_rand.excl_val((9,30,40));
      v_rand.set_uniqueness(NON_UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ((-2,2),(8,10)), ADD,(-5,-3,4,20,30,40), EXCL,(-5,-1,1,9,30,40));
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.set_uniqueness(UNIQUE);
      for i in 1 to C_NUM_RAND_REPETITIONS loop
        v_int_vec := v_rand.rand(v_int_vec'length);
        check_rand_value(v_int_vec, ((-2,2),(8,10)), ADD,(-5,-3,4,20,30,40), EXCL,(-5,-1,1,9,30,40));
        check_uniqueness(v_int_vec);
        count_rand_value(v_value_cnt, v_int_vec);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing integer_vector (invalid parameters)");
      increment_expected_alerts_and_stop_limit(TB_ERROR, 1);
      v_rand.add_val((0,1));
      v_rand.set_uniqueness(UNIQUE);
      v_int_vec := v_rand.rand(v_int_vec'length);

      v_rand.clear_config(VOID);

      ------------------------------------------------------------
      -- Real
      -- It is impossible to verify every value within a real range
      -- is generated, so instead only the rounded values are verified.
      -- There is twice as many repetitions since the values are discrete.
      ------------------------------------------------------------
      log(ID_LOG_HDR, "Testing real (unconstrained)");
      increment_expected_alerts_and_stop_limit(TB_ERROR, 1);
      v_real := v_rand.rand(VOID);

      log(ID_LOG_HDR, "Testing real (range)");
      v_num_values := 3;
      v_rand.add_range_real(-1.0, 1.0);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_real := v_rand.rand(VOID);
        check_rand_value(v_real, (0 => (-1.0,1.0)));
        count_rand_value(v_value_cnt, v_real);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 7;
      v_rand.add_range_real(-5.7, -5.2);
      v_rand.add_range_real(8.0, 9.0);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_real := v_rand.rand(VOID);
        check_rand_value(v_real, ((-5.7,-5.2),(-1.0,1.0),(8.0,9.0)));
        count_rand_value(v_value_cnt, v_real);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing real (set of values)");
      v_num_values := 4;
      v_rand.add_val_real(-10.0);
      v_rand.add_val_real((-2.4,2.7));
      v_rand.add_val_real(6.64);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_real := v_rand.rand(VOID);
        check_rand_value(v_real, ONLY,(-10.0,-2.4,2.7,6.64));
        count_rand_value(v_value_cnt, v_real);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing real (range + set of values)");
      v_num_values := 4;
      v_rand.add_range_real(-1.0, 1.0);
      v_rand.add_val_real(-10.0);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_real := v_rand.rand(VOID);
        check_rand_value(v_real, (0 => (-1.0,1.0)), ADD,(0 => -10.0));
        count_rand_value(v_value_cnt, v_real);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 8;
      v_rand.add_range_real(-5.7, -5.2);
      v_rand.add_val_real((-2.4,2.7));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS*2 loop
        v_real := v_rand.rand(VOID);
        check_rand_value(v_real, ((-1.0,1.0),(-5.7,-5.2)), ADD,(-10.0,-2.4,2.7));
        count_rand_value(v_value_cnt, v_real);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing real (range + exclude values)");
      v_num_values := 3;
      v_rand.add_range_real(-1.0, 1.0);
      v_rand.excl_val_real((-1.0,0.0,1.0));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_real := v_rand.rand(VOID);
        check_rand_value(v_real, (0 => (-1.0,1.0)), EXCL,(-1.0,0.0,1.0));
        count_rand_value(v_value_cnt, v_real);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 5;
      v_rand.add_range_real(-5.7, -5.2);
      v_rand.excl_val_real((-5.7,-5.5,-5.2));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_real := v_rand.rand(VOID);
        check_rand_value(v_real, ((-1.0,1.0),(-5.7,-5.2)), EXCL,(-1.0,0.0,1.0,-5.7,-5.5,-5.2));
        count_rand_value(v_value_cnt, v_real);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing real (set of values + exclude values)");
      v_num_values := 3;
      v_rand.add_val_real((-10.0,-2.4,0.0,2.7,6.64));
      v_rand.excl_val_real((-2.4,0.0));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_real := v_rand.rand(VOID);
        check_rand_value(v_real, ONLY,(-10.0,2.7,6.64));
        count_rand_value(v_value_cnt, v_real);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing real (range + set of values + exclude values)");
      v_num_values := 5;
      v_rand.add_range_real(-1.0, 1.0);
      v_rand.add_val_real((-10.0,-2.4));
      v_rand.excl_val_real((-1.0,0.0,1.0));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_real := v_rand.rand(VOID);
        check_rand_value(v_real, (0 => (-1.0,1.0)), ADD,(-10.0,-2.4), EXCL,(-1.0,0.0,1.0));
        count_rand_value(v_value_cnt, v_real);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 7;
      v_rand.add_range_real(-5.7, -5.2);
      v_rand.add_val_real((2.7,4.6));
      v_rand.excl_val_real((-2.4,2.7));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_real := v_rand.rand(VOID);
        check_rand_value(v_real, ((-1.0,1.0),(-5.7,-5.2)), ADD,(-10.0,-2.4,2.7,4.6), EXCL,(-1.0,0.0,1.0,-2.4,2.7));
        count_rand_value(v_value_cnt, v_real);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing real (invalid parameters)");
      increment_expected_alerts_and_stop_limit(TB_ERROR, 2);
      v_rand.add_range_real(10.0, 10.0);
      v_rand.add_range_real(10.0, 0.0);

      v_rand.clear_config(VOID);

      ------------------------------------------------------------
      -- Unsigned
      ------------------------------------------------------------
      log(ID_LOG_HDR, "Testing unsigned (length)");
      v_num_values := 2**v_uns'length;
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, (0 => (0,2**v_uns'length-1)));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      log(ID_LOG_HDR, "Testing unsigned (range)");
      v_num_values := 4;
      v_rand.add_range(0, 3);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, (0 => (0,3)));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 8;
      v_rand.add_range(8, 9);
      v_rand.add_range(14, 15);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, ((0,3),(8,9),(14,15)));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing unsigned (set of values)");
      v_num_values := 6;
      v_rand.add_val((0,1,2));
      v_rand.add_val(5);
      v_rand.add_val((7,9));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, ONLY,(0,1,2,5,7,9));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing unsigned (exclude)");
      v_num_values := 2**v_uns'length-10;
      v_rand.excl_val((0,1,2,3,4));
      v_rand.excl_val((5,6,7,8,9));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, (0 => (0,2**v_uns'length-1)), EXCL,(0,1,2,3,4,5,6,7,8,9));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing unsigned (range + set of values)");
      v_num_values := 4;
      v_rand.add_range(0, 2);
      v_rand.add_val(10);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, (0 => (0,2)), ADD,(0 => 10));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 8;
      v_rand.add_range(8, 9);
      v_rand.add_val((12,15));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, ((0,2),(8,9)), ADD,(10,12,15));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing unsigned (range + exclude values)");
      v_num_values := 2;
      v_rand.add_range(0, 3);
      v_rand.excl_val((1,2));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, (0 => (0,3)), EXCL,(1,2));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 4;
      v_rand.add_range(8, 10);
      v_rand.excl_val(10);
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, ((0,3),(8,10)), EXCL,(1,2,10));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing unsigned (set of values + exclude values)");
      v_num_values := 4;
      v_rand.add_val((0,2,4,6,8,10,12));
      v_rand.excl_val((2,6,10));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, ONLY,(0,4,8,12));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing unsigned (range + set of values + exclude values)");
      v_num_values := 3;
      v_rand.add_range(0, 2);
      v_rand.add_val((7,8));
      v_rand.excl_val((1,8));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, (0 => (0,2)), ADD,(7,8), EXCL,(1,8));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_num_values := 7;
      v_rand.add_range(4, 6);
      v_rand.add_val((10,12,15));
      v_rand.excl_val((5,15));
      for i in 1 to v_num_values*C_NUM_RAND_REPETITIONS loop
        v_uns := v_rand.rand_mult(v_uns'length);
        check_rand_value(v_uns, ((0,2),(4,6)), ADD,(7,8,10,12,15), EXCL,(1,8,5,15));
        count_rand_value(v_value_cnt, v_uns);
      end loop;
      check_uniform_distribution(v_value_cnt, v_num_values);

      v_rand.clear_config(VOID);

      log(ID_LOG_HDR, "Testing unsigned (invalid parameters)");
      increment_expected_alerts(TB_WARNING, 4);
      v_rand.add_range(0, 2**16);
      v_uns := v_rand.rand_mult(v_uns'length);
      v_rand.clear_config(VOID);

      v_rand.add_val((2**17, 2**18));
      v_uns := v_rand.rand_mult(v_uns'length);
      v_rand.clear_config(VOID);

      v_rand.add_range(-2,2);
      v_uns := v_rand.rand_mult(v_uns'length);

    end if;

    v_rand.report_config(VOID);

    -----------------------------------------------------------------------------
    -- Ending the simulation
    -----------------------------------------------------------------------------
    wait for 1000 ns;             -- Allow some time for completion
    report_alert_counters(FINAL); -- Report final counters and print conclusion (Success/Fail)
    log(ID_LOG_HDR, "SIMULATION COMPLETED");
    -- Finish the simulation
    std.env.stop;
    wait;  -- to stop completely

  end process p_main;

end architecture func;