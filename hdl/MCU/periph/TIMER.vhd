library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library work;
use work.Constants.all;
use work.MemoryMap.all;

entity TIMER is
    port (
        -- ==========================================
        -- Clock Inputs
        -- ==========================================
        mclk         : in  std_logic;                      -- Main clock
        smclk        : in  std_logic;                      -- Sub-main clock
        clk_lfxt     : in  std_logic;                      -- Low-frequency crystal clock
        clk_hfxt     : in  std_logic;                      -- High-frequency crystal clock
        resetn       : in  std_logic;                      -- System reset (active-low)

        -- ==========================================
        -- Interrupt Outputs
        -- ==========================================
        irq_cap0     : out std_logic;                      -- Capture 0 interrupt request
        irq_cap1     : out std_logic;                      -- Capture 1 interrupt request
        irq_ovf      : out std_logic;                      -- Overflow interrupt request
        irq_cmp0     : out std_logic;                      -- Compare 0 interrupt request
        irq_cmp1     : out std_logic;                      -- Compare 1 interrupt request
        irq_cmp2     : out std_logic;                      -- Compare 2 interrupt request

        -- ==========================================
        -- Memory-Mapped Register Interface
        -- ==========================================
        clk_mem      : in  std_logic;                      -- Memory interface clock
        en_mem       : in  std_logic;                      -- Memory enable (active-low)
        wen          : in  std_logic_vector(3 downto 0);   -- Write enable (active-low)
        addr_periph  : in  std_logic_vector(7 downto 2);   -- Peripheral register address
        write_data   : in  std_logic_vector(31 downto 0);  -- Write data bus
        read_data    : out std_logic_vector(31 downto 0);  -- Read data bus

        -- ==========================================
        -- Compare Output 0 Pin Interface
        -- ==========================================
        cmp0_ren_in  : in  std_logic;                      -- Compare 0 resistor config
        cmp0_out     : out std_logic;                      -- Compare 0 output value
        cmp0_dir     : out std_logic;                      -- Compare 0 direction (always output)
        cmp0_ren     : out std_logic;                      -- Compare 0 resistor enable

        -- ==========================================
        -- Compare Output 1 Pin Interface
        -- ==========================================
        cmp1_ren_in  : in  std_logic;                      -- Compare 1 resistor config
        cmp1_out     : out std_logic;                      -- Compare 1 output value
        cmp1_dir     : out std_logic;                      -- Compare 1 direction (always output)
        cmp1_ren     : out std_logic;                      -- Compare 1 resistor enable

        -- ==========================================
        -- Capture Input 0 Pin Interface
        -- ==========================================
        cap0_ren_in  : in  std_logic;                      -- Capture 0 resistor config
        cap0_in      : in  std_logic;                      -- Capture 0 input signal
        cap0_dir     : out std_logic;                      -- Capture 0 direction (always input)
        cap0_ren     : out std_logic;                      -- Capture 0 resistor enable

        -- ==========================================
        -- Capture Input 1 Pin Interface
        -- ==========================================
        cap1_ren_in  : in  std_logic;                      -- Capture 1 resistor config
        cap1_in      : in  std_logic;                      -- Capture 1 input signal
        cap1_dir     : out std_logic;                      -- Capture 1 direction (always input)
        cap1_ren     : out std_logic                       -- Capture 1 resistor enable
    );
end TIMER;

architecture rtl of TIMER is

    -- ==========================================
    -- Timer Registers
    -- ==========================================
    signal control_reg         : std_logic_vector(19 downto 0);  -- Timer control register
    signal status_reg          : std_logic_vector(7 downto 0);   -- Timer status register
    signal status_reg_latched  : std_logic_vector(7 downto 0);   -- Latched status for read
    signal timer_value         : std_logic_vector(31 downto 0);  -- Current timer count value
    signal timer_value_latched : std_logic_vector(31 downto 0);  -- Latched timer value for read
    signal compare0_reg        : std_logic_vector(31 downto 0);  -- Compare 0 threshold
    signal compare1_reg        : std_logic_vector(31 downto 0);  -- Compare 1 threshold
    signal compare2_reg        : std_logic_vector(31 downto 0);  -- Compare 2 threshold (reset)
    signal capture0_reg        : std_logic_vector(31 downto 0);  -- Capture 0 value
    signal capture1_reg        : std_logic_vector(31 downto 0);  -- Capture 1 value
    signal capture0_latched    : std_logic_vector(31 downto 0);  -- Latched capture 0 for read
    signal capture1_latched    : std_logic_vector(31 downto 0);  -- Latched capture 1 for read

    -- ==========================================
    -- Control Register Bit Fields
    -- ==========================================
    signal clock_divider       : std_logic_vector(3 downto 0);   -- Clock divider selection
    signal compare1_init_level : std_logic;                      -- Compare 1 initial output level
    signal compare0_init_level : std_logic;                      -- Compare 0 initial output level
    signal capture1_fall_edge  : std_logic;                      -- Capture 1 on falling edge enable
    signal capture0_fall_edge  : std_logic;                      -- Capture 0 on falling edge enable
    signal capture1_enable     : std_logic;                      -- Capture 1 enable
    signal capture0_enable     : std_logic;                      -- Capture 0 enable
    signal clock_source_select : std_logic_vector(1 downto 0);   -- Clock source selection
    signal compare2_reset_en   : std_logic;                      -- Reset timer on compare 2 match
    signal timer_enable        : std_logic;                      -- Timer enable
    signal capture1_int_enable : std_logic;                      -- Capture 1 interrupt enable
    signal capture0_int_enable : std_logic;                      -- Capture 0 interrupt enable
    signal overflow_int_enable : std_logic;                      -- Overflow interrupt enable
    signal compare2_int_enable : std_logic;                      -- Compare 2 interrupt enable
    signal compare1_int_enable : std_logic;                      -- Compare 1 interrupt enable
    signal compare0_int_enable : std_logic;                      -- Compare 0 interrupt enable

    -- ==========================================
    -- Status Register Bit Fields
    -- ==========================================
    signal compare1_output     : std_logic;                      -- Compare 1 current output level
    signal compare0_output     : std_logic;                      -- Compare 0 current output level
    signal capture1_int_flag   : std_logic;                      -- Capture 1 interrupt flag
    signal capture0_int_flag   : std_logic;                      -- Capture 0 interrupt flag
    signal overflow_int_flag   : std_logic;                      -- Overflow interrupt flag
    signal compare2_int_flag   : std_logic;                      -- Compare 2 interrupt flag
    signal compare1_int_flag   : std_logic;                      -- Compare 1 interrupt flag
    signal compare0_int_flag   : std_logic;                      -- Compare 0 interrupt flag

    -- ==========================================
    -- Timer Core Signals
    -- ==========================================
    signal clock_mux_output    : std_logic;                      -- Selected clock from mux
    signal clock_source        : std_logic;                      -- Gated clock source
    signal divider_counter     : std_logic_vector(14 downto 0);  -- Clock divider counter
    signal timer_clock         : std_logic;                      -- Final timer clock after division
    signal divider_input       : std_logic;                      -- Clock divider input
    signal divider_enable      : std_logic;                      -- Clock divider enable

    -- ==========================================
    -- Timer Control Signals
    -- ==========================================
    signal latch_timer_value   : std_logic;                      -- Latch new timer value
    signal timer_overflowing   : std_logic;                      -- Timer overflow detection
    signal clear_timer_value   : std_logic;                      -- Clear timer to zero
    signal clear_capture0_flag : std_logic;                      -- Clear capture 0 interrupt flag
    signal clear_capture1_flag : std_logic;                      -- Clear capture 1 interrupt flag
    signal clear_overflow_flag : std_logic;                      -- Clear overflow interrupt flag
    signal clear_compare0_flag : std_logic;                      -- Clear compare 0 interrupt flag
    signal clear_compare1_flag : std_logic;                      -- Clear compare 1 interrupt flag
    signal clear_compare2_flag : std_logic;                      -- Clear compare 2 interrupt flag

    -- ==========================================
    -- Capture Clock Signals
    -- ==========================================
    signal capture0_clock      : std_logic;                      -- Edge-detected clock for capture 0
    signal capture1_clock      : std_logic;                      -- Edge-detected clock for capture 1

    -- ==========================================
    -- Memory Interface Signals
    -- ==========================================
    signal reg_address         : natural range 0 to 63;          -- Decoded register address
    signal timer_value_write   : std_logic_vector(31 downto 0);  -- Timer value from write bus

