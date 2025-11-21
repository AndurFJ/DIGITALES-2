----------------------------------------------------------------------------------
-- PROYECTO FINAL: SISTEMA DE SEGURIDAD Y JUEGO
-- VERSIÓN FINAL V4 (Corrección de letras en Display SUBE/BAJA/OH/FAIL)
-- FPGA: Basys 3
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ===============================================================================
-- MÓDULO 1: DEBOUNCER (Filtro anti-rebote)
-- ===============================================================================
entity debouncer is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        btn_in : in STD_LOGIC;
        btn_out : out STD_LOGIC
    );
end debouncer;

architecture Behavioral of debouncer is
    constant UMBRAL_CONTADOR : integer := 500_000; -- 5ms
    signal btn_sync_0, btn_sync_1 : std_logic := '0';
    signal contador : integer range 0 to UMBRAL_CONTADOR := 0;
    signal estado_estable : std_logic := '0';
begin
    process(clk, reset)
    begin
        if reset = '1' then
            btn_sync_0 <= '0'; btn_sync_1 <= '0';
            contador <= 0; estado_estable <= '0'; btn_out <= '0';
        elsif rising_edge(clk) then
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
            if (btn_sync_1 /= estado_estable) then
                contador <= contador + 1;
                if contador >= UMBRAL_CONTADOR then
                    estado_estable <= btn_sync_1;
                    contador <= 0;
                end if;
            else
                contador <= 0;
            end if;
            btn_out <= estado_estable;
        end if;
    end process;
end Behavioral;

-- ===============================================================================
-- MÓDULO 2: ALMACENAMIENTO DE CLAVE
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity almacenamiento_clave is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        modo_config : in STD_LOGIC;
        nueva_clave : in STD_LOGIC_VECTOR (3 downto 0);
        confirmar : in STD_LOGIC;
        clave_almacenada : out STD_LOGIC_VECTOR (3 downto 0);
        clave_programada : out STD_LOGIC
    );
end almacenamiento_clave;

architecture Behavioral of almacenamiento_clave is
    signal clave_reg : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal programada : STD_LOGIC := '0';
    signal confirmar_prev : STD_LOGIC := '0';
begin
    process(clk, reset)
    begin
        if reset = '1' then
            clave_reg <= "0000"; programada <= '0'; confirmar_prev <= '0';
        elsif rising_edge(clk) then
            confirmar_prev <= confirmar;
            if modo_config = '1' and confirmar = '1' and confirmar_prev = '0' then
                clave_reg <= nueva_clave;
                programada <= '1';
            end if;
        end if;
    end process;
    clave_almacenada <= clave_reg;
    clave_programada <= programada;
end Behavioral;

-- ===============================================================================
-- MÓDULO 3: CONTADOR DE INTENTOS
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity contador_intentos is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        intento_fallido : in STD_LOGIC;
        reiniciar_contador : in STD_LOGIC;
        intentos_restantes : out STD_LOGIC_VECTOR (1 downto 0);
        sin_intentos : out STD_LOGIC
    );
end contador_intentos;

architecture Behavioral of contador_intentos is
    signal contador : unsigned(1 downto 0) := "11";
    signal intento_prev, reiniciar_prev : STD_LOGIC := '0';
begin
    process(clk, reset)
    begin
        if reset = '1' then
            contador <= "11"; intento_prev <= '0'; reiniciar_prev <= '0';
        elsif rising_edge(clk) then
            intento_prev <= intento_fallido;
            reiniciar_prev <= reiniciar_contador;
            if reiniciar_contador = '1' and reiniciar_prev = '0' then
                contador <= "11";
            elsif intento_fallido = '1' and intento_prev = '0' and contador /= "00" then
                contador <= contador - 1;
            end if;
        end if;
    end process;
    intentos_restantes <= std_logic_vector(contador);
    sin_intentos <= '1' when contador = "00" else '0';
end Behavioral;

-- ===============================================================================
-- MÓDULO 4: TEMPORIZADOR DE BLOQUEO
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity temporizador_bloqueo is
    Generic ( CLK_FREQ : integer := 100_000_000; TIEMPO_BLOQUEO : integer := 30 );
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        iniciar_bloqueo : in STD_LOGIC;
        bloqueado : out STD_LOGIC;
        tiempo_restante : out STD_LOGIC_VECTOR (5 downto 0)
    );
end temporizador_bloqueo;

architecture Behavioral of temporizador_bloqueo is
    signal contador_clk : unsigned(26 downto 0) := (others => '0');
    signal segundos : unsigned(5 downto 0) := (others => '0');
    signal en_bloqueo, iniciar_prev : STD_LOGIC := '0';
    constant TICKS_POR_SEG : integer := CLK_FREQ - 1;
