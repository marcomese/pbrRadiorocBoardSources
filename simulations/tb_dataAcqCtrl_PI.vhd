library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_dataAcqCtrl_PI is
end tb_dataAcqCtrl_PI;

architecture Behavioral of tb_dataAcqCtrl_PI is

    constant clkPeriod200M : time := 5 ns;
    constant sclkPeriod    : time := 50 ns;   -- 20 MHz SPI clock

    -- Top-level ports
    signal sysClk_p, sysClk_n : std_logic := '0';
    signal npwr_reset         : std_logic := '0';

    signal id                 : std_logic_vector(2 downto 0) := "110";  -- board ID = 6

    -- I2C SiPM-Calo (inout)
    signal sc_scl, sc_sda     : std_logic := 'H';
    signal sc_clk_sm          : std_logic;
    signal sc_val_evt         : std_logic;
    signal sc_errorb          : std_logic := '0';
    signal sc_rstn_read       : std_logic;
    signal sc_ck_read         : std_logic;
    signal sc_reset_n         : std_logic;
    signal sc_rstb_sc         : std_logic;
    signal sc_rstb_probe      : std_logic;
    signal sc_rstb_i2c        : std_logic;
    signal sc_outd_probe      : std_logic := '0';
    signal sc_holdext         : std_logic;
    signal sc_trigext         : std_logic;
    signal sc_NORT2           : std_logic := '1';
    signal sc_NORT1           : std_logic := '1';
    signal sc_NORTQ           : std_logic := '1';

    -- Trigger inputs
    signal T_1                : std_logic_vector(63 downto 0) := (others => '0');
    signal T_2                : std_logic_vector(63 downto 0) := (others => '0');

    -- ADC LVDS
    signal ADC_SCKHG_p, ADC_SCKHG_n : std_logic;
    signal ADC_SCKLG_p, ADC_SCKLG_n : std_logic;
    signal ADC_HG_p           : std_logic := '0';
    signal ADC_HG_n           : std_logic := '1';
    signal ADC_LG_p           : std_logic := '0';
    signal ADC_LG_n           : std_logic := '1';
    signal nCNV               : std_logic;
    signal nCMOS              : std_logic;

    -- TMP275 I2C
    signal SCL_275, SDA_275   : std_logic := 'H';

    -- Pulse generator / DAC
    signal pulse              : std_logic;
    signal dacSDI             : std_logic;
    signal dacSCLK            : std_logic;
    signal dacCS              : std_logic;

    -- SPI slave (LVDS)
    signal readRq_p, readRq_n : std_logic;
    signal cs_p, cs_n         : std_logic := '1';
    signal sclk_p, sclk_n     : std_logic := '0';
    signal mosi_p, mosi_n     : std_logic := '0';
    signal miso_p, miso_n     : std_logic;

    signal extTrg             : std_logic;

    -- Single-ended SPI signals (driven by stimulus, then converted to differential)
    signal cs_se   : std_logic := '1';
    signal sclk_se : std_logic := '0';
    signal mosi_se : std_logic := '0';

