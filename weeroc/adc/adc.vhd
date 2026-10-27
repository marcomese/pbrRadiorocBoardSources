----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: adc
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- RADIOROC2 readout, one event per trigger:
--   1. trigger: rising edge of the T1 output of channel trgCh, or software
--      strobe, accepted in idle while acqEn = '1' and the FIFO has room for
--      a whole event
--   2. header and timestamps written to the FIFO; RSTN_READ low (>= 20 ns)
--   3. external hold asserted holdDelay cycles after the trigger (minimum
--      HOLD_MIN), first ck_read HOLD_TO_READ cycles later
--   4. 66 conversions (the first two are discarded, the ADC returns the
--      previous conversion): read register advanced by ck_read, AMUX sampled
--      by the LTC2311 (n_cnv, 16 adc_sck), HG/LG packed in one 32-bit word
--   5. CRC and footer
--   6. RESET_N pulse (peak detectors and delay cell), then back to idle
--
-- Single clock domain (clk_200M). adc_sck = clk_200M / 2.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ucrc_pkg.all;
use work.utilsPkg.all;

library xpm;
use xpm.vcomponents.all;

library xil_defaultlib;

entity adc is
generic(
    dataHeader        : std_logic_vector(31 downto 0);
    dataFooter        : std_logic_vector(31 downto 0)
);
port(
    rst               : in  std_logic;
    clk_200M          : in  std_logic;
    acqEn             : in  std_logic;
    sdo_hg            : in  std_logic;
    sdo_lg            : in  std_logic;
    id                : in  std_logic_vector(3 downto 0);
    tStamp            : in  std_logic_vector(63 downto 0);
    t                 : in  std_logic_vector(63 downto 0);
    trgCh             : in  std_logic_vector(5 downto 0);
    holdDelay         : in  std_logic_vector(11 downto 0);
    swTrg             : in  std_logic;
    asicRst           : in  std_logic;
    rd_en             : in  std_logic;
    dout              : out std_logic_vector(7 downto 0);
    reset_n           : out std_logic;
    rstb_rd           : out std_logic;
    ck_read           : out std_logic;
    n_cnv             : out std_logic;
    adc_sck           : out std_logic;
    empty_acq         : out std_logic;
    rd_data_count_acq : out std_logic_vector(16 downto 0);
    hold_ext          : out std_logic;
    evtTrigger        : out std_logic;
    rdValid           : out std_logic
);
end adc;