begin
    process(clk, reset)
    begin
        if reset = '1' then
            contador_clk <= (others => '0'); segundos <= (others => '0');
            en_bloqueo <= '0'; iniciar_prev <= '0';
        elsif rising_edge(clk) then
            iniciar_prev <= iniciar_bloqueo;
            if iniciar_bloqueo = '1' and iniciar_prev = '0' then
                en_bloqueo <= '1';
                segundos <= to_unsigned(TIEMPO_BLOQUEO, 6);
                contador_clk <= (others => '0');
            elsif en_bloqueo = '1' then
                if contador_clk = TICKS_POR_SEG then
                    contador_clk <= (others => '0');
                    if segundos > 0 then segundos <= segundos - 1; else en_bloqueo <= '0'; end if;
                else
                    contador_clk <= contador_clk + 1;
                end if;
            end if;
        end if;
    end process;
    bloqueado <= en_bloqueo;
    tiempo_restante <= std_logic_vector(segundos);
end Behavioral;

-- ===============================================================================
-- MÓDULO 5: VERIFICACIÓN DE CLAVE (Con Cooldown de 1 Segundo)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity verificacion_clave is
    Port ( 
        clk, reset, verificar, bloqueado : in STD_LOGIC;
        clave_ingresada, clave_correcta : in STD_LOGIC_VECTOR (3 downto 0);
        acceso_concedido, acceso_denegado, verificando : out STD_LOGIC
    );
end verificacion_clave;

architecture Behavioral of verificacion_clave is
    type estado_t is (IDLE, VERIFICANDO_ST, CORRECTO, INCORRECTO, COOLDOWN_ERROR);
    signal estado_actual : estado_t := IDLE;
    
    signal verificar_prev, concedido : STD_LOGIC := '0';
    signal denegado_reg : STD_LOGIC := '0'; -- Señal interna para el error
    
    -- Temporizadores
    signal contador_tiempo : unsigned(27 downto 0) := (others => '0');
    
    -- Constantes de tiempo (para 100 MHz)
    constant TICKS_2_SEG : integer := 200_000_000; -- Para el éxito (Victory lap)
    constant TICKS_1_SEG : integer := 100_000_000; -- Para el error (Cooldown)
    
begin
    process(clk, reset)
    begin
        if reset = '1' then
            estado_actual <= IDLE; 
            verificar_prev <= '0'; 
            concedido <= '0'; 
            denegado_reg <= '0';
            contador_tiempo <= (others => '0');
        elsif rising_edge(clk) then
            verificar_prev <= verificar;
            
            case estado_actual is
                when IDLE =>
                    concedido <= '0'; 
                    denegado_reg <= '0';
                    contador_tiempo <= (others => '0');
                    
                    -- Solo iniciamos si hay flanco, NO hay bloqueo y NO estamos en cooldown
                    if verificar = '1' and verificar_prev = '0' and bloqueado = '0' then
                        estado_actual <= VERIFICANDO_ST;
                    end if;
                
                when VERIFICANDO_ST =>
                    if clave_ingresada = clave_correcta then
                        estado_actual <= CORRECTO; 
                        concedido <= '1'; 
                        contador_tiempo <= (others => '0');
                    else
                        -- Si falla, activamos denegado y vamos a cooldown
                        estado_actual <= INCORRECTO;
                        denegado_reg <= '1'; 
                    end if;
                
                when CORRECTO =>
                    -- Mantiene la señal de éxito un rato
                    if contador_tiempo < TICKS_2_SEG then
                        contador_tiempo <= contador_tiempo + 1; 
                        concedido <= '1';
                    else
                        concedido <= '0'; 
                        estado_actual <= IDLE;
                    end if;
                
                when INCORRECTO =>
                    -- Este estado dura solo 1 ciclo para mandar el pulso de "restar vida"
                    estado_actual <= COOLDOWN_ERROR;
                    denegado_reg <= '0'; -- Apagamos la señal de error inmediatamente
                    contador_tiempo <= (others => '0');

                when COOLDOWN_ERROR =>
                    -- AQUÍ ESTÁ LA MAGIA: Esperamos 1 segundo sin hacer NADA.
                    -- Si presionas el botón aquí, el sistema lo ignora.
                    if contador_tiempo < TICKS_1_SEG then
                        contador_tiempo <= contador_tiempo + 1;
                    else
                        estado_actual <= IDLE; -- Volvemos a estar listos
                    end if;
                    
            end case;
        end if;
    end process;
    
    acceso_concedido <= concedido;
    acceso_denegado <= denegado_reg; -- Solo dura 1 ciclo de reloj (muy rápido)
    
    -- Indicador visual opcional (puedes conectarlo a un LED si quieres depurar)
    verificando <= '1' when estado_actual = VERIFICANDO_ST else '0';
    
end Behavioral;