begin

    -- ==========================================
    -- Control Register Field Extraction
    -- ==========================================
    clock_divider       <= control_reg(19 downto 16);
    compare1_init_level <= control_reg(15);
    compare0_init_level <= control_reg(14);
    capture1_fall_edge  <= control_reg(13);
    capture0_fall_edge  <= control_reg(12);
    capture1_enable     <= control_reg(11);
    capture0_enable     <= control_reg(10);
    clock_source_select <= control_reg(9 downto 8);
    compare2_reset_en   <= control_reg(7);
    timer_enable        <= control_reg(6);
    capture1_int_enable <= control_reg(5);
    capture0_int_enable <= control_reg(4);
    overflow_int_enable <= control_reg(3);
    compare2_int_enable <= control_reg(2);
    compare1_int_enable <= control_reg(1);
    compare0_int_enable <= control_reg(0);

    -- ==========================================
    -- Status Register Assembly
    -- ==========================================
    status_reg <= (
        7 => compare1_output,
        6 => compare0_output,
        5 => capture1_int_flag,
        4 => capture0_int_flag,
        3 => overflow_int_flag,
        2 => compare2_int_flag,
        1 => compare1_int_flag,
        0 => compare0_int_flag
    );

    -- ==========================================
    -- Pin Direction Configuration
    -- ==========================================
    -- Capture pins are always inputs
    cap0_dir <= '0';
    cap0_ren <= cap0_ren_in;
    cap1_dir <= '0';
    cap1_ren <= cap1_ren_in;

    -- Compare pins are always outputs
    cmp0_dir <= '1';
    cmp0_ren <= cmp0_ren_in;
    cmp1_dir <= '1';
    cmp1_ren <= cmp1_ren_in;

    -- ==========================================
    -- Clock Source Selection and Division
    -- ==========================================
    -- Glitch-free clock multiplexer
    clk_mux: entity work.ClockMuxGlitchFree
    generic map (
        CLK_COUNT   => 4,
        SEL_WIDTH   => 2,
        CLK_DEFAULT => 0
    )
    port map (
        resetn      => resetn,
        Sel         => clock_source_select,
        ClkIn(0)    => smclk,
        ClkIn(1)    => mclk,
        ClkIn(2)    => clk_lfxt,
        ClkIn(3)    => clk_hfxt,
        ClkEn       => open,
        ClkOut      => clock_mux_output
    );

    -- Gate clock when timer disabled
    clock_gate_timer: entity work.ClkGate
    port map (
        ClkIn  => clock_mux_output,
        En     => timer_enable,
        ClkOut => clock_source
    );

    -- Enable divider only when needed
    divider_enable <= '1' when timer_enable = '1' and (clock_divider /= "0000") else '0';
    
    clock_gate_divider: entity work.ClkGate
    port map (
        ClkIn  => clock_mux_output,
        En     => divider_enable,
        ClkOut => divider_input
    );

    -- ==========================================
    -- Clock Divider Counter
    -- ==========================================
    divider_process: process(resetn, divider_input, timer_enable, clock_divider)
    begin
        if (resetn = '0') or (timer_enable = '0') or (clock_divider = "0000") then
            divider_counter <= (others => '0');
        elsif rising_edge(divider_input) then
            divider_counter <= divider_counter + 1;
        end if;
    end process;

    -- Select divided clock output
    with clock_divider select timer_clock <=
        clock_source         when "0000",  -- Divide by 1 (no division)
        divider_counter(0)   when "0001",  -- Divide by 2
        divider_counter(1)   when "0010",  -- Divide by 4
        divider_counter(2)   when "0011",  -- Divide by 8
        divider_counter(3)   when "0100",  -- Divide by 16
        divider_counter(4)   when "0101",  -- Divide by 32
        divider_counter(5)   when "0110",  -- Divide by 64
        divider_counter(6)   when "0111",  -- Divide by 128
        divider_counter(7)   when "1000",  -- Divide by 256
        divider_counter(8)   when "1001",  -- Divide by 512
        divider_counter(9)   when "1010",  -- Divide by 1024
        divider_counter(10)  when "1011",  -- Divide by 2048
        divider_counter(11)  when "1100",  -- Divide by 4096
        divider_counter(12)  when "1101",  -- Divide by 8192
        divider_counter(13)  when "1110",  -- Divide by 16384
        divider_counter(14)  when others;  -- Divide by 32768

    -- ==========================================
    -- Timer Counter
    -- ==========================================
    timer_counter: process(resetn, timer_clock, latch_timer_value, timer_value_write)
    begin
        if resetn = '0' then
            timer_value <= (others => '0');
        elsif latch_timer_value = '1' then
            -- Load new value from register write
            timer_value <= timer_value_write;
        elsif rising_edge(timer_clock) then
            if clear_timer_value = '1' then
                timer_value <= (others => '0');
            else
                timer_value <= timer_value + 1;
            end if;
        end if;
    end process;

    -- ==========================================
    -- Input Capture 0 Logic
    -- ==========================================
    -- Generate edge-sensitive capture clock
    capture0_clock <= '0' when capture0_enable = '0' else 
                     cap0_in xor capture0_fall_edge;

    capture0_process: process(resetn, clear_capture0_flag, capture0_clock)
    begin
        if resetn = '0' then
            capture0_reg <= (others => '0');
            capture0_int_flag <= '0';
        elsif clear_capture0_flag = '1' then
            capture0_int_flag <= '0';
        elsif rising_edge(capture0_clock) then
            capture0_reg <= timer_value;  -- Capture current timer value
            capture0_int_flag <= '1';     -- Set interrupt flag
        end if;
    end process;

    -- ==========================================
    -- Input Capture 1 Logic
    -- ==========================================
    -- Generate edge-sensitive capture clock
    capture1_clock <= '0' when capture1_enable = '0' else 
                     cap1_in xor capture1_fall_edge;

    capture1_process: process(resetn, clear_capture1_flag, capture1_clock)
    begin
        if resetn = '0' then
            capture1_reg <= (others => '0');
            capture1_int_flag <= '0';
        elsif clear_capture1_flag = '1' then
            capture1_int_flag <= '0';
        elsif rising_edge(capture1_clock) then
            capture1_reg <= timer_value;  -- Capture current timer value
            capture1_int_flag <= '1';     -- Set interrupt flag
        end if;
    end process;

    -- ==========================================
    -- Timer Overflow Detection
    -- ==========================================
    timer_overflowing <= '1' when timer_value = X"FFFFFFFF" else '0';

    overflow_process: process(resetn, timer_clock, clear_overflow_flag)
    begin
        if resetn = '0' or clear_overflow_flag = '1' then
            overflow_int_flag <= '0';
        elsif rising_edge(timer_clock) then
            if timer_overflowing = '1' then
                overflow_int_flag <= '1';
            end if;
        end if;
    end process;

    -- ==========================================
    -- Compare Match and PWM Generation
    -- ==========================================
    compare_process: process(resetn, timer_clock, clear_compare0_flag, clear_compare1_flag, 
                           timer_value, timer_enable, compare0_init_level)
    begin
        if resetn = '0' or timer_enable = '0' then
            -- Initialize outputs to configured levels
            compare0_output <= compare0_init_level;
            compare1_output <= compare1_init_level;
        elsif rising_edge(timer_clock) then
            -- Compare 0 match detection
            if timer_value = compare0_reg then
                compare0_int_flag <= '1';
                compare0_output <= not compare0_init_level;  -- Toggle output
            end if;
            
            -- Compare 1 match detection
            if timer_value = compare1_reg then
                compare1_int_flag <= '1';
                compare1_output <= not compare1_init_level;  -- Toggle output
            end if;

            -- Reset outputs on timer reset or overflow
            if clear_timer_value = '1' or timer_overflowing = '1' then
                compare0_output <= compare0_init_level;
                compare1_output <= compare1_init_level;
            end if;
        end if;

        -- Clear interrupt flags
        if resetn = '0' or clear_compare0_flag = '1' then
            compare0_int_flag <= '0';
        end if;
        if resetn = '0' or clear_compare1_flag = '1' then
            compare1_int_flag <= '0';
        end if;
    end process;

    -- ==========================================
    -- Compare 2 Timer Reset Logic
    -- ==========================================
    -- Reset timer when it matches compare2 register (if enabled)
    clear_timer_value <= '1' when (compare2_reset_en = '1' and timer_value = compare2_reg) else '0';

    compare2_process: process(resetn, timer_clock, clear_compare2_flag, timer_enable, timer_value)
    begin
        if resetn = '0' or clear_compare2_flag = '1' or timer_enable = '0' then
            compare2_int_flag <= '0';
        elsif rising_edge(timer_clock) then
            if clear_timer_value = '1' then
                compare2_int_flag <= '1';
            end if;
        end if;
    end process;

    -- ==========================================
    -- Compare Output Assignments
    -- ==========================================
    cmp0_out <= compare0_output;
    cmp1_out <= compare1_output;

    -- ==========================================
    -- Interrupt Request Generation
    -- ==========================================
    irq_cap0 <= capture0_int_flag and capture0_int_enable;
    irq_cap1 <= capture1_int_flag and capture1_int_enable;
    irq_ovf  <= overflow_int_flag and overflow_int_enable;
    irq_cmp0 <= compare0_int_flag and compare0_int_enable;
    irq_cmp1 <= compare1_int_flag and compare1_int_enable;
    irq_cmp2 <= compare2_int_flag and compare2_int_enable;

    -- ==========================================
    -- Register Synchronization for Memory Read
    -- ==========================================
    reg_sync: process(en_mem)
    begin
        if falling_edge(en_mem) then
            status_reg_latched  <= not status_reg;
            timer_value_latched <= not timer_value;
            capture0_latched    <= not capture0_reg;
            capture1_latched    <= not capture1_reg;
        end if;
    end process;

    -- ==========================================
    -- Memory-Mapped Register Interface
    -- ==========================================
    -- Address decoding
    reg_address <= slv2uint(addr_periph) when en_mem = '0' else 0;

    -- Register write process
    reg_write_proc: process(resetn, clk_mem)
    begin
        if resetn = '0' then
            control_reg <= (others => '0');
            compare0_reg <= (others => '0');
            compare1_reg <= (others => '0');
            compare2_reg <= (others => '0');
        elsif rising_edge(clk_mem) then
            if en_mem = '0' then
                case reg_address is
                    -- Control register write
                    when RegSlotTIMxCR =>
                        if wen(0) = '0' then
                            control_reg(7 downto 0) <= write_data(7 downto 0);
                        end if;
                        if wen(1) = '0' then
                            control_reg(15 downto 8) <= write_data(15 downto 8);
                        end if;
                        if wen(2) = '0' then
                            control_reg(19 downto 16) <= write_data(19 downto 16);
                        end if;
                    
                    -- Status register write (clear flags)
                    when RegSlotTIMxSR =>
                        if wen(0) = '0' then
                            if write_data(0) = '1' then clear_compare0_flag <= '1'; end if;
                            if write_data(1) = '1' then clear_compare1_flag <= '1'; end if;
                            if write_data(2) = '1' then clear_compare2_flag <= '1'; end if;
                            if write_data(3) = '1' then clear_overflow_flag <= '1'; end if;
                            if write_data(4) = '1' then clear_capture0_flag <= '1'; end if;
                            if write_data(5) = '1' then clear_capture1_flag <= '1'; end if;
                        end if;
                    
                    -- Timer value write
                    when RegSlotTIMxVAL =>
                        if wen /= "1111" then
                            timer_value_write <= write_data;
                            latch_timer_value <= '1';
                        end if;
                    
                    -- Compare 0 register write
                    when RegSlotTIMxCMP0 =>
                        if wen(0) = '0' then compare0_reg(7 downto 0)   <= write_data(7 downto 0);   end if;
                        if wen(1) = '0' then compare0_reg(15 downto 8)  <= write_data(15 downto 8);  end if;
                        if wen(2) = '0' then compare0_reg(23 downto 16) <= write_data(23 downto 16); end if;
                        if wen(3) = '0' then compare0_reg(31 downto 24) <= write_data(31 downto 24); end if;
                    
                    -- Compare 1 register write
                    when RegSlotTIMxCMP1 =>
                        if wen(0) = '0' then compare1_reg(7 downto 0)   <= write_data(7 downto 0);   end if;
                        if wen(1) = '0' then compare1_reg(15 downto 8)  <= write_data(15 downto 8);  end if;
                        if wen(2) = '0' then compare1_reg(23 downto 16) <= write_data(23 downto 16); end if;
                        if wen(3) = '0' then compare1_reg(31 downto 24) <= write_data(31 downto 24); end if;
                    
                    -- Compare 2 register write
                    when RegSlotTIMxCMP2 =>
                        if wen(0) = '0' then compare2_reg(7 downto 0)   <= write_data(7 downto 0);   end if;
                        if wen(1) = '0' then compare2_reg(15 downto 8)  <= write_data(15 downto 8);  end if;
                        if wen(2) = '0' then compare2_reg(23 downto 16) <= write_data(23 downto 16); end if;
                        if wen(3) = '0' then compare2_reg(31 downto 24) <= write_data(31 downto 24); end if;
                    
                    when others =>
                        null;
                end case;
            end if;
        end if;
        
        -- Clear control signals when not active
        if resetn = '0' or en_mem = '1' then
            clear_compare0_flag <= '0';
            clear_compare1_flag <= '0';
            clear_compare2_flag <= '0';
            clear_overflow_flag <= '0';
            clear_capture0_flag <= '0';
            clear_capture1_flag <= '0';
            latch_timer_value <= '0';
        end if;
    end process;

    -- ==========================================
    -- Register Read Process
    -- ==========================================
    reg_read_proc: process(clk_mem)
    begin
        if rising_edge(clk_mem) then
            case reg_address is
                when RegSlotTIMxCR =>
                    read_data <= (31 downto 20 => '0') & control_reg;
                
                when RegSlotTIMxSR =>
                    read_data <= (31 downto 8 => '0') & (not status_reg_latched);
                
                when RegSlotTIMxVAL =>
                    read_data <= timer_value;
                
                when RegSlotTIMxCAP0 =>
                    read_data <= not capture0_latched;
                
                when RegSlotTIMxCAP1 =>
                    read_data <= not capture1_latched;
                
                when RegSlotTIMxCMP0 =>
                    read_data <= compare0_reg;
                
                when RegSlotTIMxCMP1 =>
                    read_data <= compare1_reg;
                
                when RegSlotTIMxCMP2 =>
                    read_data <= compare2_reg;
                
                when others =>
                    read_data <= (others => '0');  -- Return zeros for unmapped addresses
            end case;
        end if;
    end process;

