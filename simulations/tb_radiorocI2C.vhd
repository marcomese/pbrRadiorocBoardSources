library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.devicesPkg.all;

entity tb_radiorocI2C is
generic(
    nCmd   : integer := 80;
    maxGap : integer := 6000;   -- clk cycles (5 ns) between commands
    seed0  : integer := 1
);
end tb_radiorocI2C;

architecture sim of tb_radiorocI2C is
    signal clk     : std_logic := '0';
    signal rst     : std_logic := '1';
    signal devExec : std_logic := '0';
    signal devRw   : std_logic := '0';
    signal devAddr : devAddr_t := (others => (others => '0'));
    signal devDIn  : devData_t := (others => (others => '0'));
    signal devDOut : devData_t;
    signal devReady, busy, enClk : std_logic;
    signal i2cEna, i2cRw, i2cBusy : std_logic;
    signal i2cAddr : std_logic_vector(6 downto 0);
    signal i2cDWr, i2cDRd : std_logic_vector(7 downto 0);
    signal scl, sda : std_logic;
    signal r0o, r1o, wrR0, wrR1, wrData : std_logic_vector(7 downto 0);
    signal wrEvt : std_logic := '0';
    signal resetn : std_logic;
    signal done : boolean := false;
    signal clkCnt : unsigned(7 downto 0) := to_unsigned(48, 8);
    signal clk2M  : std_logic := '0';
    signal clkPh  : std_logic := '0';
    signal mClk, mClkOld : std_logic := '0';
begin
    clk <= not clk after 2.5 ns when not done;
    resetn <= not rst;
    scl <= 'H';
    sda <= 'H';

    dut: entity work.radiorocInterface
    generic map(chipID => "0000")
    port map(clk => clk, rst => rst, devExec => devExec, devId => radioroc,
             devRw => devRw, devBrst => '0', devAddr => devAddr, devDataIn => devDIn,
             devDataOut => devDOut, devReady => devReady, busy => busy, i2cEnClk => enClk,
             i2cEna => i2cEna, i2cAddr => i2cAddr, i2cRw => i2cRw, i2cDataWr => i2cDWr,
             i2cBusy => i2cBusy, i2cDataRd => i2cDRd);

    mst: entity work.i2cMaster
    generic map(input_clk => 200_000_000, bus_clk => 100_000)
    port map(clk => clk, reset_n => resetn, ena => i2cEna, addr => i2cAddr, rw => i2cRw,
             data_wr => i2cDWr, busy => i2cBusy, data_rd => i2cDRd, ack_error => open,
             sda => sda, scl => scl, clk_sm => mClk);

    slv: entity work.radSlaveModel
    generic map(chipID => "0000")
    port map(scl => scl, sda => sda, r0o => r0o, r1o => r1o, wrEvt => wrEvt,
             wrR0 => wrR0, wrR1 => wrR1, wrData => wrData);

    -- clk_sm_i2c: from the I2C master (locked to its scl timing), only whole
    -- pulses let through while enabled
    gateP: process(clk)
    begin
        if rising_edge(clk) then
            mClkOld <= mClk;
            if rst = '1' then
                clk2M <= '0';
            elsif mClk = '1' and mClkOld = '0' then
                clk2M <= enClk;
            elsif mClk = '0' and mClkOld = '1' then
                clk2M <= '0';
            end if;
        end if;
    end process;

    -- phase of clk_sm with respect to SCL: time from the last clk_sm rising
    -- edge to each SCL rising edge (mod 500 ns), first SCL edge of each command
    phP: process
        variable tClk : time := 0 ns;
        variable n : integer := 0;
    begin
        wait until rising_edge(enClk);
        wait until rising_edge(clk2M);
        tClk := now;
        wait until rising_edge(scl);
        report "PHASE " & integer'image(((now - tClk) / 1 ns) mod 500) & " ns, enClk->SCL " severity note;
    end process;


    stim: process
        variable s1, s2 : positive;
        variable u : real;
        variable add, sub, dat, gap, nErr, nW, nR : integer := 0;
        type m_t is array(0 to 65535) of integer;
        variable model : m_t := (others => 0);
        variable evOld : std_logic;
    begin
        s1 := seed0; s2 := seed0 + 7;
        wait for 100 ns;
        rst <= '0';
        wait for 20 us;
        for k in 0 to nCmd-1 loop
            uniform(s1, s2, u); add := integer(floor(u*68.0));
            uniform(s1, s2, u); sub := integer(floor(u*16.0));
            uniform(s1, s2, u); dat := integer(floor(u*256.0));
            uniform(s1, s2, u);
            if u < 0.6 then devRw <= '0'; else devRw <= '1'; end if;
            devAddr(1) <= std_logic_vector(to_unsigned(add, 8));
            devAddr(0) <= std_logic_vector(to_unsigned(sub, 8));
            devDIn(0)  <= std_logic_vector(to_unsigned(dat, 8));
            evOld := wrEvt;
            wait until rising_edge(clk);
            devExec <= '1';
            wait until rising_edge(clk);
            devExec <= '0';
            wait until rising_edge(clk) and devReady = '1';
            if devRw = '0' then
                nW := nW + 1;
                -- the slave gets the data byte before the stop
                if wrEvt = evOld then
                    report "cmd " & integer'image(k) & " write " & integer'image(add) & "," & integer'image(sub) & ": no data write seen" severity error;
                    nErr := nErr + 1;
                elsif to_integer(unsigned(wrR1)) /= add or to_integer(unsigned(wrR0)) /= sub or to_integer(unsigned(wrData)) /= dat then
                    report "cmd " & integer'image(k) & " write " & integer'image(add) & "," & integer'image(sub) & "=" & integer'image(dat) &
                           " -> slave wrote " & integer'image(to_integer(unsigned(wrR1))) & "," & integer'image(to_integer(unsigned(wrR0))) & "=" & integer'image(to_integer(unsigned(wrData))) severity error;
                    nErr := nErr + 1;
                end if;
                model(add*256+sub) := dat;
            else
                nR := nR + 1;
                if to_integer(unsigned(devDOut(0))) /= model(add*256+sub) then
                    report "cmd " & integer'image(k) & " read " & integer'image(add) & "," & integer'image(sub) & " got " &
                           integer'image(to_integer(unsigned(devDOut(0)))) & " expected " & integer'image(model(add*256+sub)) severity error;
                    nErr := nErr + 1;
                end if;
            end if;
            uniform(s1, s2, u); gap := integer(floor(u*real(maxGap)));
            for g in 1 to gap loop wait until rising_edge(clk); end loop;
        end loop;
        report "DONE: " & integer'image(nW) & " writes, " & integer'image(nR) & " reads, " & integer'image(nErr) & " errors" severity note;
        done <= true;
        wait;
    end process;
end sim;