-- ===============================================================================
-- MÓDULO 6: VISUALIZACIÓN DISPLAY (SEGURIDAD)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity visualizacion_display is
    Port ( 
        clk, reset, bloqueado : in STD_LOGIC;
        intentos : in STD_LOGIC_VECTOR (1 downto 0);
        tiempo_bloqueo : in STD_LOGIC_VECTOR (5 downto 0);
        seg : out STD_LOGIC_VECTOR (6 downto 0);
        an : out STD_LOGIC_VECTOR (3 downto 0)
    );
end visualizacion_display;

architecture Behavioral of visualizacion_display is
    signal refresh_counter : unsigned(19 downto 0) := (others => '0');
    signal display_select : STD_LOGIC_VECTOR(1 downto 0);
    signal digit0, digit1, digit2, digit3, digit_actual : STD_LOGIC_VECTOR(3 downto 0);
    
    function num_to_7seg(num : STD_LOGIC_VECTOR(3 downto 0)) return STD_LOGIC_VECTOR is
    begin
        case num is
            -- Mapeo estándar 0-9
            when "0000" => return "0000001"; -- 0
            when "0001" => return "1001111"; -- 1
            when "0010" => return "0010010"; -- 2
            when "0011" => return "0000110"; -- 3
            when "0100" => return "1001100"; -- 4
            when "0101" => return "0100100"; -- 5
            when "0110" => return "0100000"; -- 6
            when "0111" => return "0001111"; -- 7
            when "1000" => return "0000000"; -- 8
            when "1001" => return "0000100"; -- 9
            when others => return "1111111"; -- OFF
        end case;
    end function;
begin
    process(clk, reset)
    begin
        if reset = '1' then refresh_counter <= (others => '0');
        elsif rising_edge(clk) then refresh_counter <= refresh_counter + 1;
        end if;
    end process;
    display_select <= std_logic_vector(refresh_counter(19 downto 18)); 
    
    process(bloqueado, intentos, tiempo_bloqueo)
        variable tiempo_int, decenas, unidades : integer;
    begin
        if bloqueado = '1' then
            tiempo_int := to_integer(unsigned(tiempo_bloqueo));
            decenas := tiempo_int / 10;
            unidades := tiempo_int mod 10;
            digit0 <= std_logic_vector(to_unsigned(unidades, 4)); 
            digit1 <= std_logic_vector(to_unsigned(decenas, 4));  
            digit2 <= "1111"; digit3 <= "1111";
        else
            digit0 <= "00" & intentos;
            digit1 <= "1111"; digit2 <= "1111"; digit3 <= "1111";
        end if;
    end process;
    
    process(display_select, digit0, digit1, digit2, digit3)
    begin
        case display_select is
            when "00" => an <= "1110"; digit_actual <= digit0; 
            when "01" => an <= "1101"; digit_actual <= digit1; 
            when "10" => an <= "1011"; digit_actual <= digit2; 
            when "11" => an <= "0111"; digit_actual <= digit3; 
            when others => an <= "1111"; digit_actual <= "1111";
        end case;
    end process;
    seg <= num_to_7seg(digit_actual);
end Behavioral;

-- ===============================================================================
-- MÓDULO 7: SISTEMA SEGURIDAD TOP (V6 - Reinicio de intentos al ganar)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sistema_seguridad_top is
    Port ( 
        CLK : in STD_LOGIC;
        SW : in STD_LOGIC_VECTOR (3 downto 0);
        BTNL, BTNC, BTNR : in STD_LOGIC;
        LED : out STD_LOGIC_VECTOR (15 downto 0);
        seg : out STD_LOGIC_VECTOR (6 downto 0);
        an : out STD_LOGIC_VECTOR (3 downto 0)
    );
end sistema_seguridad_top;

architecture Behavioral of sistema_seguridad_top is
    signal clave_almacenada_v : STD_LOGIC_VECTOR(3 downto 0);
    signal tiempo_restante_v : STD_LOGIC_VECTOR(5 downto 0);
    signal intentos_restantes_sig : STD_LOGIC_VECTOR(1 downto 0);
    signal clave_programada_sig, sin_intentos_sig, bloqueado_sig : STD_LOGIC;
    signal acceso_concedido_sig, acceso_denegado_sig, verificando_sig : STD_LOGIC;
    signal iniciar_bloqueo_sig, reiniciar_intentos_sig : STD_LOGIC;
    signal sin_intentos_prev, bloqueado_prev : STD_LOGIC := '0';
    signal btnc_clean : std_logic;