end rtl;








-- library ieee;
-- use ieee.std_logic_1164.all;
-- use ieee.std_logic_arith.all;
-- use ieee.std_logic_unsigned.all;
-- library work;
-- use work.Constants.all;
-- use work.MemoryMap.all;

-- entity TIMER is
--     port
--     (
--         -- System Signals
--         mclk         : in  std_logic;  -- Main clock
--         smclk        : in  std_logic;  -- Sub-main clock
--         clk_lfxt     : in  std_logic;  -- Low-frequency crystal clock
--         clk_hfxt     : in  std_logic;  -- High-frequency crystal clock
--         resetn       : in  std_logic;  -- System reset (active low)

--         -- IRQ Signals
--         irq_cap0    : out std_logic;  -- Capture 0 Interrupt
--         irq_cap1    : out std_logic;  -- Capture 1 Interrupt
--         irq_ovf     : out std_logic;  -- Overflow Interrupt
--         irq_cmp0    : out std_logic;  -- Compare 0 Interrupt
--         irq_cmp1    : out std_logic;  -- Compare 1 Interrupt
--         irq_cmp2    : out std_logic;  -- Compare 2 Interrupt

--         -- Memory Bus
--         clk_mem      : in  std_logic;
--         en_mem       : in  std_logic;
--         wen          : in  std_logic_vector(3 downto 0);
--         addr_periph  : in  std_logic_vector(7 downto 2);
--         write_data   : in  std_logic_vector(31 downto 0);
--         read_data    : out std_logic_vector(31 downto 0);

--         -- Pad Interface
--         cmp0_ren_in : in  std_logic;  -- Timer Compare 0 Pin
--         cmp0_out    : out std_logic;
--         cmp0_dir    : out std_logic;
--         cmp0_ren    : out std_logic;

--         cmp1_ren_in : in  std_logic;  -- Timer Compare 1 Pin
--         cmp1_out    : out std_logic;
--         cmp1_dir    : out std_logic;
--         cmp1_ren    : out std_logic;

--         cap0_ren_in : in  std_logic;  -- Timer Input Capture 0 Pin
--         cap0_ren    : out std_logic;
--         cap0_dir    : out std_logic;
--         cap0_in     : in  std_logic;  -- Timer Input Capture 0 Pin

--         cap1_ren_in : in  std_logic;  -- Timer Input Capture 1 Pin
--         cap1_ren    : out std_logic;
--         cap1_dir    : out std_logic;
--         cap1_in     : in  std_logic   -- Timer Input Capture 1 Pin
--     );
-- end TIMER;

