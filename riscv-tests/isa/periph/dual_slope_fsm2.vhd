library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity afe_fsm is
    Port (
        clk         : in  std_logic;
        rst         : in  std_logic;

        start       : in  std_logic; -- rising edge to start conversion
        enable      : in  std_logic; -- active high
        cmp_out     : in  std_logic; -- comparator output signalling adc conversion complete
        count       : in  std_logic_vector(11 downto 0); --continually changing 

        sw1         : out std_logic; -- reset for shoring integrating cap
        sw2         : out std_logic; -- connects integrator to input signal
        sw3         : out std_logic; -- connects integrator to reference voltage

        done        : out std_logic; -- interrupt flag signaling result ready
	    result_latch: out std_logic_vector(11 downto 0) --latched result 
    );
end afe_fsm;



architecture Behavioral of afe_fsm is

    -- Signals 
    signal init_val : std_logic_vector(11 downto 0); -- make programmable (register)
    signal mode     : std_logic;
    signal set    : std_logic;
    signal counter_en : std_logic;

begin 

    dual_slope_fsm: entity dual_slope_fsm2
        port map (
            clk => clk,
            rst => rst,

            start => start,
            enable => enable,
            cmp_out => cmp_out, -- signal to stop counter from counting 
            count => count, --continually changing
            init_val => init_val,
            mode => mode,
            set => set,
            counter_en => counter_en,

            sw1 => sw1,
            sw2 => sw2,
            sw3 => sw3,
            done => done, -- facing core 
            result_latch => result_latch
    );

    counter: entity counter_upd
        port map (
            clk => clk,
            rst => rst,

            mode => mode, 
            set => set,

            enable => counter_en,
            init_val => init_val,
            count => count
    );

end Behavioral;




library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dual_slope_fsm2 is
    Port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        start       : in  std_logic;
        enable      : in  std_logic;
        cmp_out     : in  std_logic;
        count       : in  std_logic_vector(11 downto 0);
        init_val    : out std_logic_vector(11 downto 0);
        mode        : out std_logic;
        set         : out std_logic;
        counter_en  : out std_logic;
        sw1, sw2, sw3 : out std_logic;
        done        : out std_logic;
	result_latch: out std_logic_vector(11 downto 0)
    );
end dual_slope_fsm2;

architecture Behavioral of dual_slope_fsm2 is

    type state_type is (
        IDLE, RESET_PRE, RESET_WAIT,
        INTEGRATE_PRE, INTEGRATE_WAIT,
        DEINTEGRATE_WAIT,
        STORE
    );

    signal state, next_state : state_type;
    signal start_reg, start_edge : std_logic;
    constant RESET_CYCLES : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(74, 12));
    constant INTEGRATION_CYCLES : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(4095, 12));
    constant DEINT_TIMEOUT : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(0, 12));

    signal timeout_triggered : std_logic := '0';
    --signal result_latch : std_logic_vector(11 downto 0) := (others => '0');
    signal counter_en_reg : std_logic := '0';

begin

    counter_en <= counter_en_reg; -- Assign output

    -- Detect rising edge on start
    process(clk)
    begin
        if rising_edge(clk) then
            start_reg <= start;
            start_edge <= start and not start_reg;
        end if;
    end process;

    -- State register and timeout tracking
    process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
            timeout_triggered <= '0';
            counter_en_reg <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                state <= next_state;

                -- Counter enable update
                if next_state = RESET_PRE or next_state = RESET_WAIT or
                   next_state = INTEGRATE_PRE or next_state = INTEGRATE_WAIT or
                   (next_state = DEINTEGRATE_WAIT and cmp_out = '0' and count /= 0) then
                    counter_en_reg <= '1';
                else
                    counter_en_reg <= '0';
                end if;

                -- Timeout flag
                if state = DEINTEGRATE_WAIT and count = DEINT_TIMEOUT then
                    timeout_triggered <= '1';
                elsif state /= DEINTEGRATE_WAIT then
                    timeout_triggered <= '0';
                end if;
            else
                state <= IDLE;
                counter_en_reg <= '0';
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if state = DEINTEGRATE_WAIT then
                if cmp_out = '1' then
                    result_latch <= count;
                elsif count = std_logic_vector(to_unsigned(1, 12)) then
                    result_latch <= (others => '0');
                end if;
            end if;
        end if;
    end process;



    -- Combinational next state logic
    process(state, start_edge, count, cmp_out, timeout_triggered)
    begin
        -- Default outputs
        sw1 <= '0'; sw2 <= '0'; sw3 <= '0';
        set <= '0'; mode <= '0';
        init_val <= (others => '0');
        done <= '0';
        next_state <= state;

        case state is

            when IDLE =>
                if start_edge = '1' then
                    next_state <= RESET_PRE;
                end if;

            when RESET_PRE =>
                set <= '1';
                init_val <= (others => '0');
                mode <= '0';
                next_state <= RESET_WAIT;

            when RESET_WAIT =>
                sw1 <= '1';
                mode <= '0';
                if count = RESET_CYCLES then
                    next_state <= INTEGRATE_PRE;
                end if;

            when INTEGRATE_PRE =>
                set <= '1';
                init_val <= (others => '0');
                mode <= '0';
                next_state <= INTEGRATE_WAIT;

            when INTEGRATE_WAIT =>
                sw2 <= '1';
                mode <= '0';
                if count = INTEGRATION_CYCLES then
                    set <= '1';
                    init_val <= (others => '1');
                    mode <= '1';
                    next_state <= DEINTEGRATE_WAIT;
                end if;
            
	    when DEINTEGRATE_WAIT =>
    		sw3 <= '1';
    		mode <= '1';
    		if cmp_out = '1' then
        	    next_state <= STORE;
    		elsif count = std_logic_vector(to_unsigned(1, 12)) then
        	    next_state <= STORE;
    		end if;

            when STORE =>
                done <= '1';
                next_state <= IDLE;

        end case;
    end process;

end Behavioral;


-- DS Counter
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity counter_upd is
    Port(
        clk, rst, mode, set, enable : in STD_LOGIC;
        init_val : in STD_LOGIC_VECTOR(11 downto 0);
        count : out STD_LOGIC_VECTOR(11 downto 0)
    );
end;

architecture behav of counter_upd is
    signal count_reg : STD_LOGIC_VECTOR(11 downto 0); 
begin

    process(clk, rst)
    begin
        if rst = '1' then
            count_reg <= (others => '0');

        elsif enable = '0' then
            -- no change to count_reg (acts like a hold)
            null;

        elsif rising_edge(clk) then
            if set = '1' then
                count_reg <= init_val;
            elsif mode = '0' then
                count_reg <= count_reg + 1;
            else
                count_reg <= count_reg - 1;
            end if;
        end if;
    end process;

    count <= count_reg;

end architecture;