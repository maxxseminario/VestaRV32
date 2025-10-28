library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.macros.all;  

package spi_macros is
    -- Constants
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz system clock

    -- Helper procedure for register writes
    procedure spi_write(
        signal clk      : in std_logic;
        signal addr_sig : out std_logic_vector(31 downto 0);
        signal din_sig  : out std_logic_vector(31 downto 0);
        signal we_sig   : out std_logic;
        addr_val  : in std_logic_vector(31 downto 0);
        data_val  : in std_logic_vector(31 downto 0)
    );

    -- Helper procedure for register reads
    procedure spi_read(
        signal clk      : in std_logic;
        signal addr_sig : out std_logic_vector(31 downto 0);
        signal re_sig   : out std_logic;
        addr_val  : in std_logic_vector(31 downto 0)
    );

    -- Helper procedure to wait for SPI transaction completion
    procedure wait_spi_ready(
        signal clk      : in std_logic;
        signal busy_sig : in std_logic
    );

    -- -- Helper procedure to power on flash and read contents word by word
    -- procedure read_flash_contents(
    --     signal clk      : in std_logic;
    --     signal addr_sig : out std_logic_vector(31 downto 0);
    --     signal din_sig : out std_logic_vector(31 downto 0);
    --     signal we_sig : out std_logic;
    --     signal re_sig : out std_logic;
    --     signal busy_sig : in std_logic;
    --     signal dout_sig : in std_logic_vector(31 downto 0);
    --     signal new_read_data: out std_logic;
    --     start_address : in natural;
    --     word_count : in natural
    -- );

        -- Helper procedure to power on flash and read contents word by word
    procedure minimal_flash_read(
        signal clk       : in  std_logic;
        signal addr_sig  : out std_logic_vector(31 downto 0);
        signal din_sig   : in std_logic_vector(31 downto 0);
        signal dout_sig  : out std_logic_vector(31 downto 0);
        signal we_sig    : out std_logic;
        signal re_sig    : out std_logic;
        signal busy_sig  : in  std_logic;
        signal new_word  : out std_logic;
        signal word32     : out std_logic_vector(31 downto 0);
        word_count       : in  natural
    );



    
end package spi_macros;

package body spi_macros is
    -- Implementation of spi_write
    procedure spi_write(
        signal clk      : in std_logic;
        signal addr_sig : out std_logic_vector(31 downto 0);
        signal din_sig  : out std_logic_vector(31 downto 0);
        signal we_sig   : out std_logic;
        addr_val  : in std_logic_vector(31 downto 0);
        data_val  : in std_logic_vector(31 downto 0)
    )is
    begin
        addr_sig <= addr_val;
        din_sig <= data_val;
        we_sig <= '1';
        wait until rising_edge(clk);
        we_sig <= '0';
        wait until rising_edge(clk);
    end procedure;

    -- Implementation of spi_read
    procedure spi_read(
        signal clk      : in std_logic;
        signal addr_sig : out std_logic_vector(31 downto 0);
        signal re_sig   : out std_logic;
        addr_val  : in std_logic_vector(31 downto 0)
    )is
    begin
        addr_sig <= addr_val;
        re_sig <= '1';
        wait until rising_edge(clk);
        re_sig <= '0';
        wait until rising_edge(clk);
    end procedure;

    -- Implementation of wait_spi_ready
    procedure wait_spi_ready(
        signal clk      : in std_logic;
        signal busy_sig : in std_logic
    ) is
    begin
        while busy_sig = '1' loop
            wait until rising_edge(clk);
        end loop;
    end procedure;


procedure minimal_flash_read(
    signal clk       : in  std_logic;
    signal addr_sig  : out std_logic_vector(31 downto 0);
    signal din_sig   : in std_logic_vector(31 downto 0); --into CPU
    signal dout_sig  : out std_logic_vector(31 downto 0); --out of CPU
    signal we_sig    : out std_logic;
    signal re_sig    : out std_logic;
    signal busy_sig  : in  std_logic;
    signal new_word  : out std_logic;
    signal word32     : out std_logic_vector(31 downto 0);
    word_count       : in  natural
) is
    -- variable word32     : std_logic_vector(31 downto 0) := (others => '0');
    variable byte_val   : std_logic_vector(7 downto 0);