begin
    -- Instanciación de submódulos
    U_DB: entity work.debouncer port map (clk => CLK, reset => BTNR, btn_in => BTNC, btn_out => btnc_clean);
    
    U_ALM: entity work.almacenamiento_clave port map (clk => CLK, reset => BTNR, modo_config => BTNL, nueva_clave => SW, confirmar => btnc_clean, clave_almacenada => clave_almacenada_v, clave_programada => clave_programada_sig);
    
    U_CONT: entity work.contador_intentos port map (clk => CLK, reset => BTNR, intento_fallido => acceso_denegado_sig, reiniciar_contador => reiniciar_intentos_sig, intentos_restantes => intentos_restantes_sig, sin_intentos => sin_intentos_sig);
    
    U_TEMP: entity work.temporizador_bloqueo port map (clk => CLK, reset => BTNR, iniciar_bloqueo => iniciar_bloqueo_sig, bloqueado => bloqueado_sig, tiempo_restante => tiempo_restante_v);
    
    U_VER: entity work.verificacion_clave port map (clk => CLK, reset => BTNR, clave_ingresada => SW, clave_correcta => clave_almacenada_v, verificar => btnc_clean, bloqueado => bloqueado_sig, acceso_concedido => acceso_concedido_sig, acceso_denegado => acceso_denegado_sig, verificando => verificando_sig);
    
    U_VIS: entity work.visualizacion_display port map (clk => CLK, reset => BTNR, intentos => intentos_restantes_sig, tiempo_bloqueo => tiempo_restante_v, bloqueado => bloqueado_sig, seg => seg, an => an);

    -- ============================================================
    -- LÓGICA DE CONTROL DE ESTADOS (MODIFICADA)
    -- ============================================================
    process(CLK, BTNR) begin
        if BTNR = '1' then 
            sin_intentos_prev<='0'; bloqueado_prev<='0'; iniciar_bloqueo_sig<='0'; reiniciar_intentos_sig<='0';
        elsif rising_edge(CLK) then
            sin_intentos_prev <= sin_intentos_sig; 
            bloqueado_prev <= bloqueado_sig;
            
            -- Iniciar bloqueo si se acaban los intentos
            if sin_intentos_sig='1' and sin_intentos_prev='0' then 
                iniciar_bloqueo_sig<='1'; 
            else 
                iniciar_bloqueo_sig<='0'; 
            end if;
            
            -- REINICIAR INTENTOS (Vidas)
            -- 1. Si el bloqueo terminó (bloqueado pasa de 1 a 0)
            -- 2. O SI GANASTE (acceso_concedido_sig es 1) -> CAMBIO AQUÍ
            if (bloqueado_sig='0' and bloqueado_prev='1') or (acceso_concedido_sig = '1') then 
                reiniciar_intentos_sig<='1'; 
            else 
                reiniciar_intentos_sig<='0'; 
            end if;
        end if;
    end process;

    -- ============================================================
    -- ASIGNACIÓN DE LEDS (Mantiene tu estilo unificado)
    -- ============================================================
    process(acceso_concedido_sig, bloqueado_sig, clave_programada_sig, BTNL, intentos_restantes_sig, SW, clave_almacenada_v)
    begin
        if acceso_concedido_sig = '1' then
            LED <= (others => '1'); -- Victoria: Todos prendidos
        else
            LED <= (others => '0'); -- Fondo apagado

            -- Eco de Switches (0-3)
            LED(3 downto 0) <= SW;

            -- Barra de Vidas (9-7)
            case intentos_restantes_sig is
                when "11" => LED(9 downto 7) <= "111"; -- 3 Vidas
                when "10" => LED(8 downto 7) <= "11";  -- 2 Vidas
                when "01" => LED(7) <= '1';            -- 1 Vida
                when others => null;
            end case;

            -- Estados
            LED(14) <= bloqueado_sig;        
            LED(13) <= clave_programada_sig; 
            LED(12) <= BTNL;                 
            
            -- Ver Clave guardada (Si presionas BTNL)
            if BTNL = '1' then
                LED(11 downto 8) <= clave_almacenada_v; 
            end if;
        end if;
    end process;

end Behavioral;




-- ===============================================================================
-- MÓDULO 8: JUEGO ADIVINANZA (V13 - CORRECCIÓN VISUAL DEFINITIVA)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ===============================================================================
-- SUB-MÓDULO 8.1: BASE DE TIEMPOS (Relojes y Contadores)
-- ===============================================================================
entity juego_timebase is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        clk_1hz_enable : out STD_LOGIC; -- Pulso cada segundo
        refresh_cnt : out integer -- Contador rápido para Display y Random
    );
end juego_timebase;

architecture Behavioral of juego_timebase is
    constant CLK_FREQ : integer := 100_000_000;
    constant MAX_REFRESH : integer := 200_000;
    signal cnt_1s : integer range 0 to CLK_FREQ := 0;
    signal cnt_ref : integer range 0 to MAX_REFRESH := 0;
begin
    process(clk, reset)
    begin
        if reset = '1' then
            cnt_1s <= 0; cnt_ref <= 0; clk_1hz_enable <= '0';
        elsif rising_edge(clk) then
            -- Generador 1Hz
            if cnt_1s = CLK_FREQ - 1 then
                cnt_1s <= 0; clk_1hz_enable <= '1';
            else
                cnt_1s <= cnt_1s + 1; clk_1hz_enable <= '0';
            end if;
            
            -- Generador Refresco (Rápido)
            if cnt_ref = MAX_REFRESH then
                cnt_ref <= 0;
            else
                cnt_ref <= cnt_ref + 1;
            end if;
        end if;
    end process;
    refresh_cnt <= cnt_ref;