-- architecture rtl of TIMER is

--     -- Register Declarations
--     signal TIMxCR       : std_logic_vector(19 downto 0);  -- Timer control register
--     signal TIMxSR       : std_logic_vector(7 downto 0);   -- Timer status register
--     signal TIMxSR_ltch : std_logic_vector(7 downto 0);   -- Latched version of TIMxSR
--     signal TIMxVAL      : std_logic_vector(31 downto 0);  -- Timer value register
--     signal TIMxVAL_ltch: std_logic_vector(31 downto 0);  -- Latched version of TIMxVAL
--     signal TIMxCMP0     : std_logic_vector(31 downto 0);  -- Timer compare 0 register
--     signal TIMxCMP1     : std_logic_vector(31 downto 0);  -- Timer compare 1 register
--     signal TIMxCMP2     : std_logic_vector(31 downto 0);  -- Timer compare 2 register
--     signal TIMxCAP0     : std_logic_vector(31 downto 0);  -- Timer capture 0 register (input only)
--     signal TIMxCAP1     : std_logic_vector(31 downto 0);  -- Timer capture 1 register
--     signal TIMxCAP0_ltch : std_logic_vector(31 downto 0);  -- Latched version of TIMxCAP0
--     signal TIMxCAP1_ltch : std_logic_vector(31 downto 0);  -- Latched version of TIMxCAP1

