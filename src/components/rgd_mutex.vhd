library ieee;
use ieee.std_logic_1164.all;
use work.defs.all;

entity mutex is
  port
  (
    R1, R2 : in std_logic;
    G1, G2 : out std_logic
  );
end entity;

architecture impl of mutex is

  signal O1, O2 : std_logic;

begin
  O1 <= not (R1 and O2);
  O2 <= not (R2 and O1);

  G1 <= O2 and not (O1);
  G2 <= O1 and not (O2);
end impl;
library ieee;
use ieee.std_logic_1164.all;
use work.defs.all;
use work.mutex;

entity rgd_mutex is
  --generic for initializing the phase registers
  generic
  (
    PHASE_INIT_IN_A  : std_logic := '0';
    PHASE_INIT_IN_B  : std_logic := '0';
    PHASE_INIT_OUT_A : std_logic := '0';
    PHASE_INIT_OUT_B : std_logic := '0';
    PHASE_INIT_OUT_C : std_logic := '0';
    PHASE_INIT_OUT_D : std_logic := '0'

  );
  port
  (
    rst : in std_logic; -- rst line

    -- Channel A
    inA_req  : in std_logic;
    outA_req : out std_logic;
    inA_done : in std_logic;

    -- Channel B
    inB_req  : in std_logic;
    outB_req : out std_logic;
    inB_done : in std_logic
  );
end entity;

architecture impl of rgd_mutex is

  -- Clock
  signal pulse_a, pulse_b : std_logic;

  -- Input state
  signal a_ready, b_ready : std_logic;

  -- Clock tick
  signal click_a, click_b : std_logic;

  -- Input registers
  signal phase_in_a : std_logic;
  signal phase_in_b : std_logic;

  -- Output registers
  signal phase_out_a : std_logic;
  signal phase_out_b : std_logic;
  signal phase_out_c : std_logic;
  signal phase_out_d : std_logic;

  attribute dont_touch                : string;
  attribute dont_touch of phase_in_a  : signal is "true";
  attribute dont_touch of phase_in_b  : signal is "true";
  attribute dont_touch of phase_out_a : signal is "true";
  attribute dont_touch of phase_out_b : signal is "true";
  attribute dont_touch of phase_out_c : signal is "true";
  attribute dont_touch of phase_out_d : signal is "true";

begin

  -- Pulse trigger
  pulse_a <= ((not (phase_out_a) and inA_req) and not (phase_in_a)) or ((phase_out_a and not (inA_req)) and phase_in_a) after AND3_DELAY + OR2_DELAY;
  pulse_b <= ((not (phase_out_c) and inB_req) and not (phase_in_b)) or ((phase_out_c and not (inB_req)) and phase_in_b) after AND3_DELAY + OR2_DELAY;

  -- Input state
  a_ready <= phase_in_a xor inA_done;
  b_ready <= phase_in_b xor inB_done;

  -- Control path
  outA_req <= phase_out_a;
  outB_req <= phase_out_c;

  -- Mutex
  M_0 : entity mutex port map
    (
    a_ready, b_ready, click_a, click_b
    );

    t_0 : PROCESS (pulse_a, rst)
    BEGIN
        
        IF rising_edge(pulse_a) THEN
            phase_in_a <= NOT phase_in_a AFTER REG_CQ_DELAY;
        END IF;
        IF rst = '1' THEN
            phase_in_a <= PHASE_INIT_IN_A;
        END IF;
    END PROCESS;

    t_1 : PROCESS (pulse_b, rst)
    BEGIN
        
        IF rising_edge(pulse_b) THEN
            phase_in_b <= NOT phase_in_b AFTER REG_CQ_DELAY;
        END IF;
        IF rst = '1' THEN
            phase_in_b <= PHASE_INIT_IN_B;
        END IF;
    END PROCESS;

    t_2 : PROCESS (click_a, rst)
    BEGIN
        
        -- Loopback reacting to rising edge control
        IF rising_edge(click_a) THEN
            phase_out_a <= NOT phase_out_a AFTER REG_CQ_DELAY;
        -- Output reacting to falling edge 
        END IF;
        IF falling_edge(click_a) THEN
            phase_out_b <= NOT phase_out_b AFTER REG_CQ_DELAY;

        END IF;
        IF rst = '1' THEN
            phase_out_a <= PHASE_INIT_OUT_A;
            phase_out_b <= PHASE_INIT_OUT_B;
        END IF;
    END PROCESS;

    t_3 : PROCESS (click_b, rst)
    BEGIN
        
        IF rising_edge(click_b) THEN
            phase_out_c <= NOT phase_out_c AFTER REG_CQ_DELAY;
        END IF;
        IF falling_edge(click_b) THEN
            phase_out_d <= NOT phase_out_d AFTER REG_CQ_DELAY;
        END IF;
        IF rst = '1' THEN
            phase_out_c <= PHASE_INIT_OUT_C;
            phase_out_d <= PHASE_INIT_OUT_D;
        END IF;
    END PROCESS;
END impl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.rgd_mutex;

entity rgd_mutex_tb is
end entity;

architecture tb of rgd_mutex_tb is
  signal rst    : std_logic;
  signal aR, bR : std_logic; --inputs
  signal aD, bD : std_logic;
  signal aG, bG : std_logic;
begin

  DUT : entity rgd_mutex
    port
    map(
    rst,
    aR, aG,
    aD, bR,
    bG, bD
    );
  rst <= '1', '0' after 10 ns;
  aR  <= '0', '1' after 20 ns;
  bR  <= '0', '1' after 30 ns;

  aD <= '0', '1' after 50 ns;
  bD <= '0', '1' after 60 ns;
  assert false report "end of test" severity note;
end architecture;