architecture Behavioral of adc is

    type state_t is (init,
                     idle,
                     wrHeader,
                     wrTSCoarse,
                     wrTSFine,
                     wait_hold,
                     hold_on,
                     first_rd_high,
                     first_rd_low,
                     nxt,
                     read_asic,
                     start_conv,
                     end_conv,
                     read_adc,
                     end_read_adc,
                     write_fifo,
                     wrCRC32,
                     wrFooter,
                     finish,
                     rst_asic);

    type dinSel_t is (HEADER,
                      TSCOARSE,
                      TSFINE,
                      ACQDATA,
                      CRC32,
                      FOOTER);

    constant ASIC_RST_CYCLES : natural := 8;    -- RESET_N on command: 40 ns

    -- state durations in clk_200M cycles
    constant HOLD_TO_READ    : natural := 2;    -- hold / RSTN_READ release to the first ck_read
    constant CK_READ_HIGH    : natural := 20;   -- ck_read high (100 ns)
    constant CK_READ_LOW     : natural := 20;   -- ck_read low after the first pulse
    constant CONV_CYCLES     : natural := 26;   -- n_cnv high (LTC2311 conversion)
    constant HOLD_MIN        : natural := 5;    -- trigger + header + timestamps + 1
    constant RST_CYCLES      : natural := 8;    -- RESET_N after every event (>= 20 ns)

    constant FIFO_BYTES      : natural := 65536;
    constant EVT_BYTES       : natural := 276;  -- 69 words

    constant ADC_DISCARD     : natural := 2;    -- the ADC returns the previous conversion
    constant N_CONV          : natural := 64 + ADC_DISCARD;

    function byteSwap(v : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return v(7 downto 0) & v(15 downto 8) & v(23 downto 16) & v(31 downto 24);
    end function;

    signal current_state, next_state : state_t;

    -- waitCounter value loaded when entering a state (duration - 1); states
    -- not listed last 1 cycle. holdLoad is precomputed from holdDelay
    function stateLoad(st : state_t; holdLoad : natural) return natural is
    begin
        case st is
            when wait_hold =>
                return holdLoad;
            when hold_on =>
                return HOLD_TO_READ - 1;
            when first_rd_high | read_asic =>
                return CK_READ_HIGH - 1;
            when first_rd_low =>
                return CK_READ_LOW - 1;
            when start_conv =>
                return CONV_CYCLES - 1;
            when rst_asic =>
                return RST_CYCLES - 1;
            when others =>
                return 0;
        end case;
    end function;

    signal waitCounter : natural range 0 to 4095;
    signal waitDone    : std_logic;
    signal convCounter : natural range 0 to N_CONV;
    signal convDone    : std_logic;   -- all N_CONV conversions done
    signal convDiscard : std_logic;   -- current result to be discarded
    signal ckReadEn    : std_logic;   -- read register advanced before this conversion
    signal sck_cnt     : unsigned(4 downto 0);
    signal holdLoad    : natural range 0 to 4095;

    signal dinSel     : dinSel_t;

    signal hit                    : std_logic;
    signal trgAccept              : std_logic;
    signal fifoRoom               : std_logic;
    signal rdDataCnt              : std_logic_vector(16 downto 0);
    signal wr_en                  : std_logic;
    signal wenSig                 : std_logic;
    signal crcEn                  : std_logic;
    signal crcClkEn               : std_logic;

    signal sdo_hg_des, sdo_lg_des : std_logic_vector(15 downto 0);
    signal dinFifo                : std_logic_vector(31 downto 0);

    signal en_adc_sck             : std_logic;
    signal adc_sck_int            : std_logic;
    signal shift_en               : std_logic;
    signal desClr                 : std_logic;
    signal sck_cnt_en             : std_logic;
    signal rstb_rd_s              : std_logic;
    signal rst_n                  : std_logic;

    signal hitFF                  : std_logic;
    signal trgEdge                : std_logic;
    signal holdext                : std_logic;

    signal asicRstCnt             : natural range 0 to ASIC_RST_CYCLES;
    signal asicRstN               : std_logic;
    signal rdValidSig             : std_logic;
    signal locRst                 : std_logic;
    signal crcRst                 : std_logic;

    signal dHeader,
           crcVal,
           crcXorRev              : std_logic_vector(31 downto 0);

begin

    evtTrigger <= trgAccept;
    rdValid    <= rdValidSig;

    dHeader    <= dataHeader(31 downto 4) & id;

    locRst     <= rst;

    ---------------------------------------------------------------------------
    -- trigger
    ---------------------------------------------------------------------------
    -- T1 outputs are active low; the 64:1 mux is registered
    trgFFProc : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if locRst = '1' then
                hit   <= '0';
                hitFF <= '0';
            else
                hit   <= not t(to_integer(unsigned(trgCh)));
                hitFF <= hit;
            end if;
        end if;
    end process;

    -- edge of the discriminator output: a T1 still high when the FSM returns
    -- to idle does not trigger
    trgEdge <= hit and not hitFF;

    -- keep room for a whole event (plus one in flight)
    fifoRoomProc : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if unsigned(rdDataCnt) <= FIFO_BYTES - 2*EVT_BYTES then
                fifoRoom <= '1';
            else
                fifoRoom <= '0';
            end if;
        end if;
    end process;

    trgAccept <= (trgEdge or swTrg) and acqEn and fifoRoom when current_state = idle else '0';

    ---------------------------------------------------------------------------
    -- RADIOROC control
    ---------------------------------------------------------------------------
    hold_ext   <= holdext;
    rstb_rd    <= rstb_rd_s;
    reset_n    <= rst_n and asicRstN;

    -- wait_hold lasts holdDelay - 4 cycles (trigger, header and timestamps
    -- take the other 4), so that hold_ext rises holdDelay cycles after the
    -- trigger
    holdLoadProc : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if unsigned(holdDelay) > HOLD_MIN then
                holdLoad <= to_integer(unsigned(holdDelay)) - 5;
            else
                holdLoad <= HOLD_MIN - 5;
            end if;
        end if;
    end process;

    -- RESET_N on command (asicRst strobe), ASIC_RST_CYCLES long
    asicRstProc : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if locRst = '1' then
                asicRstCnt <= 0;
                asicRstN   <= '1';
            elsif asicRst = '1' then
                asicRstCnt <= ASIC_RST_CYCLES;
                asicRstN   <= '0';
            elsif asicRstCnt > 1 then
                asicRstCnt <= asicRstCnt - 1;
                asicRstN   <= '0';
            else
                asicRstCnt <= 0;
                asicRstN   <= '1';
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- LTC2311 serial readout (16 adc_sck per conversion)
    ---------------------------------------------------------------------------
    sckGen : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if locRst = '1' or en_adc_sck = '0' or sck_cnt = 16 then
                adc_sck_int <= '1';
                sck_cnt_en  <= '0';
            else
                adc_sck_int <= not adc_sck_int;
                sck_cnt_en  <= en_adc_sck and adc_sck_int;
            end if;
        end if;
    end process;

    adc_sck <= adc_sck_int;

    sckCntProc : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if locRst = '1' or current_state = end_conv then
                sck_cnt <= (others => '0');
            elsif sck_cnt_en = '1' then
                sck_cnt <= sck_cnt + 1;
            end if;
        end if;
    end process;

    shiftEnProc : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if locRst = '1' then
                shift_en <= '0';
            elsif sck_cnt < 15 then
                shift_en <= en_adc_sck and adc_sck_int;
            end if;
        end if;
    end process;

    deserProc : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if locRst = '1' or desClr = '1' then
                sdo_hg_des <= (others => '0');
                sdo_lg_des <= (others => '0');
            elsif shift_en = '1' then
                sdo_hg_des <= sdo_hg_des(14 downto 0) & sdo_hg;
                sdo_lg_des <= sdo_lg_des(14 downto 0) & sdo_lg;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- event FIFO and CRC
    ---------------------------------------------------------------------------
    -- the 32-bit words are written byte-swapped: xpm_fifo_sync reads the
    -- least significant byte first, so the file is big-endian
    dinMux : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if locRst = '1' then
                wenSig   <= '0';
                crcClkEn <= '0';
                dinFifo  <= (others => '0');
            else
                wenSig   <= wr_en;
                crcClkEn <= wr_en and crcEn;

                case dinSel is
                    when HEADER =>
                        dinFifo <= byteSwap(dHeader);
                    when TSCOARSE =>
                        dinFifo <= byteSwap(tStamp(63 downto 32));
                    when TSFINE =>
                        dinFifo <= byteSwap(tStamp(31 downto 0));
                    when CRC32 =>
                        dinFifo <= byteSwap(crcXorRev);
                    when FOOTER =>
                        dinFifo <= byteSwap(dataFooter);
                    when others =>
                        dinFifo <= byteSwap(sdo_hg_des & sdo_lg_des);
                end case;
            end if;
        end if;
    end process;

    dataFifo : xpm_fifo_sync
    generic map(
        FIFO_WRITE_DEPTH    => 16384,
        READ_DATA_WIDTH     => 8,
        WRITE_DATA_WIDTH    => 32,
        RD_DATA_COUNT_WIDTH => 17,
        READ_MODE           => "std",
        USE_ADV_FEATURES    => "1400",
        FIFO_MEMORY_TYPE    => "block"
    )
    port map(
        wr_clk        => clk_200M,
        rst           => locRst,
        din           => dinFifo,
        wr_en         => wenSig,
        dout          => dout,
        rd_en         => rd_en,
        data_valid    => rdValidSig,
        empty         => empty_acq,
        full          => open,
        rd_data_count => rdDataCnt,
        sleep         => '0',
        injectdbiterr => '0',
        injectsbiterr => '0'
    );

    rd_data_count_acq <= rdDataCnt;

    crcXorRev <= reverse(crcVal xor x"FFFFFFFF");

    ucrcInst : ucrc_par
    generic map(
        POLYNOMIAL => x"04C11DB7",
        INIT_VALUE => x"FFFFFFFF",
        DATA_WIDTH => 32,
        SYNC_RESET => 1
    )
    port map(
        clk_i   => clk_200M,
        rst_i   => crcRst,
        clken_i => crcClkEn,
        data_i  => dinFifo,
        match_o => open,
        crc_o   => crcVal
    );

    ---------------------------------------------------------------------------
    -- readout FSM
    ---------------------------------------------------------------------------
    fsmSeq : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if locRst = '1' then
                current_state <= init;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;

    -- loaded with the duration of the next state on every state change
    waitCounterProc : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if locRst = '1' then
                waitCounter <= 0;
            elsif next_state /= current_state then
                waitCounter <= stateLoad(next_state, holdLoad);
            elsif waitCounter > 0 then
                waitCounter <= waitCounter - 1;
            end if;
        end if;
    end process;

    waitDone <= '1' when waitCounter = 0 else '0';

    -- conversions done in the current event
    convCounterProc : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if locRst = '1' or current_state = idle then
                convCounter <= 0;
            elsif current_state = end_conv then
                convCounter <= convCounter + 1;
            end if;
        end if;
    end process;

    -- decoded one cycle after convCounter changes (at end_conv): they are used
    -- in end_read_adc, nxt and read_asic, many cycles later
    convFlagsProc : process(clk_200M)
    begin
        if rising_edge(clk_200M) then
            if convCounter = N_CONV then
                convDone <= '1';
            else
                convDone <= '0';
            end if;

            if convCounter <= ADC_DISCARD then
                convDiscard <= '1';
            else
                convDiscard <= '0';
            end if;

            if convCounter >= ADC_DISCARD then
                ckReadEn <= '1';
            else
                ckReadEn <= '0';
            end if;
        end if;
    end process;

    fsmComb : process(current_state, trgAccept, waitDone, convDone, convDiscard, sck_cnt)
    begin
        case current_state is
            when init =>
                next_state <= rst_asic;

            when idle =>
                if trgAccept = '1' then
                    next_state <= wrHeader;
                else
                    next_state <= idle;
                end if;

            when wrHeader =>
                next_state <= wrTSCoarse;

            when wrTSCoarse =>
                next_state <= wrTSFine;

            when wrTSFine =>
                next_state <= wait_hold;

            when wait_hold =>
                if waitDone = '1' then
                    next_state <= hold_on;
                else
                    next_state <= wait_hold;
                end if;

            -- hold asserted, read register out of reset
            when hold_on =>
                if waitDone = '1' then
                    next_state <= first_rd_high;
                else
                    next_state <= hold_on;
                end if;

            -- first ck_read: the read register points to channel 0
            when first_rd_high =>
                if waitDone = '1' then
                    next_state <= first_rd_low;
                else
                    next_state <= first_rd_high;
                end if;

            when first_rd_low =>
                if waitDone = '1' then
                    next_state <= nxt;
                else
                    next_state <= first_rd_low;
                end if;

            -- read_asic advances the read register, except before the first
            -- ADC_DISCARD conversions (see fsmOut)
            when nxt =>
                if convDone = '1' then
                    next_state <= wrCRC32;
                else
                    next_state <= read_asic;
                end if;

            when read_asic =>
                if waitDone = '1' then
                    next_state <= start_conv;
                else
                    next_state <= read_asic;
                end if;

            when start_conv =>
                if waitDone = '1' then
                    next_state <= end_conv;
                else
                    next_state <= start_conv;
                end if;

            when end_conv =>
                next_state <= read_adc;

            when read_adc =>
                if sck_cnt = 16 then
                    next_state <= end_read_adc;
                else
                    next_state <= read_adc;
                end if;

            -- the first two results belong to the previous conversion
            when end_read_adc =>
                if convDiscard = '1' then
                    next_state <= nxt;
                else
                    next_state <= write_fifo;
                end if;

            when write_fifo =>
                next_state <= nxt;

            when wrCRC32 =>
                next_state <= wrFooter;

            when wrFooter =>
                next_state <= finish;

            when finish =>
                next_state <= rst_asic;

            when rst_asic =>
                if waitDone = '1' then
                    next_state <= idle;
                else
                    next_state <= rst_asic;
                end if;

            when others =>
                next_state <= idle;
        end case;
    end process;

    fsmOut : process(current_state, ckReadEn)
    begin
        rstb_rd_s  <= '1';
        desClr     <= '0';
        holdext    <= '1';
        ck_read    <= '0';
        n_cnv      <= '0';
        en_adc_sck <= '0';
        wr_en      <= '0';
        crcEn      <= '1';
        crcRst     <= '0';
        dinSel     <= ACQDATA;
        rst_n      <= '1';

        case current_state is
            when init =>
                crcRst    <= '1';
                rstb_rd_s <= '0';
                holdext   <= '0';

            when idle =>
                holdext <= '0';

            -- header/timestamps: hold not yet asserted, read register reset
            when wrHeader =>
                rstb_rd_s <= '0';
                holdext   <= '0';
                wr_en     <= '1';
                dinSel    <= HEADER;

            when wrTSCoarse =>
                rstb_rd_s <= '0';
                holdext   <= '0';
                wr_en     <= '1';
                dinSel    <= TSCOARSE;

            when wrTSFine =>
                rstb_rd_s <= '0';
                holdext   <= '0';
                wr_en     <= '1';
                dinSel    <= TSFINE;

            when wait_hold =>
                rstb_rd_s <= '0';
                holdext   <= '0';

            when first_rd_high =>
                ck_read <= '1';

            when nxt =>
                desClr <= '1';

            when read_asic =>
                if ckReadEn = '1' then
                    ck_read <= '1';
                end if;

            when start_conv =>
                n_cnv <= '1';

            when read_adc =>
                en_adc_sck <= '1';

            when write_fifo =>
                wr_en <= '1';

            when wrCRC32 =>
                crcEn  <= '0';
                dinSel <= CRC32;
                wr_en  <= '1';

            when wrFooter =>
                crcEn  <= '0';
                dinSel <= FOOTER;
                wr_en  <= '1';

            when finish =>
                crcRst  <= '1';
                holdext <= '0';

            when rst_asic =>
                holdext <= '0';
                rst_n   <= '0';

            when others =>
                null;
        end case;
    end process;

end Behavioral;