--     -- Control Register Bits
--     signal TIMx_clk_div     : std_logic_vector(3 downto 0);  -- Timer clock divider
--     signal TIMxCMP1_init   : std_logic;  -- Compare 1 initial output level
--     signal TIMxCMP0_init   : std_logic;  -- Compare 0 initial output level
--     signal TIMxCAP1_edge   : std_logic;  -- Capture 1 falling edge trigger enable
--     signal TIMxCAP0_edge   : std_logic;  -- Capture 0 falling edge trigger enable
--     signal TIMxCAP1_en     : std_logic;  -- Capture 1 enable
--     signal TIMxCAP0_en     : std_logic;  -- Capture 0 enable
--     signal timer_clk_src_sel : std_logic_vector(1 downto 0);  -- Timer clock source select
--     signal TIMxCMP2_reset  : std_logic;  -- Timer resets on compare 2 match
--     signal en_timer          : std_logic;  -- Timer enable
--     signal TIMxCAP1_ie     : std_logic;  -- Capture 1 interrupt enable
--     signal TIMxCAP0_ie     : std_logic;  -- Capture 0 interrupt enable
--     signal timer_ovf_ie      : std_logic;  -- Timer overflow interrupt enable
--     signal TIMxCMP2_ie     : std_logic;  -- Compare 2 interrupt enable
--     signal TIMxCMP1_ie     : std_logic;  -- Compare 1 interrupt enable
--     signal TIMxCMP0_ie     : std_logic;  -- Compare 0 interrupt enable

--     -- Status Register Bits
--     signal TIMxCMP1_out    : std_logic;  -- Compare 1 output level
--     signal TIMxCMP0_out    : std_logic;  -- Compare 0 output level
--     signal TIMxCAP1_if     : std_logic;  -- Capture 1 interrupt flag
--     signal TIMxCAP0_if     : std_logic;  -- Capture 0 interrupt flag
--     signal timer_ovf_if      : std_logic;  -- Timer overflow interrupt flag
--     signal TIMxCMP2_if     : std_logic;  -- Compare 2 interrupt flag
--     signal TIMxCMP1_if     : std_logic;  -- Compare 1 interrupt flag
--     signal TIMxCMP0_if     : std_logic;  -- Compare 0 interrupt flag

