----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: rateMetersCtrl
-- Create Date: 22.12.2025 17:15:46
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
-- Revision:
-- Revision 0.01 - File Created
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.utilsPkg.all;
use work.devicesPkg.all;
use work.registersPkg.all;
library xpm;
use xpm.vcomponents.all;

entity rateMetersCtrl is
generic(
    trgNum     : natural
);
port(
    clk        : in  std_logic;
    clkTmr     : in  std_logic;
    rst        : in  std_logic;
    trgIn      : in  std_logic_vector(trgNum-1 downto 0);
    devExec    : in  std_logic;
    devId      : in  devices_t;
    devRw      : in  std_logic;
    devBrst    : in  std_logic;
    devBrstWrt : in  std_logic;
    devBrstSnd : in  std_logic;
    devBrstRst : out std_logic;
    devAddr    : in  devAddr_t;
    devDataIn  : in  devData_t;
    devDataOut : out devData_t;
    devReady   : out std_logic;
    busy       : out std_logic
);
end rateMetersCtrl;

architecture Behavioral of rateMetersCtrl is

--------------------- registers definitions ------------------------

type addr is (regStatus,
              regTmrBase);

constant addrNum         : natural := addr'pos(addr'right)+1;

constant regModes        : regModeRec_t(0 to trgNum+addrNum-1) := (0      => ro,  -- regStatus
                                                                   1      => rw,  -- regTmrBase
                                                                   others => ro); -- counters

constant reg             : regsRec_t := initRegs(regModes);

