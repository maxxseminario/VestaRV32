library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.constants.all;
use work.MemoryMap.all;

entity SARADC is
    -- generic (
    --     NUM_ADCS : integer := 1  
    -- );
    port (
        -- System Signals
        clk         : in  std_logic;  
        resetn       : in  std_logic;  
        irq          : out std_logic;  

        -- Memory Bus (active low enables)
        clk_mem      : in  std_logic;
        en_mem       : in  std_logic;                       
        wen          : in  std_logic_vector(3 downto 0); 
        addr_periph  : in  std_logic_vector(7 downto 2);
        write_data   : in  std_logic_vector(31 downto 0);
        read_data    : out std_logic_vector(31 downto 0);

        -- Digital Test Ports 
        dtp0   : out std_logic;
        dtp1   : out std_logic;
        dtp2   : out std_logic;
        dtp3   : out std_logic;

        -- ADC Connection 
        ADC_ready_i : in std_logic;
        ADC_data_i  : in std_logic_vector(9 downto 0); 
        ADC_reset  : out std_logic;
        ADC_trigger_clock_o : out std_logic


    );
end SARADC;

-- TODO: Flag for overflow

architecture rtl of SARADC is

    -- Internal reset (active high)
    signal reset_i : std_logic;

    -- Register definitions
    -- TODO: Size Registers 
    signal SARADC_CR    : std_logic_vector(31 downto 0);
    signal SARADC_SR    : std_logic_vector(31 downto 0);
    signal SARADC_DATA  : std_logic_vector(31 downto 0);


    -- Sync clock signals
    signal ADC_sync_clock : std_logic;
    signal ADC_sync_clock_active : std_logic;
    signal ADC_sync_clock_active_synced0 : std_logic;
    signal ADC_sync_clock_active_synced1 : std_logic;
    signal ADC_sync_clock_phase_shift_reg : std_logic_vector(15 downto 0);
    signal ADC_sync_clock_clear_phase : std_logic;
    signal ADC_sync_clock_sample_phase : std_logic;
    signal ADC_sync_clock_conversion_phase : std_logic;
    signal ADC_sync_clock_activation_allowed : std_logic;
    signal ADC_sync_sample_step_counter : std_logic_vector(2 downto 0);

    -- Debug signals
    signal ADC_debug : std_logic_vector(9 downto 0);

    -- Signal routing from control register TODO
    -- signal active_channel               : std_logic_vector(4 downto 0);
    signal external_trigger_clock_mode  : std_logic; --TODO: What is this ? Check.
    signal adc_sync_init_sample_step    : std_logic_vector(2 downto 0); --changed from pulse width 
    signal debug_mode                   : std_logic;
    signal adc_en                       : std_logic;

    -- Signal routing for status register
    signal adc_ready_status : std_logic;
    signal conversion_busy : std_logic;

    -- Signal routing for output register
    signal adc_data_out : std_logic_vector(9 downto 0);
    signal adc_channel_id : std_logic_vector(4 downto 0);
    signal adc_data_valid : std_logic;

    -- ADC control signals
    signal ADC_trigger_clock : std_logic;
    signal ADC_ready : std_logic;
    signal ADC_data : std_logic_vector(9 downto 0);



    -- Memory interface signals
    signal en_addr_periph : integer;
    signal adc_ready_prev : std_logic;
    signal clr_data_valid : std_logic;


