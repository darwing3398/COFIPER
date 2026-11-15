# COFIPER — Control Financiero Personal Quincenal en Córdobas (`C$`)

Aplicación móvil multiplataforma desarrollada en **Flutter y Dart** (`com.dsoluciones.cofiper`) para **Android e iOS**, adaptada a **Nicaragua (Córdobas `C$`)** y diseñada para llevar un control claro y sin complicaciones de tus gastos, tarjetas de crédito, préstamos, sueldo fijo y ventas o negocios extras en tus **2 quincenas del mes**.

---

## 1. Mejoras Principales Implementadas

1. **Moneda 100% en Córdobas de Nicaragua (`C$`):**
   - Formateo automático con separador de miles (`C$ 12,500.00`) en todas las pantallas, simuladores, bitácora y reportes.
2. **Interfaz Simplificada y Clara (4 Pestañas Directas):**
   - **Inicio:** Semáforo superior que te dice al instante si estás bien o si te estás excediendo en gastos, 3 botones directos (`+ Venta / Extra`, `+ Sueldo`, `+ Gasto/Deuda`), comparativa clara de **Primera Quincena (Días 1 al 15)** vs **Segunda Quincena (Días 16 al 30)** y botón para **Rehacer Cálculos Ahora**.
   - **Mis Gastos:** Muestra cada tarjeta de crédito, préstamo o gasto del mes, cuánto debes apartar en la **1ra Quincena** y cuánto en la **2da Quincena**, con barra deslizable para ajustar y casillas de `"Ya aparté"` / `"Ya pagué"`.
   - **Ingresos/Ventas:** Separado claramente entre tus **Ventas y Negocios Extras** (hechos en la semana o en el trayecto de la 1ra o 2da quincena) y tu **Sueldo Fijo** (quincenal o mensual).
   - **Asesor IA:** Incluye el evaluador de exceso de gastos rubro por rubro, consejos de mejora actualizados con acceso a Internet, simulador de nuevas cuotas en Córdobas y la bitácora histórica de movimientos.
3. **Registro de Ventas y Negocios Extras en la Semana o Quincena:**
   - Botón directo **`+ Venta / Extra`** para anotar ganancias de ventas, encargos o negocios realizados en la semana, indicando si entraron en el trayecto de la **1ra Quincena (Días 1-15)** o de la **2da Quincena (Días 16-30)**. La app suma ese dinero a esa quincena y recalcula tus pagos automáticamente.
4. **Valoración Automática de Exceso de Gastos + Asesor IA con Internet:**
   - Mide el porcentaje de tus ingresos que se va en **Tarjetas y Préstamos** (máx. saludable 35%), **Gastos Básicos de Casa/Comida** (máx. 50%) y **Gastos Diarios/Hormiga** (máx. 10%), avisándote en rojo exactamente por cuántos **Córdobas (`C$`)** te estás pasando.
   - Cuando el teléfono tiene acceso a Internet (`android.permission.INTERNET` configurado en [AndroidManifest.xml](file:///c:/Users/DSOLUCIONES/Desktop/COFIPER/android/app/src/main/AndroidManifest.xml)), el **Asesor IA** actualiza recomendaciones y metas semanales de ventas/ahorro para nivelar tus quincenas.

---

## 2. Cómo Actualizar la App en tu Teléfono Android

Ejecuta en tu terminal dentro de `c:\Users\DSOLUCIONES\Desktop\COFIPER`:

```powershell
# Si tienes el teléfono conectado por USB:
flutter run --release

# O para generar el nuevo instalador APK en Córdobas:
flutter build apk --release
```
El instalador actualizado quedará en `build/app/outputs/flutter-apk/app-release.apk`.