end Behavioral;

-- ===============================================================================
-- SUB-MÓDULO 8.2: NÚCLEO LÓGICO (FSM - Cerebro del Juego)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity juego_fsm_core is
    Port (
        clk, reset : in std_logic;
        btn_validar : in std_logic; -- Botón limpio
        sw_in : in std_logic_vector(3 downto 0);
        clk_1hz_en : in std_logic;
        refresh_val : in integer;   -- Semilla para random
        
        -- Salidas
        leds_out : out std_logic_vector(15 downto 0);
        state_code : out std_logic_vector(2 downto 0); -- Código para el display
        countdown_val : out integer range 0 to 15
    );
end juego_fsm_core;

architecture Behavioral of juego_fsm_core is
    type state_type is (init, espera_ingreso, validar, oh_st, sube_st, baja_st, mostrar_fail, bloqueo_timer);
    signal state : state_type := init;
    
    signal numero_adivinar, intento : std_logic_vector(3 downto 0) := "0000";
    signal intentos_count : integer range 0 to 5 := 5;
    signal cuenta_reg : integer range 0 to 15 := 15;
    signal msg_timer : integer range 0 to 300_000_000 := 0;
    
    signal btn_prev : std_logic := '0';
    signal btn_posedge : std_logic;
    
    signal leds_int : std_logic_vector(15 downto 0);
    signal st_code_int : std_logic_vector(2 downto 0);
begin
    -- Detector de flanco interno
    process(clk) begin if rising_edge(clk) then btn_prev <= btn_validar; end if; end process;
    btn_posedge <= btn_validar and (not btn_prev);

    process(clk, reset)
    begin
        if reset = '1' then
            state <= init; intentos_count <= 5; cuenta_reg <= 15;
            numero_adivinar <= "0000"; msg_timer <= 0;
        elsif rising_edge(clk) then
            leds_int <= (others => '0');
            leds_int(3 downto 0) <= sw_in; -- Eco siempre

            case state is
                when init =>
                    intentos_count <= 5; state <= espera_ingreso;
                    
                when espera_ingreso =>
                    st_code_int <= "000"; -- ID 0
                    -- Barra Vidas (11-7)
                    if intentos_count >= 1 then leds_int(7) <= '1'; end if;
                    if intentos_count >= 2 then leds_int(8) <= '1'; end if;
                    if intentos_count >= 3 then leds_int(9) <= '1'; end if;
                    if intentos_count >= 4 then leds_int(10) <= '1'; end if;
                    if intentos_count = 5  then leds_int(11) <= '1'; end if;
                    
                    if btn_posedge = '1' then
                        intento <= sw_in;
                        if intentos_count = 5 then
                            numero_adivinar <= std_logic_vector(to_unsigned(refresh_val mod 16, 4));
                        end if;
                        state <= validar;
                    end if;
                    
                when validar =>
                    st_code_int <= "000";
                    if intento = numero_adivinar then
                        msg_timer <= 0; state <= oh_st;
                    else
                        if intentos_count > 0 then intentos_count <= intentos_count - 1; end if;
                        msg_timer <= 0;
                        if unsigned(intento) < unsigned(numero_adivinar) then state <= sube_st;
                        else state <= baja_st; end if;
                    end if;
                    
                when sube_st =>
                    st_code_int <= "001"; -- ID 1 (SUBE)
                    -- Mantener Vidas visibles
                    if intentos_count >= 1 then leds_int(7) <= '1'; end if;
                    if intentos_count >= 2 then leds_int(8) <= '1'; end if;
                    if intentos_count >= 3 then leds_int(9) <= '1'; end if;
                    if intentos_count >= 4 then leds_int(10) <= '1'; end if;
                    if intentos_count = 5  then leds_int(11) <= '1'; end if;

                    if msg_timer < 200_000_000 then msg_timer <= msg_timer + 1;
                    else
                        msg_timer <= 0;
                        if intentos_count = 0 then state <= mostrar_fail;
                        else state <= espera_ingreso; end if;
                    end if;

                when baja_st =>
                    st_code_int <= "010"; -- ID 2 (BAJA)
                    -- Mantener Vidas visibles
                    if intentos_count >= 1 then leds_int(7) <= '1'; end if;
                    if intentos_count >= 2 then leds_int(8) <= '1'; end if;
                    if intentos_count >= 3 then leds_int(9) <= '1'; end if;
                    if intentos_count >= 4 then leds_int(10) <= '1'; end if;
                    if intentos_count = 5  then leds_int(11) <= '1'; end if;

                    if msg_timer < 200_000_000 then msg_timer <= msg_timer + 1;
                    else
                        msg_timer <= 0;
                        if intentos_count = 0 then state <= mostrar_fail;
                        else state <= espera_ingreso; end if;
                    end if;

                when oh_st =>
                    st_code_int <= "011"; -- ID 3 (OH/GANAR)
                    leds_int <= (others => '1'); -- Victoria Total
                    if msg_timer < 200_000_000 then msg_timer <= msg_timer + 1;
                    else state <= init; end if;

                when mostrar_fail =>
                    st_code_int <= "100"; -- ID 4 (FAIL)
                    leds_int(13) <= '1';
                    if msg_timer < 200_000_000 then
                        msg_timer <= msg_timer + 1; cuenta_reg <= 15;
                    else
                        msg_timer <= 0; state <= bloqueo_timer;
                    end if;

                when bloqueo_timer =>
                    st_code_int <= "101"; -- ID 5 (Timer)
                    leds_int(14) <= '1';
                    if clk_1hz_en = '1' then
                        if cuenta_reg > 0 then cuenta_reg <= cuenta_reg - 1;
                        else state <= init; end if;
                    end if;
            end case;
        end if;
    end process;
    
    leds_out <= leds_int;
    state_code <= st_code_int;
    countdown_val <= cuenta_reg;