begin

    -- Convert active low reset to active high to jive with Zhilis setup
    reset_i <= not resetn;


    -- Register Signal Routing 
    -- SARADC_CR
    adc_reset                       <= SARADC_CR(0);  --TODO: This could be done more elegently, but manual reset for now.
    adc_sync_init_sample_step       <= SARADC_CR(12 downto 10);     
    external_trigger_clock_mode     <= SARADC_CR(13);              
    adc_en                          <= SARADC_CR(14);                                 
    debug_mode                      <= SARADC_CR(15);                                      

    -- SARADC_SR
    SARADC_SR(10)                   <= adc_ready_status;                         
    SARADC_SR(11)                   <= conversion_busy;                         
    SARADC_SR(31 downto 12)         <= (others => '0');                   
    SARADC_SR(9 downto 0)           <= (others => '0');                     

    -- SARADC_DATA
    SARADC_DATA(9 downto 0)           <= adc_data_out;                   
    SARADC_DATA(14 downto 10)         <= adc_channel_id;              
    SARADC_DATA(15)                   <= adc_data_valid;                          
    SARADC_DATA(31 downto 16)         <= (others => '0');     
    
    

    -- Update status signals TODO
    adc_ready_status <= ADC_ready;
    conversion_busy <= ADC_sync_clock_active;


    -- ADC data capture logic
    ADC_Data_Capture : process (clk, reset_i)
    begin
        if reset_i = '1' then
            adc_ready_prev <= '0';
            adc_data_out <= (others => '0');
            adc_channel_id <= (others => '0');
            adc_data_valid <= '0';
        elsif rising_edge(clk) then
            adc_ready_prev <= ADC_ready;
            -- Capture data on rising edge of ADC_ready
            if ADC_ready = '1' and adc_ready_prev = '0' then
                adc_data_out <= ADC_data;
                -- adc_channel_id <= active_channel;
                adc_data_valid <= '1';
            elsif clr_data_valid = '1' then
                -- Clear data valid flag when output register is read
                adc_data_valid <= '0';
            end if;
        end if;
    end process;

    -- Debug test ports
    dtp0 <= ADC_debug(0) when debug_mode = '1' else '0';
    dtp1 <= ADC_debug(1) when debug_mode = '1' else '0';
    dtp2 <= ADC_debug(2) when debug_mode = '1' else '0';
    dtp3 <= ADC_debug(3) when debug_mode = '1' else '0';


    -- Generate IRQ when ADC data is ready and valid
    -- TODO: ie signals 
    irq <= adc_data_valid;



    -- Choose clk type - in this case all ADCs are synchronous
    ADC_trigger_clock <= ADC_sync_clock;




    -- Sync clock logic (modified to use divided clock instead of oscillator)
    ADC_sync_clock_activation_allowed <= '1' when ((ADC_sync_clock_phase_shift_reg = "1000000000000000")
                                                    and (adc_en = '1') 
                                                    and (ADC_ready = '1')
                                                    and (external_trigger_clock_mode = '0')) else '0';
    

    -- Synchronizer Logic (What are the two clock domains here?)
    Clock_Active_Synchronizer : process (reset_i, ADC_sync_clock_active, adc_en, clk)
    begin
        if (reset_i = '1') or (ADC_sync_clock_active = '0') or (adc_en = '0') then
            ADC_sync_clock_active_synced0 <= '0';
            ADC_sync_clock_active_synced1 <= '0';
        elsif falling_edge(clk) then
            ADC_sync_clock_active_synced0 <= ADC_sync_clock_active;
            ADC_sync_clock_active_synced1 <= ADC_sync_clock_active_synced0;
        end if;
    end process;

    -- Shift register and count down.
    Sync_Clock_Step : process (reset_i, ADC_sync_clock_active, adc_en, clk)
    begin
        if (reset_i = '1') or (ADC_sync_clock_active = '0') or (adc_en = '0') then
            ADC_sync_sample_step_counter <= adc_sync_init_sample_step;
            ADC_sync_clock_phase_shift_reg <= "1000000000000000";
            ADC_sync_clock_conversion_phase <= '0';
        elsif (ADC_sync_clock_active_synced1 = '1') and falling_edge(clk) then
            if (ADC_sync_clock_sample_phase = '1') and (ADC_sync_sample_step_counter /= "000") then
                -- sample countdown during sample phase
                ADC_sync_sample_step_counter <= std_logic_vector(unsigned(ADC_sync_sample_step_counter) - 1);
            elsif (ADC_sync_clock_phase_shift_reg(0) /= '1') then 
                -- shift right until the 1 reaches end and then wait to be reset
                ADC_sync_clock_phase_shift_reg(14 downto 0) <= ADC_sync_clock_phase_shift_reg(15 downto 1);
                ADC_sync_clock_phase_shift_reg(15) <= '0';
            end if;

            -- Generate conversion flag
            if (ADC_sync_clock_phase_shift_reg(11) = '1') then
                ADC_sync_clock_conversion_phase <= '1';
            elsif (ADC_sync_clock_phase_shift_reg(1) = '1') then
                ADC_sync_clock_conversion_phase <= '0';
            end if;

        end if;
    end process;

    -- Phase Flags 

    ADC_sync_clock_clear_phase <= ADC_sync_clock_phase_shift_reg(14);
    ADC_sync_clock_sample_phase <= ADC_sync_clock_phase_shift_reg(12);

    -- Clock waveform generation
    -- TODO: Gate this clock with IP!
    ADC_sync_clock <= ADC_sync_clock_clear_phase or ADC_sync_clock_sample_phase or (ADC_sync_clock_conversion_phase and clk);


    -- No muxing if ony one adc is present
    ADC_ready <= ADC_ready_i;
    ADC_data <= ADC_data_i;



    -- =============================================================================
    -- Memory-Mapped Register Interface
    -- =============================================================================
    en_addr_periph <= slv2uint(addr_periph) when en_mem = '0' else 0;


    -- Register Write Process 
    write_proc: process(resetn, clk_mem, clr_data_valid)
    begin
        if resetn = '0' then
            SARADC_CR <= x"00002020";  -- Default: channel=0, pulse_width=31, sync_step=7, ext_trigger=1, adc_en=0, debug=0
            
        elsif rising_edge(clk_mem) then
            if en_mem = '0' then
                case en_addr_periph is
                    when RegSlotSARADC_CR =>
                        if wen(0) = '0' then
                            SARADC_CR(7 downto 0) <= write_data(7 downto 0);
                        end if;
                        if wen(1) = '0' then
                            SARADC_CR(15 downto 8) <= write_data(15 downto 8);
                        end if;
                        if wen(2) = '0' then
                            SARADC_CR(23 downto 16) <= write_data(23 downto 16);
                        end if;
                        if wen(3) = '0' then
                            SARADC_CR(31 downto 24) <= write_data(31 downto 24);
                        end if;
                    when RegSlotSARADC_DATA =>
                        -- Reading from output register clears data valid flag
                        if wen = "1111" then  -- Read operation
                            clr_data_valid <= '1';
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;

        -- Handle clear signals
        if resetn = '0' or clr_data_valid = '1' then
            -- Clear handled in ADC data capture process
        end if;

        if resetn = '0' or en_mem = '1' then
            clr_data_valid <= '0';
        end if;
    end process;

        -- Register Read Process 
    read_proc: process(clk_mem)
    begin
        if rising_edge(clk_mem) then
            read_data <= (others => '0');
            case en_addr_periph is
                when RegSlotSARADC_CR =>
                    read_data(SARADC_CR'high downto SARADC_CR'low) <= SARADC_CR;
                when RegSlotSARADC_SR =>
                    read_data(SARADC_SR'high downto SARADC_SR'low) <= SARADC_SR;
                when RegSlotSARADC_DATA =>
                    read_data(SARADC_DATA'high downto SARADC_DATA'low) <= SARADC_DATA;
                when others =>
                    read_data <= (others => '0');
            end case;
        end if;
    end process;





end architecture;