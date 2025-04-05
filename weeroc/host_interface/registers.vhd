-------------------------------------------------------------------------------
-- Title      : Internal config and status registers
-- Project    : MAuD v2
-------------------------------------------------------------------------------
-- File       : registers.vhd
-- Author     :   
-- Company    :
-- Created    : 2020-06-01
-- Last update: 2020-08-12
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2020
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-06-01  1.0      Nico    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity registers is
	generic (
		G_IRQ_SUPPORT : boolean          := false;  -- Support des interruptions
		G_FW_VER      : std_logic_vector := x"20"); -- Firmware version
	port
	(
		-- Interface LAL
		subadd     : in  std_logic_vector(6 downto 0);
		user_rdata : out std_logic_vector(7 downto 0);
		user_wdata : in  std_logic_vector(7 downto 0);
		n_write    : in  std_logic;
		n_read     : in  std_logic;
		n_sync     : in  std_logic;
		n_wait     : out std_logic;
		busy       : in  std_logic;
		interrupt  : out std_logic;
		int_data   : out std_logic_vector(7 downto 0);
		-- Registers (interface with Weeroc functions)
		word_0  : out std_logic_vector(7 downto 0);
		word_1  : out std_logic_vector(7 downto 0);
		word_2  : out std_logic_vector(7 downto 0);
		word_3  : out std_logic_vector(7 downto 0);
		word_4  : in  std_logic_vector(7 downto 0);
		word_5  : out std_logic_vector(7 downto 0);
		word_6  : out std_logic_vector(7 downto 0);
		word_8  : in  std_logic_vector(7 downto 0);
		word_9  : in  std_logic_vector(7 downto 0);
		word_18 : in  std_logic_vector(7 downto 0);
		word_19 : in  std_logic_vector(7 downto 0);
		word_20 : in  std_logic_vector(7 downto 0);
		word_21 : out  std_logic_vector(7 downto 0);
		word_22 : out  std_logic_vector(7 downto 0);
		word_23 : out  std_logic_vector(7 downto 0);
		word_24 : out  std_logic_vector(7 downto 0);
		word_25 : out std_logic_vector(7 downto 0);
		word_26 : out std_logic_vector(7 downto 0);
		word_27 : out std_logic_vector(7 downto 0);
		word_28 : in std_logic_vector(7 downto 0);
		word_29 : in std_logic_vector(7 downto 0);
		word_30 : out std_logic_vector(7 downto 0);
		word_31 : out std_logic_vector(7 downto 0);
		word_48 : out std_logic_vector(7 downto 0);
		word_49 : out std_logic_vector(7 downto 0);
		word_50 : in std_logic_vector(7 downto 0);
		word_51 : in std_logic_vector(7 downto 0);
		word_55 : in std_logic_vector(7 downto 0);
		word_56 : out std_logic_vector(7 downto 0);
		word_60 : out std_logic_vector(7 downto 0);
		word_61 : out std_logic_vector(7 downto 0);
		word_62 : out std_logic_vector(7 downto 0);
		word_63 : out std_logic_vector(7 downto 0);
		word_64 : out std_logic_vector(7 downto 0);
		word_65 : out std_logic_vector(7 downto 0);
		word_66 : out std_logic_vector(7 downto 0);
		word_67 : out std_logic_vector(7 downto 0);
		word_68 : out std_logic_vector(7 downto 0);
		word_75 : out std_logic_vector(7 downto 0);
		word_76 : out std_logic_vector(7 downto 0);
		word_77 : out std_logic_vector(7 downto 0);
		word_78 : out std_logic_vector(7 downto 0);
		word_79 : out std_logic_vector(7 downto 0);
		word_96 : in  std_logic_vector(7 downto 0);
		word_97 : in  std_logic_vector(7 downto 0);
		word_98 : in  std_logic_vector(7 downto 0);
		word_99 : in  std_logic_vector(7 downto 0);
		rd_20 : out std_logic;
		wr_24 : out std_logic;
		rd_55   : out std_logic;
		wr_56   : out std_logic;
		-- Acquisition data FIFO interface
		fifo_out     : in  std_logic_vector(7 downto 0);
		fifo_read      : out std_logic;
		fifo_count   : in  std_logic_vector(15 downto 0);
		fifo_empty   : in  std_logic;
		fifo_fr_rdy  : in  std_logic;
		fifo_full    : in  std_logic;
		fifo_overrun : in  std_logic;
		acq_en           : out std_logic;
		extrd_en         : out std_logic;
		fifo_clr     : out std_logic;
		acq_cnt_clr      : in  std_logic;
		-- Multi-BE sync
		set_sync_master : out std_logic;
		set_sync_slave  : out std_logic;
		do_sync         : out std_logic;
		-- Extended read FIFO read signal
		extrd_fifo_rd : in std_logic;
		-- Clock & Reset
		clk : in std_logic;
		rst : in std_logic
	);
