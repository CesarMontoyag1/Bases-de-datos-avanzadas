-- ============================================================
-- BONUS: Patrón SAGA sobre transacciones distribuidas
-- Comparación 2PC vs SAGA en PostgreSQL y CockroachDB
-- Proyecto 2 SI3009 — Bonus Track (20%)
-- ============================================================

-- ══════════════════════════════════════════════════════════════
-- CONTEXTO: Por qué SAGA vs 2PC
-- ══════════════════════════════════════════════════════════════
-- 2PC:  bloquea recursos durante toda la transacción → no escala bien
-- SAGA: cada paso es una transacción local + transacción compensatoria
--       si algo falla → ejecutar compensaciones en orden inverso
--       No hay bloqueos inter-nodo → mayor disponibilidad
--
-- Ejemplo bancario: transferencia entre 2 bancos independientes
--   Paso 1: Debitar cuenta origen  → compensación: Acreditar origen
--   Paso 2: Acreditar cuenta destino → compensación: Debitar destino
--   Paso 3: Registrar en auditoría → compensación: Marcar como revertida

-- ══════════════════════════════════════════════════════════════
-- IMPLEMENTACIÓN EN POSTGRESQL
-- ══════════════════════════════════════════════════════════════

-- Tabla de estado de SAGAs (orquestador)
CREATE TABLE IF NOT EXISTS saga_orchestrator (
    saga_id       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo_saga     VARCHAR(50) NOT NULL,
    estado        VARCHAR(20) NOT NULL DEFAULT 'iniciada'
                  CHECK (estado IN ('iniciada','en_proceso','completada','compensando','fallida')),
    payload       JSONB       NOT NULL,
    paso_actual   INT         NOT NULL DEFAULT 0,
    pasos_total   INT         NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla de pasos ejecutados (para idempotencia)
CREATE TABLE IF NOT EXISTS saga_pasos (
    paso_id       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    saga_id       UUID        NOT NULL REFERENCES saga_orchestrator(saga_id),
    paso_numero   INT         NOT NULL,
    nombre_paso   VARCHAR(100) NOT NULL,
    estado        VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                  CHECK (estado IN ('pendiente','ejecutado','compensado','fallido')),
    datos_entrada JSONB,
    datos_salida  JSONB,
    ejecutado_at  TIMESTAMPTZ,
    UNIQUE (saga_id, paso_numero)
);

-- ── SAGA: Transferencia interbancaria ─────────────────────────

CREATE OR REPLACE FUNCTION saga_transferencia_inicio(
    p_cuenta_origen  UUID,
    p_cuenta_destino UUID,
    p_monto          NUMERIC
) RETURNS UUID
LANGUAGE plpgsql AS $$
DECLARE
    v_saga_id UUID;
BEGIN
    INSERT INTO saga_orchestrator (tipo_saga, payload, pasos_total)
    VALUES (
        'transferencia_interbancaria',
        jsonb_build_object(
            'cuenta_origen',  p_cuenta_origen,
            'cuenta_destino', p_cuenta_destino,
            'monto',          p_monto
        ),
        3   -- 3 pasos: debitar, acreditar, auditar
    )
    RETURNING saga_id INTO v_saga_id;

    RETURN v_saga_id;
END;
$$;

-- Paso 1: Debitar cuenta origen
CREATE OR REPLACE FUNCTION saga_paso1_debitar(p_saga_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE
    v_payload   JSONB;
    v_saldo     NUMERIC;
BEGIN
    SELECT payload INTO v_payload FROM saga_orchestrator WHERE saga_id = p_saga_id;

    SELECT saldo INTO v_saldo FROM cuentas
    WHERE cuenta_id = (v_payload->>'cuenta_origen')::UUID FOR UPDATE;

    IF v_saldo < (v_payload->>'monto')::NUMERIC THEN
        -- Fallo: iniciar compensación
        UPDATE saga_orchestrator SET estado = 'fallida', updated_at = now()
        WHERE saga_id = p_saga_id;
        RETURN FALSE;
    END IF;

    -- Ejecutar débito
    UPDATE cuentas
    SET saldo = saldo - (v_payload->>'monto')::NUMERIC, updated_at = now()
    WHERE cuenta_id = (v_payload->>'cuenta_origen')::UUID;

    INSERT INTO saga_pasos (saga_id, paso_numero, nombre_paso, estado, datos_salida, ejecutado_at)
    VALUES (p_saga_id, 1, 'debitar_origen', 'ejecutado',
            jsonb_build_object('saldo_anterior', v_saldo, 'monto_debitado', v_payload->>'monto'),
            now());

    UPDATE saga_orchestrator SET paso_actual = 1, estado = 'en_proceso', updated_at = now()
    WHERE saga_id = p_saga_id;

    RETURN TRUE;
END;
$$;

-- Paso 2: Acreditar cuenta destino
CREATE OR REPLACE FUNCTION saga_paso2_acreditar(p_saga_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE
    v_payload JSONB;
BEGIN
    SELECT payload INTO v_payload FROM saga_orchestrator WHERE saga_id = p_saga_id;

    UPDATE cuentas
    SET saldo = saldo + (v_payload->>'monto')::NUMERIC, updated_at = now()
    WHERE cuenta_id = (v_payload->>'cuenta_destino')::UUID;

    IF NOT FOUND THEN
        PERFORM saga_compensar(p_saga_id);
        RETURN FALSE;
    END IF;

    INSERT INTO saga_pasos (saga_id, paso_numero, nombre_paso, estado, ejecutado_at)
    VALUES (p_saga_id, 2, 'acreditar_destino', 'ejecutado', now());

    UPDATE saga_orchestrator SET paso_actual = 2, updated_at = now()
    WHERE saga_id = p_saga_id;

    RETURN TRUE;
END;
$$;

-- Paso 3: Registrar en auditoría (último paso — SAGA completada)
CREATE OR REPLACE FUNCTION saga_paso3_auditar(p_saga_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE
    v_payload JSONB;
BEGIN
    SELECT payload INTO v_payload FROM saga_orchestrator WHERE saga_id = p_saga_id;

    INSERT INTO transacciones_log (
        cuenta_origen, cuenta_dest, tipo_tx, monto, estado, nodo_origen
    ) VALUES (
        (v_payload->>'cuenta_origen')::UUID,
        (v_payload->>'cuenta_destino')::UUID,
        'transferencia',
        (v_payload->>'monto')::NUMERIC,
        'completado',
        'saga-orchestrator'
    );

    INSERT INTO saga_pasos (saga_id, paso_numero, nombre_paso, estado, ejecutado_at)
    VALUES (p_saga_id, 3, 'registrar_auditoria', 'ejecutado', now());

    UPDATE saga_orchestrator SET paso_actual = 3, estado = 'completada', updated_at = now()
    WHERE saga_id = p_saga_id;

    RETURN TRUE;
END;
$$;

-- ── COMPENSACIÓN: deshacer en orden inverso ───────────────────
CREATE OR REPLACE FUNCTION saga_compensar(p_saga_id UUID)
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_payload     JSONB;
    v_paso_actual INT;
BEGIN
    SELECT payload, paso_actual INTO v_payload, v_paso_actual
    FROM saga_orchestrator WHERE saga_id = p_saga_id;

    UPDATE saga_orchestrator SET estado = 'compensando', updated_at = now()
    WHERE saga_id = p_saga_id;

    -- Compensar en orden INVERSO
    IF v_paso_actual >= 2 THEN
        -- Compensación paso 2: debitar lo que se acreditó
        UPDATE cuentas
        SET saldo = saldo - (v_payload->>'monto')::NUMERIC, updated_at = now()
        WHERE cuenta_id = (v_payload->>'cuenta_destino')::UUID;

        UPDATE saga_pasos SET estado = 'compensado'
        WHERE saga_id = p_saga_id AND paso_numero = 2;
    END IF;

    IF v_paso_actual >= 1 THEN
        -- Compensación paso 1: devolver el débito
        UPDATE cuentas
        SET saldo = saldo + (v_payload->>'monto')::NUMERIC, updated_at = now()
        WHERE cuenta_id = (v_payload->>'cuenta_origen')::UUID;

        UPDATE saga_pasos SET estado = 'compensado'
        WHERE saga_id = p_saga_id AND paso_numero = 1;
    END IF;

    UPDATE saga_orchestrator SET estado = 'fallida', updated_at = now()
    WHERE saga_id = p_saga_id;

    RAISE NOTICE 'SAGA % compensada exitosamente', p_saga_id;
END;
$$;

-- ── ORQUESTADOR PRINCIPAL ─────────────────────────────────────
CREATE OR REPLACE FUNCTION ejecutar_saga_transferencia(
    p_origen  UUID,
    p_destino UUID,
    p_monto   NUMERIC
) RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_saga_id UUID;
BEGIN
    v_saga_id := saga_transferencia_inicio(p_origen, p_destino, p_monto);

    IF NOT saga_paso1_debitar(v_saga_id)  THEN RETURN jsonb_build_object('saga_id', v_saga_id, 'estado', 'fallida', 'paso', 1); END IF;
    IF NOT saga_paso2_acreditar(v_saga_id) THEN RETURN jsonb_build_object('saga_id', v_saga_id, 'estado', 'compensada', 'paso', 2); END IF;
    IF NOT saga_paso3_auditar(v_saga_id)   THEN RETURN jsonb_build_object('saga_id', v_saga_id, 'estado', 'compensada', 'paso', 3); END IF;

    RETURN jsonb_build_object('saga_id', v_saga_id, 'estado', 'completada');
END;
$$;

-- ── VISTA DE MONITOREO ────────────────────────────────────────
CREATE OR REPLACE VIEW v_sagas_activas AS
SELECT
    s.saga_id,
    s.tipo_saga,
    s.estado,
    s.paso_actual || '/' || s.pasos_total AS progreso,
    s.payload->>'monto' AS monto,
    s.created_at,
    EXTRACT(MILLISECONDS FROM (now() - s.created_at)) AS duracion_ms,
    COUNT(p.paso_id) AS pasos_ejecutados
FROM saga_orchestrator s
LEFT JOIN saga_pasos p ON p.saga_id = s.saga_id AND p.estado = 'ejecutado'
GROUP BY s.saga_id
ORDER BY s.created_at DESC;

-- ── COMPARACIÓN 2PC vs SAGA ───────────────────────────────────
/*
 DIFERENCIAS CLAVE para documentar:

 2PC:
   + Atomicidad garantizada
   + Rollback automático si falla cualquier fase
   - Bloquea recursos en TODOS los nodos hasta COMMIT
   - Si el coordinador falla: recursos bloqueados indefinidamente
   - No escala más allá de ~10 participantes (latencia acumulativa)

 SAGA:
   + No hay bloqueos inter-nodo: cada paso es una TX local
   + Escala horizontalmente sin límite
   + Compatible con microservicios (cada servicio gestiona su TX local)
   - No hay atomicidad global: se ven estados intermedios
   - Las compensaciones deben ser idempotentes (se pueden ejecutar N veces)
   - Lógica de compensación es responsabilidad del desarrollador
   - Debugging más complejo (múltiples TX independientes)

 CUÁNDO USAR CADA UNO:
   2PC: transacciones cortas, pocos participantes, consistencia crítica (ej: débito bancario)
   SAGA: flujos de negocio largos, microservicios, consistencia eventual aceptable
         (ej: proceso de compra: reservar → cobrar → enviar → notificar)
*/