--     -- Timer Core Signals
--     signal clk_src_mux       : std_logic;  -- Clock source multiplexer
--     signal clk_src           : std_logic;  -- Selected clock source
--     signal clk_div_counter       : std_logic_vector(14 downto 0);  -- Clock divider counter
--     signal clk_timer         : std_logic;  -- clk used by timer, divided clock
--     signal clk_div           : std_logic;  -- Input to clock divider (output of mux)
--     signal en_clk_div       : std_logic;  -- Enable for the clock divider

--     signal latch_value       : std_logic;  -- Latch timer value command
--     signal overflowing       : std_logic;  -- Timer is overflowing
--     signal clr_TIMxVAL      : std_logic;  -- Clear timer value command
--     signal clr_cap0_if     : std_logic;  -- Clear capture 0 interrupt flag
--     signal clr_cap1_if     : std_logic;  -- Clear capture 1 interrupt flag
--     signal clr_ovf_if      : std_logic;  -- Clear overflow interrupt flag
--     signal clr_cmp0_if     : std_logic;  -- Clear compare 0 interrupt flag
--     signal clr_cmp1_if     : std_logic;  -- Clear compare 1 interrupt flag
--     signal clr_cmp2_if     : std_logic;  -- Clear compare 2 interrupt flag

--     signal clk_cap0          : std_logic;  -- Generated clock for capture 0
--     signal clk_cap1          : std_logic;  -- Generated clock for capture 1

--     -- =============================================================================
--     -- Memory Interface Signals
--     -- =============================================================================
--     signal en_addr_periph : natural range 0 to 63; -- Enable Memory Peripheral
--     signal TIMxVAL_mab    : std_logic_vector(31 downto 0);  -- Timer value in from MAB

-- begin

--     -- Register Signal Routing
--     TIMx_clk_div     <= TIMxCR(19 downto 16);
--     TIMxCMP1_init   <= TIMxCR(15);
--     TIMxCMP0_init   <= TIMxCR(14);
--     TIMxCAP1_edge   <= TIMxCR(13);
--     TIMxCAP0_edge   <= TIMxCR(12);
--     TIMxCAP1_en     <= TIMxCR(11);
--     TIMxCAP0_en     <= TIMxCR(10);
--     timer_clk_src_sel <= TIMxCR(9 downto 8);
--     TIMxCMP2_reset  <= TIMxCR(7);
--     en_timer          <= TIMxCR(6);
--     TIMxCAP1_ie     <= TIMxCR(5);
--     TIMxCAP0_ie     <= TIMxCR(4);
--     timer_ovf_ie      <= TIMxCR(3);
--     TIMxCMP2_ie     <= TIMxCR(2);
--     TIMxCMP1_ie     <= TIMxCR(1);
--     TIMxCMP0_ie     <= TIMxCR(0);


--     -- TIMxSR
--     TIMxSR <= (
--         7 => TIMxCMP1_out,
--         6 => TIMxCMP0_out,
--         5 => TIMxCAP1_if,
--         4 => TIMxCAP0_if,
--         3 => timer_ovf_if,
--         2 => TIMxCMP2_if,
--         1 => TIMxCMP1_if,
--         0 => TIMxCMP0_if
--     );

--     cap0_dir <= '0';  -- Input Capture is always input
--     cap0_ren <= cap0_ren_in;
--     cap1_dir <= '0';  -- Input Capture is always input
--     cap1_ren <= cap1_ren_in;

--     ------------------------------------
--     -- Timer Core
--     ------------------------------------

--     -- Clock Multiplexer and Divider
--     clk_mux: entity work.ClockMuxGlitchFree
--     generic map (
--         CLK_COUNT   => 4,
--         SEL_WIDTH   => 2,
--         CLK_DEFAULT => 0
--     )
--     port map (
--         resetn      => resetn,
--         Sel         => timer_clk_src_sel,
--         ClkIn(0)    => smclk,
--         ClkIn(1)    => mclk,
--         ClkIn(2)    => clk_lfxt,
--         ClkIn(3)    => clk_hfxt,
--         ClkEn       => open,
--         ClkOut      => clk_src_mux
--     );

--     clock_gate_timer: entity work.ClkGate
--     port map (
--         ClkIn       => clk_src_mux,
--         En          => en_timer,
--         ClkOut      => clk_src
--     );

--     en_clk_div <= '1' when en_timer = '1' and (TIMx_clk_div /= "0000") else '0';
--     clock_gate_clk_div: entity work.ClkGate
--     port map (
--         ClkIn       => clk_src_mux,
--         En          => en_clk_div,
--         ClkOut      => clk_div
--     );

--     -- Clock Divider Process
--     process (resetn, clk_div, en_timer, TIMx_clk_div)
--     begin
--         if (resetn = '0') or (en_timer = '0') or (TIMx_clk_div = "0000") then
--             clk_div_counter <= (others => '0');
--         elsif rising_edge(clk_div) then
--             clk_div_counter <= clk_div_counter + 1;
--         end if;
--     end process;

--     with TIMx_clk_div select clk_timer <=
--         clk_src              when "0000",  -- Divide by 1
--         clk_div_counter(0)   when "0001",  -- Divide by 2
--         clk_div_counter(1)   when "0010",  -- Divide by 4
--         clk_div_counter(2)   when "0011",  -- Divide by 8
--         clk_div_counter(3)   when "0100",  -- Divide by 16
--         clk_div_counter(4)   when "0101",  -- Divide by 32
--         clk_div_counter(5)   when "0110",  -- Divide by 64
--         clk_div_counter(6)   when "0111",  -- Divide by 128
--         clk_div_counter(7)   when "1000",  -- Divide by 256
--         clk_div_counter(8)   when "1001",  -- Divide by 512
--         clk_div_counter(9)   when "1010",  -- Divide by 1024
--         clk_div_counter(10)  when "1011",  -- Divide by 2048
--         clk_div_counter(11)  when "1100",  -- Divide by 4096
--         clk_div_counter(12)  when "1101",  -- Divide by 8192
--         clk_div_counter(13)  when "1110",  -- Divide by 16384
--         clk_div_counter(14)  when others;  -- Divide by 32768