end Behavioral;

-- ===============================================================================
-- SUB-MÓDULO 8.3: CONTROLADOR DE DISPLAY (Visualización V15)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity juego_display_driver is
    Port (
        clk : in std_logic;
        reset : in std_logic;
        refresh_cnt : in integer;
        state_code : in std_logic_vector(2 downto 0);
        sw_in : in std_logic_vector(3 downto 0);
        countdown_val : in integer;
        
        seg : out std_logic_vector(6 downto 0);
        an : out std_logic_vector(3 downto 0)
    );
end juego_display_driver;

architecture Behavioral of juego_display_driver is
    signal an_selector : std_logic_vector(1 downto 0);
    signal data_char : std_logic_vector(4 downto 0);
    signal an_temp : std_logic_vector(3 downto 0);
    
    -- Constantes de caracteres
    constant CHAR_0: std_logic_vector(4 downto 0):="00000"; constant CHAR_1: std_logic_vector(4 downto 0):="00001";
    constant CHAR_A: std_logic_vector(4 downto 0):="01010"; constant CHAR_C: std_logic_vector(4 downto 0):="01100";
    constant CHAR_E: std_logic_vector(4 downto 0):="01110"; constant CHAR_F: std_logic_vector(4 downto 0):="01111";
    constant CHAR_S: std_logic_vector(4 downto 0):="10000"; constant CHAR_U: std_logic_vector(4 downto 0):="10001";
    constant CHAR_b: std_logic_vector(4 downto 0):="10010"; constant CHAR_L: std_logic_vector(4 downto 0):="10011";
    constant CHAR_I: std_logic_vector(4 downto 0):="10100"; constant CHAR_H: std_logic_vector(4 downto 0):="10101";
    constant CHAR_O: std_logic_vector(4 downto 0):="10110"; constant CHAR_J: std_logic_vector(4 downto 0):="10111";
    constant CHAR_GUION: std_logic_vector(4 downto 0):="11111"; constant CHAR_OFF: std_logic_vector(4 downto 0):="11100";

    -- Función V15 Corregida
    function char_to_7seg(val: std_logic_vector(4 downto 0)) return STD_LOGIC_VECTOR is
    begin
        case val is
            -- Numeros
            when "00000" => return "0000001"; when "00001" => return "1001111";
            when "00010" => return "0010010"; when "00011" => return "0000110";
            when "00100" => return "1001100"; when "00101" => return "0100100";
            when "00110" => return "0100000"; when "00111" => return "0001111";
            when "01000" => return "0000000"; when "01001" => return "0000100";
            -- Letras V4
            when "01010" => return "0001000"; -- A
            when "10010" => return "1100000"; -- b
            when "01011" => return "1100000"; -- b alt
            when "01100" => return "0110001"; -- C
            when "01110" => return "0110000"; -- E
            when "01111" => return "0111000"; -- F
            when "10000" => return "0100100"; -- S
            when "10001" => return "1000001"; -- U
            when "10011" => return "1110001"; -- L
            when "10100" => return "1001111"; -- I
            when "10101" => return "1001000"; -- H
            when "10110" => return "0000001"; -- O
            when "10111" => return "1000011"; -- J
            when "11111" => return "1111110"; -- -
            when others => return "1111111"; 
        end case;
    end function;
