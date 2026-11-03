-- behavioral I2C slave of the RADIOROC slow control (ideal timing):
-- 7-bit address = chipID & R, R0 = address byte 0, R1 = address byte 1,
-- R2 = data at (R1,R0), R3 = data with auto-increment of (R1 & R0)
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

entity radSlaveModel is
generic(
    chipID : std_logic_vector(3 downto 0) := "0000"
);
port(
    scl : inout std_logic;
    sda : inout std_logic;
    r0o : out std_logic_vector(7 downto 0);
    r1o : out std_logic_vector(7 downto 0);
    wrEvt : out std_logic;   -- toggles at every data write (R2/R3)
    wrR0, wrR1 : out std_logic_vector(7 downto 0);
    wrData : out std_logic_vector(7 downto 0)
);
end radSlaveModel;

architecture beh of radSlaveModel is
    type mem_t is array(0 to 65535) of std_logic_vector(7 downto 0);
    shared variable mem : mem_t := (others => x"00");
    signal sdaDrv : std_logic := '0';
begin
    sda <= '0' when sdaDrv = '1' else 'Z';
    scl <= 'Z';

    proc: process
        variable sh   : std_logic_vector(7 downto 0);
        variable r    : integer;
        variable rwb  : std_logic;
        variable r0, r1 : unsigned(7 downto 0) := (others => '0');
        variable a    : integer;
        variable stopSeen, startSeen : boolean;
        variable ev   : std_logic := '0';
        variable l    : line;
    begin
        -- wait for START: sda falling while scl high
        wait until falling_edge(sda) and to_X01(scl) = '1';
        restart: loop
            -- address byte
            for i in 7 downto 0 loop
                wait until rising_edge(scl);
                sh(i) := to_X01(sda);
            end loop;
            r   := to_integer(unsigned(sh(3 downto 1)));
            rwb := sh(0);
            wait until falling_edge(scl);
            if sh(7 downto 4) /= chipID then
                -- not for us: wait next start
                wait until falling_edge(sda) and to_X01(scl) = '1';
                next restart;
            end if;
            sdaDrv <= '1';
            wait until falling_edge(scl);
            sdaDrv <= '0';
            if rwb = '0' then
                -- data bytes until STOP or repeated START
                loop
                    stopSeen := false; startSeen := false;
                    -- first bit: watch for stop/start while scl high
                    wait until rising_edge(scl);
                    sh(7) := to_X01(sda);
                    -- detect stop/start during this scl high
                    loop
                        wait on scl, sda;
                        if to_X01(scl) = '0' then exit; end if;
                        if sda'event and to_X01(sda) = '1' then stopSeen := true; exit; end if;
                        if sda'event and to_X01(sda) = '0' then startSeen := true; exit; end if;
                    end loop;
                    if stopSeen then
                        wait until falling_edge(sda) and to_X01(scl) = '1';
                        next restart;
                    end if;
                    if startSeen then next restart; end if;
                    for i in 6 downto 0 loop
                        wait until rising_edge(scl);
                        sh(i) := to_X01(sda);
                    end loop;
                    wait until falling_edge(scl);
                    case r is
                        when 0 => r0 := unsigned(sh);
                        when 1 => r1 := unsigned(sh);
                        when 2 | 3 =>
                            a := to_integer(r1 & r0);
                            mem(a) := sh;
                            ev := not ev;
                            wrR0 <= std_logic_vector(r0); wrR1 <= std_logic_vector(r1); wrData <= sh; wrEvt <= ev;
                            if r = 3 then
                                a := (a + 1) mod 65536;
                                r1 := to_unsigned(a / 256, 8);
                                r0 := to_unsigned(a mod 256, 8);
                            end if;
                        when others => null;
                    end case;
                    r0o <= std_logic_vector(r0); r1o <= std_logic_vector(r1);
                    sdaDrv <= '1';
                    wait until falling_edge(scl);
                    sdaDrv <= '0';
                end loop;
            else
                -- read: send mem(R1,R0) for R2 (one byte, then master NACK)
                a := to_integer(r1 & r0);
                sh := mem(a);
                for i in 7 downto 0 loop
                    sdaDrv <= not sh(i);
                    wait until falling_edge(scl);
                end loop;
                sdaDrv <= '0';
                wait until rising_edge(scl);   -- master ack/nack
                wait until falling_edge(scl);
                if r = 3 then
                    a := (a + 1) mod 65536;
                    r1 := to_unsigned(a / 256, 8);
                    r0 := to_unsigned(a mod 256, 8);
                end if;
                wait until falling_edge(sda) and to_X01(scl) = '1';
                next restart;
            end if;
        end loop;
    end process;
end beh;