--     -- Timer Value Counter
--     process (resetn, clk_timer, latch_value, TIMxVAL_mab)
--     begin
--         if resetn = '0' then
--             TIMxVAL <= (others => '0');
--         elsif latch_value = '1' then
--             TIMxVAL <= TIMxVAL_mab;
--         elsif rising_edge(clk_timer) then
--             if clr_TIMxVAL = '1' then
--                 TIMxVAL <= (others => '0');
--             else
--                 TIMxVAL <= TIMxVAL + 1;
--             end if;
--         end if;
--     end process;

--     ------------------------------------
--     -- Input Capture Triggering
--     ------------------------------------

--     clk_cap0 <= '0' when TIMxCAP0_en = '0' else cap0_in xor TIMxCAP0_edge;

--     process (resetn, clr_cap0_if, clk_cap0)
--     begin
--         if resetn = '0' then
--             TIMxCAP0 <= (others => '0');
--             TIMxCAP0_if <= '0';
--         elsif clr_cap0_if = '1' then
--             TIMxCAP0_if <= '0';
--         elsif rising_edge(clk_cap0) then
--             TIMxCAP0 <= TIMxVAL;
--             TIMxCAP0_if <= '1';
--         end if;
--     end process;

--     clk_cap1 <= '0' when TIMxCAP1_en = '0' else cap1_in xor TIMxCAP1_edge;

--     process (resetn, clr_cap1_if, clk_cap1)
--     begin
--         if resetn = '0' then
--             TIMxCAP1 <= (others => '0');
--             TIMxCAP1_if <= '0';
--         elsif clr_cap1_if = '1' then
--             TIMxCAP1_if <= '0';
--         elsif rising_edge(clk_cap1) then
--             TIMxCAP1 <= TIMxVAL;
--             TIMxCAP1_if <= '1';
--         end if;
--     end process;

--     ------------------------------------
--     -- Overflow Detection
--     ------------------------------------

--     overflowing <= '1' when TIMxVAL = X"FFFFFFFF" else '0';

--     process (resetn, clk_timer, clr_ovf_if)
--     begin
--         if resetn = '0' or clr_ovf_if = '1' then
--             timer_ovf_if <= '0';
--         elsif rising_edge(clk_timer) then
--             if overflowing = '1' then
--                 timer_ovf_if <= '1';
--             end if;
--         end if;
--     end process;

--     ------------------------------------
--     -- Compare Events and PWM
--     ------------------------------------

--     process (resetn, clk_timer, clr_cmp0_if, clr_cmp1_if, TIMxVAL, en_timer, TIMxCMP0_init)
--     begin
--         if resetn = '0' or en_timer = '0' then
--             TIMxCMP0_out <= TIMxCMP0_init;
--             TIMxCMP1_out <= TIMxCMP1_init;
--         elsif rising_edge(clk_timer) then
--             if TIMxVAL = TIMxCMP0 then
--                 TIMxCMP0_if <= '1';
--                 TIMxCMP0_out <= not TIMxCMP0_init;
--             end if;
--             if TIMxVAL = TIMxCMP1 then
--                 TIMxCMP1_if <= '1';
--                 TIMxCMP1_out <= not TIMxCMP1_init;
--             end if;

--             if clr_TIMxVAL = '1' or overflowing = '1' then
--                 TIMxCMP0_out <= TIMxCMP0_init;
--                 TIMxCMP1_out <= TIMxCMP1_init;
--             end if;
--         end if;

--         if resetn = '0' or clr_cmp0_if = '1' then
--             TIMxCMP0_if <= '0';
--         end if;
--         if resetn = '0' or clr_cmp1_if = '1' then
--             TIMxCMP1_if <= '0';
--         end if;
--     end process;

--     -- Timer Compare 2 for Reset (used for resetting the timer)
--     clr_TIMxVAL <= '1' when (TIMxCMP2_reset = '1' and TIMxVAL = TIMxCMP2) else '0';

--     process (resetn, clk_timer, clr_cmp2_if, en_timer, TIMxVAL)
--     begin
--         if resetn = '0' or clr_cmp2_if = '1' or en_timer = '0' then
--             TIMxCMP2_if <= '0';
--         elsif rising_edge(clk_timer) then
--             if clr_TIMxVAL = '1' then
--                 TIMxCMP2_if <= '1';
--             end if;
--         end if;
--     end process;

--     ------------------------------------
--     -- Signal Routing
--     ------------------------------------

--     cmp0_out <= TIMxCMP0_out;
--     cmp0_dir <= '1';
--     cmp0_ren <= cmp0_ren_in;

--     cmp1_out <= TIMxCMP1_out;
--     cmp1_dir <= '1';
--     cmp1_ren <= cmp1_ren_in;

--     -- irq <=  (TIMxCAP1_if and TIMxCAP1_ie) or (TIMxCAP0_if and TIMxCAP0_ie) or
--     --         (timer_ovf_if and timer_ovf_ie) or (TIMxCMP2_if and TIMxCMP2_ie) or
--     --         (TIMxCMP1_if and TIMxCMP1_ie) or (TIMxCMP0_if and TIMxCMP0_ie);

--     irq_cap0 <= TIMxCAP0_if and TIMxCAP0_ie;
--     irq_cap1 <= TIMxCAP1_if and TIMxCAP1_ie;
--     irq_ovf  <= timer_ovf_if and timer_ovf_ie;
--     irq_cmp0 <= TIMxCMP0_if and TIMxCMP0_ie;
--     irq_cmp1 <= TIMxCMP1_if and TIMxCMP1_ie;
--     irq_cmp2 <= TIMxCMP2_if and TIMxCMP2_ie;