begin
    -- Usar bits altos del contador de refresco para seleccionar anodo
    an_selector <= std_logic_vector(to_unsigned((refresh_cnt / 50000) mod 4, 2));

    process(an_selector, state_code, sw_in, countdown_val)
    begin
        data_char <= CHAR_OFF; an_temp <= "1111";
        case an_selector is
            when "00" => an_temp<="1110"; -- Dig 0
                if state_code="001" then data_char <= CHAR_E;       -- SUB(E)
                elsif state_code="010" then data_char <= CHAR_A;    -- BAJ(A)
                elsif state_code="100" then data_char <= CHAR_L;    -- FAI(L)
                elsif state_code="101" then data_char <= "0" & std_logic_vector(to_unsigned(countdown_val mod 10, 4));
                elsif state_code="000" then 
                    if sw_in(0)='1' then data_char<=CHAR_1; else data_char<=CHAR_0; end if;
                end if;
            when "01" => an_temp<="1101"; -- Dig 1
                if state_code="001" then data_char <= CHAR_b;       -- SU(b)E
                elsif state_code="010" then data_char <= CHAR_J;    -- BA(J)A
                elsif state_code="100" then data_char <= CHAR_I;    -- FA(I)L
                elsif state_code="101" then data_char <= "0" & std_logic_vector(to_unsigned(countdown_val / 10, 4));
                elsif state_code="000" then 
                    if sw_in(1)='1' then data_char<=CHAR_1; else data_char<=CHAR_0; end if;
                end if;
            when "10" => an_temp<="1011"; -- Dig 2
                if state_code="001" then data_char <= CHAR_U;       -- S(U)BE
                elsif state_code="010" then data_char <= CHAR_A;    -- B(A)JA
                elsif state_code="100" then data_char <= CHAR_A;    -- F(A)IL
                elsif state_code="000" then 
                    if sw_in(2)='1' then data_char<=CHAR_1; else data_char<=CHAR_0; end if;
                end if;
            when "11" => an_temp<="0111"; -- Dig 3
                if state_code="001" then data_char <= CHAR_S;       -- (S)UBE
                elsif state_code="010" then data_char <= CHAR_b;    -- (b)AJA
                elsif state_code="100" then data_char <= CHAR_F;    -- (F)AIL
                elsif state_code="000" then 
                    if sw_in(3)='1' then data_char<=CHAR_1; else data_char<=CHAR_0; end if;
                end if;
            when others => an_temp<="1111";
        end case;
    end process;

    -- Salida final con Override OH (V15)
    seg <= "1001000" when (state_code="011" and an_selector="00") else -- H
           "0000001" when (state_code="011" and an_selector="01") else -- O
           "1111111" when (state_code="011") else
           char_to_7seg(data_char);
           
    an <= an_temp;
end Behavioral;

-- ===============================================================================
-- MÓDULO 8 (TOP): JUEGO ADIVINANZA (Integra Bloques)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity juego_adivinanza is
    Port (
        clk, reset, BTNC_validar : in std_logic;
        SW_in : in std_logic_vector(3 downto 0);
        LED_out : out std_logic_vector(15 downto 0);
        seg : out std_logic_vector(6 downto 0);
        an : out std_logic_vector(3 downto 0)
    );
end juego_adivinanza;

architecture Structural of juego_adivinanza is
    -- Señales de interconexión
    signal s_clk_1hz : std_logic;
    signal s_refresh : integer;
    signal s_state_code : std_logic_vector(2 downto 0);
    signal s_countdown : integer;
    signal s_btn_clean : std_logic; -- Usamos el botón limpio que ya viene de top_game, pero podemos recablearlo si hiciera falta
begin
    -- Módulo 8 recibe BTNC_validar ya limpio desde top_game, 
    -- así que lo pasamos directo a la FSM.

    -- 1. Instancia Base de Tiempo
    U_TIME: entity work.juego_timebase port map (
        clk => clk, reset => reset, 
        clk_1hz_enable => s_clk_1hz, refresh_cnt => s_refresh
    );

    -- 2. Instancia Lógica (Cerebro)
    U_CORE: entity work.juego_fsm_core port map (
        clk => clk, reset => reset, 
        btn_validar => BTNC_validar, 
        sw_in => SW_in, 
        clk_1hz_en => s_clk_1hz, refresh_val => s_refresh,
        leds_out => LED_out, 
        state_code => s_state_code, 
        countdown_val => s_countdown
    );

    -- 3. Instancia Display (Vista)
    U_DISP: entity work.juego_display_driver port map (
        clk => clk, reset => reset,
        refresh_cnt => s_refresh,
        state_code => s_state_code,
        sw_in => SW_in,
        countdown_val => s_countdown,
        seg => seg, an => an
    );

end Structural;


-- ===============================================================================
-- MÓDULO 9: TOP GAME (CARGA LENTA - 1 SEGUNDO)
-- ===============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_game is
    Port (
        clk : in std_logic;
        SW : in std_logic_vector(4 downto 0); 
        BTNC, BTNL, BTNR : in std_logic; 
        LEDS : out std_logic_vector(15 downto 0);
        DISP_SEG : out std_logic_vector(6 downto 0);
        DISP_AN : out std_logic_vector(3 downto 0)
    );