end entity registers;

architecture rtl of registers is
	signal fifo_rd : std_logic;

begin -- architecture rtl

	fifo_read <= fifo_rd or extrd_fifo_rd;

	p : process (clk, rst) is
		type t_reg_array is array (natural range <>) of std_logic_vector(7 downto 0);
		variable v_regs        : t_reg_array(0 to 127);  -- Banc de registres
		variable v_addr        : natural range 0 to 127; -- Compteur d'adresse
		variable v_delrdwr     : std_logic;
		variable v_delrd       : std_logic;
		variable v_wait        : std_logic_vector(1 downto 0); -- Insertion d'un delai
		variable v_del_fr_rdy  : std_logic;
		variable v_del_overrun : std_logic;
		variable v_acq_sync    : std_logic; -- Decalage d'un cycle de la synchro multi-BE
	begin                               -- process p
		if rst = '1' then                   -- asynchronous reset (active high)
			v_regs := (others => (others => '0'));
			v_regs(0) := "00111111";
			rd_20 <= '0';
			wr_24 <= '0';
			wr_56     <= '0';
			rd_55 <= '0';
			fifo_rd   <= '0';
			interrupt <= '0';
			v_wait        := (others => '0');
			v_delrdwr     := '0';
			v_delrd       := '0';
			v_del_fr_rdy  := '0';
			v_del_overrun := '0';
			v_acq_sync    := '0';
		elsif rising_edge(clk) then -- rising clock edge
			-- Registres en lecture seule ou inutilises -------------------------------	
			v_regs(4)  := word_4;
			v_regs(8)  := word_8;
			v_regs(9)  := word_9;
			v_regs(18) := word_18;
			v_regs(19) := word_19;
			v_regs(20) := word_20;
			v_regs(28) := word_28;
			v_regs(29) := word_29;
			v_regs(40) := fifo_out;                                --
			v_regs(41) := "0000" & fifo_overrun & fifo_full & --
			fifo_fr_rdy & fifo_empty;                          --
			v_regs(42) := fifo_count(7 downto 0);                  --
			v_regs(43) := fifo_count(15 downto 8);                 --
			if not G_IRQ_SUPPORT then                                  --
				v_regs(44)(2) := '0';                                      -- Force disable interrupts            --
			end if;
			v_regs(50) := word_50;
			v_regs(51) := word_51;  
			v_regs(55)  := word_55;
			v_regs(96)  := word_96;
			v_regs(97)  := word_97;
			v_regs(98)  := word_98;
			v_regs(99)  := word_99;
			v_regs(100) := G_FW_VER;
			---------------------------------------------------------------------------
			-- Valeurs par defaut --------------
			rd_20 <= '0';
			rd_55 <= '0';
			wr_24 <= '0';
			wr_56   <= '0';
			fifo_rd <= '0'; --
			------------------------------------
			-- Lecture des registres (toujours actif)
			user_rdata <= v_regs(v_addr);
			-- Registre a decalage d'insertion d'un delai
			v_wait := v_wait(0) & '0';
			-- Generation d'interruption (si support) -------------------------------
			if G_IRQ_SUPPORT then                                --
				if v_regs(44)(2) = '1' then                          -- Interrupt enable                 --
					if (fifo_overrun and not v_del_overrun) = '1' or --
						(fifo_fr_rdy and not v_del_fr_rdy) = '1' then    --
						-- Generation d'une interruption en cas de debordement de la FIFO --
						-- ou de presence d'au moins une trame complete (en mode polling) --
						interrupt <= '1';                      --
					elsif (n_read and v_delrd) = '1' and   --
						busy = '0' and subadd = "1111111" then --
						-- Acquittement de l'interruption                                 --
						interrupt <= '0'; --
					end if;           --
					-- Vecteur d'interruption = �tat de la FIFO                         --
					int_data <= "0000" & fifo_overrun &          --
						fifo_full & fifo_fr_rdy & fifo_empty; --
				else                                              --
					interrupt <= '0';                                 --
				end if;                                           --
			end if;                                           --
			--------------------------------------------------------------------------
			-- Decalage d'une periode d'horloge pour detection des fronts --
			v_del_fr_rdy  := fifo_fr_rdy or v_regs(44)(1); --
			v_del_overrun := fifo_overrun;                 --
			----------------------------------------------------------------
			if n_sync = '0' then
				-- Premier acc�s / acc�s seul ---------------------------
				-- Echantilonnage de l'adresse                         --
				v_addr := to_integer(unsigned(subadd)); --
				if n_read = '0' then                    --
					-- En cas de lecture, insertion de 2 cycles d'atente --
					v_wait := (others => '1'); --
				end if;                    --
				---------------------------------------------------------
			elsif (n_read and n_write and v_delrdwr) = '1' then
				-- Acc�s suivants --------------------------------------
				if v_addr /= 40 and v_addr /= 56 and v_addr /= 55 and v_addr /= 20 then --
					-- Autoincr�mentation de l'adresse sauf FIFOs       --
					if v_addr < 127 then  --
						v_addr := v_addr + 1; --
					else                  --
						v_addr := 0;          --
					end if;               --
				end if;               --
				--------------------------------------------------------
			end if;
			-- Lecture de la FIFO (mode polling seulement) ------
			if (v_delrd and n_read) = '1' then --
				if v_addr = 40 then                --
					fifo_rd <= not v_regs(44)(1);      -- Mode polling --
				elsif v_addr = 20 then
				    rd_20 <= '1';
				elsif v_addr = 55 then
                        rd_55 <= '1';
                end if; 
			end if;                            --
			-----------------------------------------------------
			if (v_delrdwr or n_write) = '0' then
				if v_addr = 56 then
					--Ecriture de la FIFO Slow Control SCA
					v_regs(56) := user_wdata;
					wr_56 <= '1';
			     elsif v_addr = 24 then
				    v_regs(24) := user_wdata;
				    wr_24 <= '1';
				else
					-- Ecriture de registre
					v_regs(v_addr) := user_wdata;
				end if;
			end if;
			-- Desactivation de l'acquisition en cas de debordement --
			if fifo_overrun = '1' then --
				v_regs(44)(0) := '0';          --
			end if;                        --
			----------------------------------------------------------
			-- Activation automatique de l'acquisition -------
			--  (synchro multi BE) a la fin de l'impulsion  --
			if (v_acq_sync and not acq_cnt_clr) = '1' then --
				v_regs(44)(0) := '1';                          --
			end if;                                        --
			v_acq_sync := acq_cnt_clr;                     --
			--------------------------------------------------
			v_delrdwr              := not (n_read and n_write);
			v_delrd                := not n_read;
			v_regs(44)(6 downto 3) := (others => '0');
			v_regs(47)(7 downto 3) := (others => '0');
		end if;
		-- Affectation des sorties
		word_0  <= v_regs(0);
		word_1  <= v_regs(1);
		word_2  <= v_regs(2);
		word_3  <= v_regs(3);
		word_5  <= v_regs(5);
		word_6  <= v_regs(6);
		word_21 <= v_regs(21);
		word_22 <= v_regs(22);
		word_23 <= v_regs(23);
		word_24 <= v_regs(24);
		word_25 <= v_regs(25);
		word_26 <= v_regs(26);
		word_27 <= v_regs(27);
		word_30 <= v_regs(30);
		word_31 <= v_regs(31);
		word_48 <= v_regs(48);
		word_49 <= v_regs(49);
		word_56 <= v_regs(56);
		word_60 <= v_regs(60);
		word_61 <= v_regs(61);
		word_62 <= v_regs(62);
		word_63 <= v_regs(63);
		word_64 <= v_regs(64);
		word_65 <= v_regs(65);
		word_66 <= v_regs(66);
		word_67 <= v_regs(67);
		word_68 <= v_regs(68);
		word_75 <= v_regs(75);
		word_76 <= v_regs(76);
		word_77 <= v_regs(77);
		word_78 <= v_regs(78);
		word_79 <= v_regs(79);

		acq_en          <= v_regs(44)(0);
		extrd_en        <= v_regs(44)(1);
		fifo_clr    <= v_regs(44)(7);
		set_sync_master <= v_regs(47)(1);
		set_sync_slave  <= v_regs(47)(0);
		do_sync         <= v_regs(47)(2);
		n_wait          <= not v_wait(1);
	end process p;

end architecture rtl;