begin

    -- Differential clock generation (200 MHz)
    sysClk_p <= not sysClk_p after clkPeriod200M/2;
    sysClk_n <= not sysClk_n after clkPeriod200M/2;
    sysClk_n <= not sysClk_p;  -- ensure complementary

    -- SPI single-ended to differential
    cs_p   <= cs_se;
    cs_n   <= not cs_se;
    sclk_p <= sclk_se;
    sclk_n <= not sclk_se;
    mosi_p <= mosi_se;
    mosi_n <= not mosi_se;

    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    DUT: entity work.radioroc_fw
    port map(
        sysClk_p      => sysClk_p,
        sysClk_n      => sysClk_n,
        npwr_reset    => npwr_reset,
        id            => id,

        sc_scl        => sc_scl,
        sc_sda        => sc_sda,
        sc_clk_sm     => sc_clk_sm,
        sc_val_evt    => sc_val_evt,
        sc_errorb     => sc_errorb,
        sc_rstn_read  => sc_rstn_read,
        sc_ck_read    => sc_ck_read,
        sc_reset_n    => sc_reset_n,
        sc_rstb_sc    => sc_rstb_sc,
        sc_rstb_probe => sc_rstb_probe,
        sc_rstb_i2c   => sc_rstb_i2c,
        sc_outd_probe => sc_outd_probe,
        sc_holdext    => sc_holdext,
        sc_trigext    => sc_trigext,
        sc_NORT2      => sc_NORT2,
        sc_NORT1      => sc_NORT1,
        sc_NORTQ      => sc_NORTQ,

        T_1           => T_1,
        T_2           => T_2,

        ADC_SCKHG_p   => ADC_SCKHG_p,
        ADC_SCKHG_n   => ADC_SCKHG_n,
        ADC_SCKLG_p   => ADC_SCKLG_p,
        ADC_SCKLG_n   => ADC_SCKLG_n,
        ADC_HG_p      => ADC_HG_p,
        ADC_HG_n      => ADC_HG_n,
        ADC_LG_p      => ADC_LG_p,
        ADC_LG_n      => ADC_LG_n,
        nCNV          => nCNV,
        nCMOS         => nCMOS,

        SCL_275       => SCL_275,
        SDA_275       => SDA_275,

        pulse         => pulse,
        dacSDI        => dacSDI,
        dacSCLK       => dacSCLK,
        dacCS         => dacCS,

        readRq_p      => readRq_p,
        readRq_n      => readRq_n,
        cs_p          => cs_p,
        cs_n          => cs_n,
        sclk_p        => sclk_p,
        sclk_n        => sclk_n,
        mosi_p        => mosi_p,
        mosi_n        => mosi_n,
        miso_p        => miso_p,
        miso_n        => miso_n,

        extTrg        => extTrg
    );

    -- Free-running ADC LVDS data lines
    ADC_HG_p <= not ADC_HG_p after 10 ns;
    ADC_HG_n <= not ADC_HG_p;
    ADC_LG_p <= not ADC_LG_p after 10 ns;
    ADC_LG_n <= not ADC_LG_p;

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stimProc: process

        -- Send a single byte over SPI (mode 1: CPOL=0, CPHA=1, MSB first).
        procedure sendByte(constant b : in std_logic_vector(7 downto 0)) is
        begin
            for i in 7 downto 0 loop
                sclk_se <= '1';
                mosi_se <= b(i);
                wait for sclkPeriod/2;
                sclk_se <= '0';
                wait for sclkPeriod/2;
            end loop;
        end procedure;

        procedure startSpi is
        begin
            sclk_se <= '0';
            mosi_se <= '0';
            cs_se   <= '0';
            wait for sclkPeriod/2;
        end procedure;

        procedure endSpi is
        begin
            wait for sclkPeriod/2;
            cs_se   <= '1';
            mosi_se <= '0';
            wait for sclkPeriod;
        end procedure;

    begin
        -- Power-on reset (active low)
        npwr_reset <= '0';
        wait for clkPeriod200M*1000;
        npwr_reset <= '1';
        wait for clkPeriod200M*100;

        wait for 1 us;

        --------------------------------------------------------------------
        -- 1st transaction: 0x76, 0x55, 0x00, 0x03, 0x00, 0x00, 0x00, 0x02
        --------------------------------------------------------------------
        startSpi;
        sendByte(x"76");
        sendByte(x"55");
        sendByte(x"00");
        sendByte(x"03");
        sendByte(x"00");
        sendByte(x"00");
        sendByte(x"00");
        sendByte(x"02");
        endSpi;

        wait for 5 us;

        --------------------------------------------------------------------
        -- 2nd transaction: 0x76, 0xA5, 0x00, 0x05
        --------------------------------------------------------------------
        startSpi;
        sendByte(x"76");
        sendByte(x"A5");
        sendByte(x"00");
        sendByte(x"05");
        endSpi;

        wait for 100 us;

        --------------------------------------------------------------------
        -- 3rd transaction: 0x76, 0x55, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01
        --------------------------------------------------------------------
        startSpi;
        sendByte(x"76");
        sendByte(x"55");
        sendByte(x"00");
        sendByte(x"01");
        sendByte(x"00");
        sendByte(x"00");
        sendByte(x"00");
        sendByte(x"01");
        endSpi;

        wait for 10 us;

        -- NORT1 pulses
        sc_NORT1 <= '0';
        wait for clkPeriod200M;
        sc_NORT1 <= '1';
        wait for 100 us;
        sc_NORT1 <= '0';
        wait for clkPeriod200M;
        sc_NORT1 <= '1';
        wait for 100 us;
        sc_NORT1 <= '0';
        wait for clkPeriod200M;
        sc_NORT1 <= '1';

        wait for 100 us;

        --------------------------------------------------------------------
        -- 4th transaction: 0x76, 0xB5, 0x00, 0x00, 0x00, 0x00, 0x01, 0x05
        --------------------------------------------------------------------
        startSpi;
        sendByte(x"76");
        sendByte(x"B5");
        sendByte(x"00");
        sendByte(x"00");
        sendByte(x"00");
        sendByte(x"00");
        sendByte(x"01");
        sendByte(x"05");
        endSpi;

        wait for 600 us;

        --------------------------------------------------------------------
        -- 5th transaction: 0x76, 0xB5, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00
        --------------------------------------------------------------------
        startSpi;
        sendByte(x"76");
        sendByte(x"B5");
        sendByte(x"00");
        sendByte(x"00");
        sendByte(x"00");
        sendByte(x"00");
        sendByte(x"01");
        sendByte(x"00");
        endSpi;

        wait;
    end process;

end Behavioral;