begin
    -- === Power On Flash ===
    addr_sig <= x"00000000"; dout_sig <= x"00000001"; we_sig <= '1';
    wait until rising_edge(clk); we_sig <= '0'; wait until rising_edge(clk);

    addr_sig <= x"00000004"; dout_sig <= x"000000AB"; we_sig <= '1';
    wait until rising_edge(clk); we_sig <= '0'; wait until rising_edge(clk);

    addr_sig <= x"00000000"; dout_sig <= x"00000003"; we_sig <= '1'; -- START
    wait until rising_edge(clk); we_sig <= '0';

    wait until rising_edge(clk) and busy_sig = '0';
    wait for 40 us; -- Simulated flash ready delay

    -- === Send 0x03 Read Command ===
    addr_sig <= x"00000000"; dout_sig <= x"00000001"; we_sig <= '1';
    wait until rising_edge(clk); we_sig <= '0'; wait until rising_edge(clk);

    addr_sig <= x"00000004"; dout_sig <= x"00000003"; we_sig <= '1';
    wait until rising_edge(clk); we_sig <= '0'; wait until rising_edge(clk);

    addr_sig <= x"00000000"; dout_sig <= x"00000003"; we_sig <= '1'; -- START
    wait until rising_edge(clk); we_sig <= '0';
    wait until rising_edge(clk) and busy_sig = '0';

    -- === Send address 0x000000 (3 bytes) ===
    for i in 2 downto 0 loop
        addr_sig <= x"00000004"; dout_sig <= x"00000000"; we_sig <= '1';
        wait until rising_edge(clk); we_sig <= '0'; wait until rising_edge(clk);

        addr_sig <= x"00000000"; dout_sig <= x"00000003"; we_sig <= '1'; -- START
        wait until rising_edge(clk); we_sig <= '0'; 
        -- wait until rising_edge(clk);

        wait until rising_edge(clk) and busy_sig = '0';
    end loop;

    addr_sig <= x"00000000"; dout_sig <= x"00000003"; we_sig <= '1'; --send one dummy byte to begin
                wait until rising_edge(clk); we_sig <= '0'; wait until rising_edge(clk);
            wait until rising_edge(clk) and busy_sig = '0';

    -- === Read word_count 32-bit words ===
    for i in 0 to word_count - 1 loop
        -- word32 := (others => '0');

        for j in 0 to 3 loop
            -- Start SPI transfer
            addr_sig <= x"00000000"; dout_sig <= x"00000003"; we_sig <= '1';
            wait until rising_edge(clk); we_sig <= '0'; wait until rising_edge(clk);
            wait until rising_edge(clk) and busy_sig = '0';

            -- Read byte
            addr_sig <= x"00000004"; re_sig <= '1';
            wait until rising_edge(clk); re_sig <= '0'; wait until rising_edge(clk);
            byte_val := din_sig(7 downto 0);

            -- Shift byte into word32 (Little Endian: byte 0 is LSB)
            word32 <= byte_val & word32(31 downto 8);
        end loop;
            -- byte_val := din_sig(7 downto 0);
            -- word32 := byte_val & word32(31 downto 8);

        -- Output the complete word
        -- word32 <= word32;
        new_word <= '1';
        wait until rising_edge(clk);
        new_word <= '0';
    end loop;