end top_game;

architecture Behavioral of top_game is
    signal selector_modo, reset_global, btnc_clean : std_logic;
    signal sw_data : std_logic_vector(3 downto 0); 
    
    -- Salidas de los módulos
    signal seg_out_LEDS, juego_out_LEDS : std_logic_vector(15 downto 0);
    signal seg_out_DISP_SEG, juego_out_seg : std_logic_vector(6 downto 0);
    signal seg_out_DISP_AN, juego_out_an : std_logic_vector(3 downto 0);
    
    -- Señales para el efecto de carga
    signal sw_mode_prev : std_logic := '0';
    signal loading_active : std_logic := '0';
    
    -- AJUSTE 1: Duración TOTAL del efecto (1 Segundo = 100_000_000 ciclos)
    signal loading_timer_max : integer := 100_000_000; 
    signal loading_timer_current : integer range 0 to 100_000_000 := 0; 

    -- Para la secuencia de LEDs
    signal seq_led_counter : integer range 0 to 2 := 0; 
    
    -- AJUSTE 2: Velocidad de movimiento (Más lento = número más grande)
    -- 15_000_000 ciclos = 0.15 segundos por salto (aprox 6.6 saltos por segundo)
    signal seq_clk_divider : integer range 0 to 15_000_000 := 0; 
    constant SEQ_SPEED_TICKS : integer := 15_000_000; 
begin
    -- Asignaciones básicas
    selector_modo <= SW(4);        
    sw_data <= SW(3 downto 0);    
    reset_global <= BTNR;          
    
    -- Instanciación de Módulos
    U_DB: entity work.debouncer port map (clk=>clk, reset=>reset_global, btn_in=>BTNC, btn_out=>btnc_clean);
    
    U_SEG: entity work.sistema_seguridad_top port map (
        CLK=>clk, SW=>sw_data, BTNL=>BTNL, BTNC=>btnc_clean, BTNR=>reset_global, 
        LED=>seg_out_LEDS, seg=>seg_out_DISP_SEG, an=>seg_out_DISP_AN
    );
    
    U_JUE: entity work.juego_adivinanza port map (
        clk=>clk, reset=>reset_global, SW_in=>sw_data, BTNC_validar=>btnc_clean, 
        LED_out=>juego_out_LEDS, seg=>juego_out_seg, an=>juego_out_an
    );

    -- PROCESO DE CONTROL DEL EFECTO DE CARGA
    process(clk)
    begin
        if rising_edge(clk) then
            -- Detección de cambio de modo
            if sw_mode_prev /= selector_modo then
                loading_active <= '1';                
                loading_timer_current <= loading_timer_max; 
                seq_led_counter <= 0;                 
                seq_clk_divider <= 0;                 
            end if;
            sw_mode_prev <= selector_modo;
            
            -- Lógica del temporizador de carga
            if loading_active = '1' then
                if loading_timer_current > 0 then
                    loading_timer_current <= loading_timer_current - 1;
                    
                    -- Lógica del secuenciador (más lento ahora)
                    if seq_clk_divider = SEQ_SPEED_TICKS then
                        seq_clk_divider <= 0;
                        seq_led_counter <= (seq_led_counter + 1) mod 3; 
                    else
                        seq_clk_divider <= seq_clk_divider + 1;
                    end if;
                else
                    loading_active <= '0'; -- Termina carga
                end if;
            end if;
        end if;
    end process;

    -- MUX DE SALIDA CON OVERRIDE DE CARGA
    process(selector_modo, loading_active, seq_led_counter, 
            seg_out_LEDS, seg_out_DISP_SEG, seg_out_DISP_AN, 
            juego_out_LEDS, juego_out_seg, juego_out_an)
        variable temp_leds : std_logic_vector(15 downto 0);
    begin
        if loading_active = '1' then
            -- EFECTO CARGA SECUENCIAL (LEDS 6, 7, 8)
            temp_leds := (others => '0'); 
            
            case seq_led_counter is
                when 0 => temp_leds(6) := '1'; -- Primero el 6
                when 1 => temp_leds(7) := '1'; -- Luego el 7
                when 2 => temp_leds(8) := '1'; -- Finalmente el 8
                when others => null;
            end case;
            LEDS <= temp_leds;
            
            DISP_SEG <= "1111111";        -- Apagar display
            DISP_AN <= "1111";            
        else
            -- FUNCIONAMIENTO NORMAL
            if selector_modo = '0' then
                LEDS <= seg_out_LEDS;
                DISP_SEG <= seg_out_DISP_SEG;
                DISP_AN <= seg_out_DISP_AN;
            else
                LEDS <= juego_out_LEDS;
                DISP_SEG <= juego_out_seg;
                DISP_AN <= juego_out_an;
            end if;
        end if;
    end process;

end Behavioral;