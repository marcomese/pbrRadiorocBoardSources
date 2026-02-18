----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: dataAcqCtrl
-- Create Date: 08.07.2025 15:47:20
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

entity dataAcqCtrl is
port(
    clk        : in  std_logic;
    rst        : in  std_logic;
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
    busy       : out std_logic;
    resetAcq   : out std_logic;
    startAcq   : out std_logic;
    endAcq     : in  std_logic;
    endMAcq    : out std_logic;
    rdValid    : in  std_logic;
    rdAcq      : out std_logic;
    rdDataCnt  : in  std_logic_vector(15 downto 0);
    emptyAcq   : in  std_logic;
    nbAcq      : out std_logic_vector(7 downto 0);
    selAdc     : out std_logic_vector(63 downto 0);
    doutAcq    : in  std_logic_vector(7 downto 0)
);
end dataAcqCtrl;

architecture Behavioral of dataAcqCtrl is

--------------------- registers definitions ------------------------

type addr is (regStatus,
              regAcqEn,
              regSwTrg,
              regFifoCnt,
              regAcqNb,
              regSelAdcMSB,
              regSelAdcLSB);

constant addrNum         : natural := addr'pos(addr'right)+1;

constant regModes        : regModeRec_t(0 to addrNum-1) := (0      => ro,  -- regStatus
                                                            1      => rw,  -- regAcqEn
                                                            2      => rw,  -- regSwTrg
                                                            3      => ro,  -- regFifoCnt,
                                                            4      => rw,  -- regAcqNb
                                                            5      => rw,  -- regSelAdcMSB
                                                            6      => rw,  -- regSelAdcLSB
                                                            others => ro);

constant reg             : regsRec_t := initRegs(regModes);

constant regSize         : integer   := addrNum*regsLen;

constant addrWidthA      : integer   := bitsNum(addrNum);
constant writeDataWidthA : integer   := regsLen;
constant byteWriteWidthA : integer   := regsLen;
constant readDataWidthA  : integer   := regsLen;

constant addrWidthB      : integer   := bitsNum(addrNum);
constant writeDataWidthB : integer   := regsLen;
constant byteWriteWidthB : integer   := regsLen;
constant readDataWidthB  : integer   := regsLen;

constant wenALen         : integer   := integer(writeDataWidthA/byteWriteWidthA);
constant wenBLen         : integer   := integer(writeDataWidthB/byteWriteWidthB);

--------------------------------------------------------------------

type state_t is (idle,
                 execute,
                 sendStartAcq,
                 readFifo,
                 waitBrstSent,
                 sendData,
                 acqEnd,
                 errAddr,
                 errReadOnly,
                 errFifoEmpty);

constant idleStatus         : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"001", '0');
constant errAddrStatus      : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"500", '0');
constant errROnlyStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"A00", '0');
constant errFifoEmptyStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"B00", '0');

signal state         : state_t;

signal dataIn        : devData_t;

signal dAddr         : integer;

signal addrToRegA,
       addrToRegB,
       lastAddr      : std_logic_vector(bitsNum(addrNum)-1 downto 0);

signal enRegA,
       enRegB,
       swTrg,
       rstAcqSig,
       strtAcqSig,
       rdAcqSig      : std_logic;

signal nbAcqSig      : std_logic_vector(7 downto 0);

signal dataFromRegA,
       dataToRegA,
       dataFromRegB,
       dataToRegB    : std_logic_vector(devDataBytes*8-1 downto 0);

signal writeRegA     : std_logic_vector(wenALen-1 downto 0);
signal writeRegB     : std_logic_vector(wenBLen-1 downto 0);

begin

dAddr      <= devAddrToInt(devAddr);
devDataOut <= slvToDevData(dataFromRegA);
nbAcq      <= nbAcqSig;
resetAcq   <= rstAcqSig;
startAcq   <= strtAcqSig;
rdAcq      <= rdAcqSig and not devBrstSnd;