end procedure;




    -- -- Implementation of read_flash_contents
    -- procedure read_flash_contents(
    --     signal clk      : in std_logic;
    --     signal addr_sig : out std_logic_vector(31 downto 0);
    --     signal din_sig : out std_logic_vector(31 downto 0);
    --     signal we_sig : out std_logic;
    --     signal re_sig : out std_logic;
    --     signal busy_sig : in std_logic;
    --     signal dout_sig : in std_logic_vector(31 downto 0);
    --     signal new_read_data: out std_logic;
    --     start_address : in natural;
    --     word_count : in natural
        
    -- ) is
    --     variable word32 : std_logic_vector(31 downto 0) := (others => '0');
    --     variable byte_read : std_logic_vector(7 downto 0);
    --     variable current_addr : natural :=  0; -- Start address for reading
    -- begin
        

    --     -- Power on the flash
    --     report "Powering on flash";
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000001"); -- Set CS=1
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000004", x"000000AB"); -- Power on command (0xAB)
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003"); -- CS=1, START=1
    --     wait_spi_ready(clk, busy_sig);
        
    --     -- Wait for flash to become ready (30us in flash model)
    --     wait for 40 us;

    --     -- Send read command (0x03) with address
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000001"); -- Set CS=1
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000004", x"00000003"); -- Read command
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003"); -- CS=1, START=1
    --     wait_spi_ready(clk, busy_sig);

    --     new_read_data <= '0';
        
    --     -- Send 3 address bytes (MSB to LSB)
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000004", 
    --                 std_logic_vector(to_unsigned((current_addr / 65536) mod 256, 32))); -- MSB
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003");
    --     wait_spi_ready(clk, busy_sig);

        
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000004", 
    --                 std_logic_vector(to_unsigned((current_addr / 256) mod 256, 32))); -- Middle byte
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003");
    --     wait_spi_ready(clk, busy_sig);
        
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000004", 
    --                 std_logic_vector(to_unsigned(current_addr mod 256, 32))); -- LSB
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003");
    --     wait_spi_ready(clk, busy_sig);
        
    --     --TODO maybe put a wait here 

    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003"); -- START -- Dummy to get first byte at beginning of read
        
        
    --     -- Read flash contents word by word
    --     -- current_addr := start_address;
    --     for i in 0 to word_count-1 loop
    --         -- spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003"); -- START

    --         -- Read 4 bytes (32-bit word)
    --         word32 := (others => '0');
    --         for j in 0 to 3 loop
    --             wait_spi_ready(clk, busy_sig);
    --             spi_read(clk, addr_sig, re_sig, x"00000004");
    --             byte_read := dout_sig(7 downto 0);
    --             word32 := byte_read & word32(31 downto 8); -- Little-endian?
    --         end loop;
    --         new_read_data <= '1';
    --         wait until rising_edge(clk);
    --         new_read_data <= '0';
    --     end loop;

    --     --dummy byte to deassert chip select
    --     --TODO: Look into proper way of doing this 
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000001"); -- Set CS=1 (Deassert)
    --     wait_spi_ready(clk, busy_sig);
    --     new_read_data <= '0';


    -- end procedure;
    
    

    -- -- Implementation of read_flash_contents
    -- procedure read_flash_contents(
    --     signal clk      : in std_logic;
    --     signal addr_sig : out std_logic_vector(31 downto 0);
    --     signal din_sig : out std_logic_vector(31 downto 0);
    --     signal we_sig : out std_logic;
    --     signal re_sig : out std_logic;
    --     signal busy_sig : in std_logic;
    --     signal dout_sig : in std_logic_vector(31 downto 0);
    --     signal new_read_data: out std_logic;
    --     start_address : in natural;
    --     word_count : in natural
        
    -- ) is
    --     variable word32 : std_logic_vector(31 downto 0) := (others => '0');
    --     variable byte_read : std_logic_vector(7 downto 0);
    --     variable current_addr : natural;
    -- begin
        

    --     -- Power on the flash
    --     report "Powering on flash";
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000001"); -- Set CS=1
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000004", x"000000AB"); -- Power on command (0xAB)
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003"); -- CS=1, START=1
    --     wait_spi_ready(clk, busy_sig);
        
    --     -- Wait for flash to become ready (30us in flash model)
    --     wait for 40 us;
        
    --     -- Read flash contents word by word
    --     current_addr := start_address;
    --     for i in 0 to word_count-1 loop
    --         -- Send read command (0x03) with address
    --         spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000001"); -- Set CS=1
    --         spi_write(clk, addr_sig, din_sig, we_sig, x"00000004", x"00000003"); -- Read command
    --         spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003"); -- CS=1, START=1
    --         wait_spi_ready(clk, busy_sig);

    --         new_read_data <= '0';
            
    --         -- Send 3 address bytes (MSB to LSB)
    --         spi_write(clk, addr_sig, din_sig, we_sig, x"00000004", 
    --                  std_logic_vector(to_unsigned((current_addr / 65536) mod 256, 32))); -- MSB
    --         spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003");
    --         wait_spi_ready(clk, busy_sig);

            
    --         spi_write(clk, addr_sig, din_sig, we_sig, x"00000004", 
    --                  std_logic_vector(to_unsigned((current_addr / 256) mod 256, 32))); -- Middle byte
    --         spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003");
    --         wait_spi_ready(clk, busy_sig);
            
    --         spi_write(clk, addr_sig, din_sig, we_sig, x"00000004", 
    --                  std_logic_vector(to_unsigned(current_addr mod 256, 32))); -- LSB
    --         spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003");
    --         wait_spi_ready(clk, busy_sig);
            
    --         -- Read 4 bytes (32-bit word)
    --         word32 := (others => '0');
    --         for j in 0 to 4 loop
    --             spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000003"); -- START
    --             wait_spi_ready(clk, busy_sig);
    --             spi_read(clk, addr_sig, re_sig, x"00000004");
    --             byte_read := dout_sig(7 downto 0);
    --             word32 := byte_read & word32(31 downto 8); -- Little-endian?
    --         end loop;

    --         new_read_data <= '1';
            
    --         current_addr := current_addr + 4;
    --     end loop;

    --     --dummy byte to deassert chip select
    --     --TODO: Look into proper way of doing this 
    --     spi_write(clk, addr_sig, din_sig, we_sig, x"00000000", x"00000001"); -- Set CS=1 (Deassert)
    --     wait_spi_ready(clk, busy_sig);
    --     new_read_data <= '0';


    -- end procedure;
end package body spi_macros;