constant regsNum         : integer := reg(reg'high).rAddr+1;

constant regSize         : integer := (trgNum+addrNum)*regsLen;

constant fifoWDWidth     : integer := trgNum*regsLen;
constant fifoRDWidth     : integer := addrNum*regsLen;
constant fifoDepth       : integer := fifoWDWidth/fifoRDWidth;

constant byteWriteWidthA : integer := regsLen;
constant writeDataWidthA : integer := regsLen;
constant readDataWidthA  : integer := regsLen;
constant byteWriteWidthB : integer := fifoRDWidth;
constant writeDataWidthB : integer := fifoRDWidth;
constant readDataWidthB  : integer := fifoRDWidth;
constant wenALen         : integer := integer(writeDataWidthA/byteWriteWidthA);
constant wenBLen         : integer := integer(fifoRDWidth/byteWriteWidthB);
--------------------------------------------------------------------

type stateRMCtrl_t is (idle,
                       waitRegWrite,
                       execute,
                       errAddr,
                       errReadOnly);

type stateFifoCtrl_t is (idle,
                         writeBport);

type rateMeters_t is array(0 to trgNum-1) of unsigned(regsLen-1 downto 0);

constant idleStatus     : std_logic_vector(regsLen-1 downto 0) := initSlv(regsLen, 13, 0, "00" & x"001", '0');
constant errAddrStatus  : std_logic_vector(regsLen-1 downto 0) := initSlv(regsLen, 13, 0, "11" & x"500", '0');
constant errROnlyStatus : std_logic_vector(regsLen-1 downto 0) := initSlv(regsLen, 13, 0, "11" & x"A00", '0');

signal state         : stateRMCtrl_t;

signal fcState       : stateFifoCtrl_t;

signal addrToRegA,
       lastAddr      : std_logic_vector(bitsNum(trgNum+addrNum)-1 downto 0);

signal dataFromRegA,
       dataToRegA    : std_logic_vector(devDataBytes*8-1 downto 0);

signal addrToRegB    : std_logic_vector(bitsNum(trgNum+addrNum)-1 downto 0);

signal addrUnsB      : unsigned(addrToRegB'left downto 0);

signal rmToBuf       : std_logic_vector(fifoWDWidth-1 downto 0);

signal dAddr         : integer;

signal trgMeters     : rateMeters_t;

signal cntTmrMax     : unsigned(devDataBytes*8-1 downto 0);

signal cntTmr        : unsigned(cntTmrMax'length downto 0); -- MSB = overflow

signal enRegA,
       enRegB,
       addrBEnd,
       fifoDValid,
       fifoDValidOld,
       fifoWAck,
       fifoRdEn,
       cntTmrSig,
       cntTmrSet     : std_logic;
signal fifoDOut      : std_logic_vector(fifoRDWidth-1 downto 0);
signal writeRegA     : std_logic_vector(wenALen-1 downto 0);
signal writeRegB     : std_logic_vector(wenBLen-1 downto 0);

begin

dAddr      <= devAddrToInt(devAddr);

cntTmrSig  <= cntTmr(cntTmr'left);

devDataOut <= slvToDevData(dataFromRegA);

addrBEnd   <= '1' when addrUnsB = fifoDepth else '0';

addrToRegB <= std_logic_vector(addrUnsB(addrToRegB'left downto 0));

rmToBufGen: for i in 0 to trgNum-1 generate
begin
    rmToBuf((i+1)*regsLen-1 downto i*regsLen) <= std_logic_vector(trgMeters(trgNum-1-i));
end generate;

rateMetersCtrlFSM: process(clk, rst, devExec)
begin
    if rising_edge(clk) then
        if rst = '1' then
            devReady    <= '0';
            busy        <= '0';
            devBrstRst  <= '0';
            lastAddr    <= (others => '0');
            cntTmrMax   <= (others => '0');
            cntTmrSet   <= '0';
            enRegA      <= '0';
            writeRegA   <= (others => '0');
            dataToRegA  <= (others => '0');

            state       <= idle;
        else
            case state is
                when idle =>
                    devReady   <= '0';
                    busy       <= '0';
                    cntTmrSet  <= '0';
                    enRegA     <= '0';
                    writeRegA  <= (others => '0');
                    addrToRegA <= devAddrToSlice(devAddr, bitsNum(trgNum+addrNum)-1, 0);
                    dataToRegA <= devDataToSlv(devDataIn);

                    state      <= idle;

                    if devExec = '1' and devId = rateMeters then
                        if dAddr > trgNum+addrNum-1 then
                            state    <= errAddr;
                        elsif devRw = devRead and devBrst = '0' then
                            lastAddr <= devAddrToSlice(devAddr, bitsNum(trgNum+addrNum)-1, 0);
                            busy     <= '1';

                            state    <= waitRegWrite;
                        elsif devRw = devWrite and reg(dAddr).rMode = ro then
                            state    <= errReadOnly;
                        elsif devRw = devWrite and reg(dAddr).rMode = rw then
                            lastAddr  <= devAddrToSlice(devAddr, bitsNum(trgNum+addrNum)-1, 0);
                            enRegA    <= '1';
                            writeRegA <= (others => '1');
                            busy      <= '1';

                            state     <= execute;
                        end if;
                    end if;

                when waitRegWrite =>
                    state <= waitRegWrite;

                    if fifoRdEn = '0' then
                        addrToRegA <= lastAddr;
                        enRegA     <= '1';
                        writeRegA  <= (others => '0');
                        devReady   <= '1';

                        state      <= idle;
                    end if;

                when execute =>
                    enRegA    <= '0';
                    writeRegA <= (others => '0');

                    state     <= idle;

                    if lastAddr = addrToSlice(addr'pos(regTmrBase), bitsNum(trgNum+addrNum)-1, 0) then
                        cntTmrMax <= unsigned(dataToRegA);
                        cntTmrSet <= '1';
                    end if;

                when errAddr =>
                    enRegA     <= '1';
                    writeRegA  <= (others => '1');
                    addrToRegA <= (others => '0');
                    dataToRegA <= errAddrStatus;
                    busy       <= '0';

                    state      <= idle;

                when errReadOnly =>
                    enRegA     <= '1';
                    writeRegA  <= (others => '1');
                    addrToRegA <= (others => '0');
                    dataToRegA <= errROnlyStatus;
                    busy       <= '0';

                    state      <= idle;

                when others =>
                    enRegA    <= '0';
                    writeRegA <= (others => '0');
                    devReady  <= '0';
                    busy      <= '0';

                    state     <= idle;
            end case;
        end if;
    end if;
end process;

trgCntGen: for i in 0 to trgNum-1 generate
begin
    trgICnt: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or fifoWAck = '1' then
                trgMeters(i) <= (others => '0');
            elsif trgIn(i) = '1' then
                trgMeters(i) <= trgMeters(i) + 1;
            end if;
        end if;
    end process;
end generate;

cntTmrGen: process(clkTmr, rst)
begin
    if rising_edge(clkTmr) then
        if rst = '1' or cntTmrSig = '1' or cntTmrSet = '1' then
            cntTmr <= resize(cntTmrMax-2, cntTmr'length);
        else
            cntTmr <= cntTmr - 1;
        end if;
    end if;
end process;

fifoBufCtrl: process(clk, rst)
begin
    if rising_edge(clk) then
        if rst = '1' then
            fifoRdEn      <= '0';
            enRegB        <= '0';
            fifoDValidOld <= '0';
            writeRegB     <= (others => '0');
            addrUnsB      <= to_unsigned(addrNum-1, addrUnsB'length);

            fcState       <= idle;
        else
            fifoDValidOld <= fifoDValid;

            case fcState is
                when idle =>
                    fifoRdEn   <= '0';
                    enRegB     <= '0';
                    writeRegB  <= (others => '0');
                    addrUnsB   <= to_unsigned(addrNum-1, addrUnsB'length);

                    fcState    <= idle;

                    if (fifoDValid and not fifoDValidOld) = '1' then
                        writeRegB <= (others => '1');
                        fifoRdEn  <= '1';
                        enRegB    <= '1';

                        fcState   <= writeBPort;
                    end if;

                when writeBport =>
                    writeRegB <= (others => '1');
                    addrUnsB  <= addrUnsB + 1;

                    fcState   <= writeBPort;

                    if addrBEnd = '1' then
                        fifoRdEn <= '0';
                        enRegB   <= '0';

                        fcState  <= idle;
                    end if;

                when others =>
                    fifoRdEn   <= '0';
                    enRegB     <= '0';
                    addrUnsB   <= to_unsigned(addrNum-1, addrUnsB'length);
                    writeRegB  <= (others => '0');

                    fcState    <= idle;
            end case;
        end if;
    end if;
end process;

buffRMInst: xpm_fifo_sync
generic map(
    FIFO_MEMORY_TYPE  => "block",
    FIFO_WRITE_DEPTH  => fifoDepth,
    READ_DATA_WIDTH   => fifoRDWidth,
    WRITE_DATA_WIDTH  => fifoWDWidth,
    FIFO_READ_LATENCY => 0,
    READ_MODE         => "fwft",
    USE_ADV_FEATURES  => "1010"
)
port map(
    rst           => rst,
    wr_clk        => clk,
    din           => rmToBuf,
    dout          => fifoDOut,
    data_valid    => fifoDValid,
    wr_ack        => fifoWAck,
    rd_en         => fifoRdEn,
    wr_en         => cntTmrSig,
    sleep         => '0',
    injectdbiterr => '0',
    injectsbiterr => '0'
);


regsRMInst: xpm_memory_tdpram
generic map(
    ADDR_WIDTH_A       => bitsNum(trgNum+addrNum),
    BYTE_WRITE_WIDTH_A => byteWriteWidthA,
    READ_DATA_WIDTH_A  => readDataWidthA,
    WRITE_DATA_WIDTH_A => writeDataWidthA,
    READ_LATENCY_A     => 1,
    WRITE_MODE_A       => "write_first",
    ADDR_WIDTH_B       => bitsNum(trgNum+addrNum),
    BYTE_WRITE_WIDTH_B => byteWriteWidthB,
    READ_DATA_WIDTH_B  => readDataWidthB,
    WRITE_DATA_WIDTH_B => writeDataWidthB,
    READ_LATENCY_B     => 1,
    WRITE_MODE_B       => "write_first",
    MEMORY_SIZE        => regSize,
    MEMORY_PRIMITIVE   => "block"
)
port map(
    clka               => clk,
    clkb               => clk,
    rsta               => rst,
    rstb               => rst,
    addra              => addrToRegA,
    dina               => dataToRegA,
    douta              => dataFromRegA,
    ena                => enRegA,
    wea                => writeRegA,
    addrb              => addrToRegB,
    dinb               => fifoDOut,
    doutb              => open,
    enb                => enRegB,
    web                => writeRegB,
    sleep              => '0',
    regcea             => '1',
    injectdbiterra     => '0',
    injectsbiterra     => '0',
    regceb             => '1',
    injectdbiterrb     => '0',
    injectsbiterrb     => '0'
);

end Behavioral;