dataAcqCtrlFSM: process(clk, rst, devExec)
begin
    if rising_edge(clk) then
        if rst = '1' then
            devReady   <= '0';
            busy       <= '0';
            rstAcqSig  <= '1';
            strtAcqSig <= '0';
            rdAcqSig   <= '0';
            nbAcqSig   <= (others => '0');
            devBrstRst <= '0';
            swTrg      <= '0';
            enRegA     <= '0';
            writeRegA  <= (others => '0');
            dataToRegA <= (others => '0');
            enRegB     <= '0';
            writeRegB  <= (others => '0');
            dataToRegB <= (others => '0');

            state      <= idle;
        else
            enRegB     <= '1';
            writeRegB  <= (others => '1');
            addrToRegB <= std_logic_vector(to_unsigned(addr'pos(regFifoCnt), regsLen));
            dataToRegB <= std_logic_vector(resize(unsigned(rdDataCnt), regsLen));

            selAdc <= readReg(reg, rData, addr'pos(regSelAdcMSB)) &
                      readReg(reg, rData, addr'pos(regSelAdcLSB)); 

            case state is
                when idle =>
                    devReady   <= '0';
                    rstAcqSig  <= '0';
                    strtAcqSig <= '0';
                    swTrg      <= '0';
                    busy       <= '0';
                    enRegA     <= '0';
                    writeRegA  <= (others => '0');
                    addrToRegA <= devAddrToSlice(devAddr, bitsNum(addrNum)-1, 0);
                    dataToRegA <= devDataToSlv(devDataIn);

                    state      <= idle;

                    if devExec = '1' and devId = acqSystem then
                        if dAddr > addr'pos(addr'high) then
                            state    <= errAddr;
                        elsif devRw = devRead and devBrst = '0' then
                            devReady <= '1';
                            busy     <= '1';

                            state    <= idle;
                        elsif devRw = devRead and devBrst = '1' and emptyAcq = '0' then
                            rdAcqSig <= '1';

                            state    <= readFifo;
                        elsif devRw = devRead and devBrst = '1' and emptyAcq = '1' then
                            devBrstRst <= '1';

                            state      <= errFifoEmpty;
                        elsif devRw = devWrite and reg(dAddr).rMode = ro then
                            state <= errReadOnly;
                        elsif devRw = devWrite and reg(dAddr).rMode = rw then
                            lastAddr  <= devAddrToSlice(devAddr, bitsNum(addrNum)-1, 0);
                            enRegA    <= '1';
                            writeRegA <= (others => '1');
                            busy      <= '1';

                            state     <= execute;
                        end if;
                    end if;

                when execute =>
                    state <= idle;

                    if isSet(reg, rData, addr'pos(regAcqEn)) then
                        rstAcqSig <= '1';

                        state     <= sendStartAcq;
                    elsif isSet(reg, rData, addr'pos(regSwTrg)) then
                        clearReg(reg, rData, addr'pos(regSwTrg));
                        swTrg <= '1';
                    elsif lastAddr = addrToSlv(addr'pos(regAcqNb)) then
                        nbAcqSig <= readReg(reg, rData, addr'pos(regAcqNb))(7 downto 0);
                    end if;

                when sendStartAcq =>
                    rstAcqSig  <= '0';
                    strtAcqSig <= '1';

                    state      <= idle;

                when readFifo =>
                    devReady      <= rdValid;
                    rdAcqSig      <= devBrstWrt;

                    state         <= readFifo;

                    if devBrstSnd = '1' then
                        rdAcqSig <= '0';

                        state    <= waitBrstSent; 
                    elsif devBrst = '0' and devBrstWrt = '1' then
                        rdAcqSig <= '0';

                        state    <= acqEnd;
                    end if;

                when waitBrstSent =>
                    state <= waitBrstSent;

                    if devBrstSnd = '0' then
                        rdAcqSig <= '1';

                        state    <= readFifo;
                    elsif emptyAcq = '1' then
                        devBrstRst <= '1';

                        state      <= errFifoEmpty;
                    end if;

                when acqEnd =>
                    busy      <= '0';
                    rstAcqSig <= '0';
                    devReady  <= '0';

                    state     <= idle;                    

                    if emptyAcq = '1' then
                        rstAcqSig <= '1';
                    end if;

                when errAddr =>
                    writeRegB  <= (others => '1');
                    addrToRegB <= (others => '0');
                    dataToRegB <= errAddrStatus;
                    busy       <= '0';

                    state      <= idle;

                when errReadOnly =>
                    writeRegB  <= (others => '1');
                    addrToRegB <= (others => '0');
                    dataToRegB <= errROnlyStatus;
                    busy       <= '0';

                    state      <= idle;

                when errFifoEmpty =>
                    writeRegB  <= (others => '1');
                    addrToRegB <= (others => '0');
                    dataToRegB <= errFifoEmptyStatus;
                    devBrstRst <= '0';
                    busy       <= '0';

                    state      <= idle;                    

                when others =>
                    devReady <= '0';
                    busy     <= '0';

                    state    <= idle;
            end case;
        end if;
    end if;
end process;

regsRMInst: xpm_memory_tdpram
generic map(
    ADDR_WIDTH_A       => addrWidthA,
    BYTE_WRITE_WIDTH_A => byteWriteWidthA,
    READ_DATA_WIDTH_A  => readDataWidthA,
    WRITE_DATA_WIDTH_A => writeDataWidthA,
    READ_LATENCY_A     => 1,
    WRITE_MODE_A       => "write_first",
    ADDR_WIDTH_B       => addrWidthB,
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
    dinb               => dataToRegB,
    doutb              => dataFromRegB,
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