--     -- =============================================================================
--     -- Register Synchronization for Memory Interface
--     -- =============================================================================
--     reg_sync: process(en_mem) --TODO: Sensitive to regs?
--     begin
--         if falling_edge(en_mem) then 
--             TIMxSR_ltch <= not TIMxSR;
--             TIMxVAL_ltch <= not TIMxVAL;
--             TIMxCAP0_ltch <= not TIMxCAP0;
--             TIMxCAP1_ltch <= not TIMxCAP1;
--         end if;
--     end process;


    

--     -- =============================================================================
--     -- Memory-Mapped Register Interface
--     -- =============================================================================
    
--     -- Address decoding
--     en_addr_periph <= slv2uint(addr_periph) when en_mem = '0' else 0;

--     -- Register Write Process 
--     reg_write_proc: process(resetn, clk_mem)
--     begin
--         if resetn = '0' then
-- 	        TIMxCR <= (others => '0');
-- 			TIMxCMP0 <= (others => '0');
-- 			TIMxCMP1 <= (others => '0');
-- 			TIMxCMP2 <= (others => '0');
--         elsif rising_edge(clk_mem) then
            
--             -- Handle register writes
--             if en_mem = '0' then -- TODO: Redundant
--                 case en_addr_periph is
--                     when RegSlotTIMxCR =>
--                         if wen(0) = '0' then
--                             TIMxCR(7 downto 0) <= write_data(7 downto 0);
--                         end if;
--                         if wen(1) = '0' then
--                             TIMxCR(15 downto 8) <= write_data(15 downto 8);
--                         end if;
--                         if wen(2) = '0' then
--                             TIMxCR(19 downto 16) <= write_data(19 downto 16);
--                         end if;
--                     when RegSlotTIMxSR =>
--                         if wen(0) = '0' then
--                             if write_data(0) = '1' then
--                                 clr_cmp0_if <= '1';
--                             end if;
--                             if write_data(1) = '1' then
--                                 clr_cmp1_if <= '1';
--                             end if;
--                             if write_data(2) = '1' then
--                                 clr_cmp2_if <= '1';
--                             end if;
--                             if write_data(3) = '1' then
--                                 clr_ovf_if <= '1';
--                             end if;
--                             if write_data(4) = '1' then
--                                 clr_cap0_if <= '1';
--                             end if;
--                             if write_data(5) = '1' then
--                                 clr_cap1_if <= '1';
--                             end if;
--                         end if;
--                     when RegSlotTIMxVAL =>
--                         if wen /= "1111" then
--                             TIMxVAL_mab <= write_data;
--                             latch_value <= '1';
--                         end if;
--                     when RegSlotTIMxCMP0 =>
--                         if wen(0) = '0' then
--                             TIMxCMP0(7 downto 0) <= write_data(7 downto 0);
--                         end if;
--                         if wen(1) = '0' then
--                             TIMxCMP0(15 downto 8) <= write_data(15 downto 8);
--                         end if;
--                         if wen(2) = '0' then
--                             TIMxCMP0(23 downto 16) <= write_data(23 downto 16);
--                         end if;
--                         if wen(3) = '0' then
--                             TIMxCMP0(31 downto 24) <= write_data(31 downto 24);
--                         end if;
--                   when RegSlotTIMxCMP1 =>
--                         if wen(0) = '0' then
--                             TIMxCMP1(7 downto 0) <= write_data(7 downto 0);
--                         end if;
--                         if wen(1) = '0' then
--                             TIMxCMP1(15 downto 8) <= write_data(15 downto 8);
--                         end if;
--                         if wen(2) = '0' then
--                             TIMxCMP1(23 downto 16) <= write_data(23 downto 16);
--                         end if;
--                         if wen(3) = '0' then
--                             TIMxCMP1(31 downto 24) <= write_data(31 downto 24);
--                         end if;
--                   when RegSlotTIMxCMP2 =>
--                         if wen(0) = '0' then
--                             TIMxCMP2(7 downto 0) <= write_data(7 downto 0);
--                         end if;
--                         if wen(1) = '0' then
--                             TIMxCMP2(15 downto 8) <= write_data(15 downto 8);
--                         end if;
--                         if wen(2) = '0' then
--                             TIMxCMP2(23 downto 16) <= write_data(23 downto 16);
--                         end if;
--                         if wen(3) = '0' then
--                             TIMxCMP2(31 downto 24) <= write_data(31 downto 24);
--                         end if;
--                     when others =>
--                         null;
--                 end case;
--             end if;
--         end if;
--         --Handle clear signals 
--         if resetn = '0' or en_mem = '1' then
--             clr_cmp0_if <= '0';
--             clr_cmp1_if <= '0';
--             clr_cmp2_if <= '0';
--             clr_ovf_if <= '0';
--             clr_cap0_if <= '0';
--             clr_cap1_if <= '0';
--             latch_value <= '0';
--         end if;
--     end process;

--     -- Register Read Process 
--     reg_read_proc: process(clk_mem)
--     begin
--         if rising_edge(clk_mem) then
--             case en_addr_periph is
--                 when RegSlotTIMxCR =>
--                     read_data <= (31 downto TIMxCR'high + 1 => '0') & TIMxCR;
--                 when RegSlotTIMxSR =>
--                     read_data <= (31 downto TIMxSR'high + 1 => '0') & (not TIMxSR_ltch);
--                 when RegSlotTIMxVAL =>
--                     read_data <= (31 downto TIMxVAL'high + 1 => '0') & TIMxVAL;
--                 when RegSlotTIMxCAP0 =>
--                     read_data <= not TIMxCAP0_ltch;
--                 when RegSlotTIMxCAP1 =>
--                     read_data <= not TIMxCAP1_ltch;
--                 when RegSlotTIMxCMP0 =>
--                     read_data <= TIMxCMP0;
--                 when RegSlotTIMxCMP1 =>
--                     read_data <= TIMxCMP1;
--                 when RegSlotTIMxCMP2 =>
--                     read_data <= TIMxCMP2;
--                 when others =>
--                     read_data <= (others => '0'); -- Return zeros for unmapped addresses
--             end case;
--         end if;
--     end process;

-- end rtl;