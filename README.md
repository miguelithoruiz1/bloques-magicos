# Bloques Mágicos 🧱

Constructor de bloques 3D tipo Minecraft, **educativo y seguro para un niño de 5 años**.
Mundo de pradera con cuadrícula de 16×16 donde se ponen y quitan cubos de colores
y cubos con números, con voz en español que nombra cada bloque al colocarlo.

- **Motor:** Godot **4.3** (GDScript), renderizador *GL Compatibility* (pensado para hardware modesto, como un stick de TV).
- **Paquete Android:** `com.miguelitho.bloquesmagicos`
- **Sin red, sin anuncios, sin cuentas, sin compras.** Todo funciona sin conexión.
- **Plataformas:** Android y Google TV (APK), orientación horizontal.

> Estado: **Fase 1.1** — construir libre, guardar automático y controles
> corregidos: paleta alcanzable con el control del TV (sin puntero) y
> pantalla táctil funcional en el celular (ver «Controles»).

## Qué trae la Fase 1

- Suelo de cuadrícula **16×16** con textura de pradera generada en código, cielo claro, sol con sombras suaves y arbolitos decorativos.
- **Cursor 3D con bloque fantasma** semitransparente (con un leve latido) que muestra dónde va el bloque; se pone rojo si la celda está ocupada.
- Paleta inferior con botones grandes:
  - **6 cubos de colores:** rojo, azul, amarillo, verde, naranja y morado.
  - **5 cubos con números 1–5** (el número se ve en la cara superior y en los 4 lados).
  - **Herramienta Borrar.**
- **Voz (TTS del sistema):** al poner un bloque dice «¡Rojo!» o «¡Tres!». Si el dispositivo no tiene voces de texto a voz, el juego sigue sin error, simplemente en silencio.
- **Sonidos generados en código** (sin archivos externos): «pop» al poner, «toc» al quitar.
- Límites amables: altura máxima de 8 bloques y tope de 600 bloques, con mensajes cariñosos en pantalla (nunca castigos).
- **Guardado automático:** el mundo se guarda solo en `user://mundo.json` cada vez que cambia y se carga al abrir.
- Botón **«Empezar de nuevo» con pulsación larga** (1,5 s con barra de progreso) para que no se borre el mundo por accidente.

## Controles

### Con mando (gamepad)

| Acción | Botón |
|---|---|
| Mover el cursor | Stick izquierdo o cruceta (D-pad) |
| Poner bloque | **A** / Cross (✕) — pulsación corta |
| Quitar bloque | **B** / Circle (○) |
| Subir el cursor (altura) | Gatillo derecho (RT) o RB |
| Bajar el cursor (altura) | Gatillo izquierdo (LT) o LB |
| Girar la cámara | Stick derecho (izquierda / derecha) |

La cámara orbital sigue al cursor con un giro suave. El cursor se mueve
relativo a la cámara (redondeado a 90°), así «hacia adelante» siempre es
hacia donde se está mirando.

### Con el control del TV (sin puntero, sin gatillos)

El control de un stick de TV solo tiene cruceta, **OK** y **Atrás**; por
eso la paleta se maneja con un modo dedicado:

| Acción | Botón |
|---|---|
| Mover el cursor | Cruceta |
| Poner bloque | **OK corto** (soltar antes de 0,35 s) |
| Quitar bloque | **Atrás** |
| **Abrir la paleta** (colores, números 1–5 y Borrar) | **Mantener OK** (≥ 0,35 s) — al mantenerlo NO se coloca ningún bloque |
| Elegir dentro de la paleta | Cruceta ◀ ▶ (la opción resaltada se ve con borde dorado) |
| Subir / Bajar la altura del cursor (con la paleta abierta) | Cruceta ▲ ▼ |
| Confirmar la opción y cerrar la paleta | **OK** |
| Cerrar la paleta sin cambiar nada | **Atrás** |

Mientras la paleta está abierta, el mundo queda en pausa (el cursor no se
mueve ni se colocan bloques). En pantalla se lee siempre la ayuda
«Control TV: mantén OK para elegir color o número» y, con la paleta
abierta, «Eligiendo: …» muestra la opción resaltada antes de confirmar.

### Con pantalla táctil (celular o tableta)

| Acción | Cómo |
|---|---|
| Mover el cursor | Tocar el suelo o un bloque (el fantasma salta ahí; si tocas la parte de arriba de un bloque, el cursor sube sobre él) |
| Poner / Quitar | Botones grandes **Poner** y **Quitar** |
| Subir / Bajar el cursor | Botones **Subir** y **Bajar** |
| Elegir color o número | Tocar directamente los botones de la paleta inferior |
| Girar la cámara | Arrastrar el dedo sobre la pantalla, o mantener **Girar ← / →** |

> En la Fase 1 el tacto no respondía en el celular: `project.godot`
> desactivaba la emulación de ratón desde el tacto y los botones de la
> interfaz (controles GUI) solo reciben eventos de ratón. Desde la
> Fase 1.1 la emulación está activa y todo el tacto entra por un único
> camino (ratón emulado), así botones y mundo responden sin duplicados.

### Con teclado (para probar en el PC)

Flechas o WASD mueven el cursor · **Espacio/Enter** pone · **Supr/X/Retroceso** quita ·
**E/Q** sube/baja · **Z/C** gira la cámara · teclas **1–6** eligen color.

Al quitar: si el cursor está sobre una columna, se quita el bloque del cursor
o el más alto de esa columna (así borrar torres es fácil).

## Abrir el proyecto en Godot 4.3

1. Descarga **Godot 4.3** (versión exacta 4.3-stable) desde [godotengine.org](https://godotengine.org/download/) o GitHub. No uses otra versión: `project.godot` declara `features` de 4.3.
2. Abre Godot → **Importar** → selecciona el `project.godot` de esta carpeta.
3. Pulsa **Ejecutar** (F5) para jugar en el PC con teclado.

La escena principal (`main.tscn`) es mínima a propósito: casi todo el mundo,
la cámara y la interfaz se construyen por código en `scripts/main.gd` y
`scripts/palette_ui.gd`.

## Exportar el APK desde el PC

1. En Godot, ve a **Editor → Administrar plantillas de exportación → Descargar e instalar** (baja las plantillas **4.3** oficiales, ~1 GB).
2. Abre el proyecto y ve a **Proyecto → Exportar…**. Ya existe el preset **«Android»** en `export_presets.cfg`:
   - Paquete: `com.miguelitho.bloquesmagicos`
   - Arquitecturas: `arm64-v8a` + `armeabi-v7a`
   - Sin permiso de internet.
3. Pulsa **Exportar proyecto** y elige la ruta del APK. La exportación de depuración (*debug*) se firma con la clave de depuración y se puede instalar de inmediato.
4. Instala el APK donde quieras:
   - En el celular: cópialo y ábrelo (permite «instalar desde esta fuente»).
   - En el stick de TV (Google TV): envíalo con una app de transferencia o por USB y ábrelo con un explorador de archivos; o por red con `adb install BloquesMagicos.apk`.

**Si la exportación pide algo más:** algunas instalaciones de Godot piden tener
instaladas las herramientas de línea de comandos del SDK de Android y fijar su
ruta en *Editor → Ajustes del editor → Exportar → Android → Ruta del SDK de
Android*. Con eso (y el JDK 17 que trae Android Studio o Temurin) la exportación
del preset sin Gradle (`use_gradle_build=false`) funciona sin proyecto Android Studio.

> **Nota honesta sobre TV:** con el preset estándar el APK se instala y se
> abre sin problema en Google TV, pero para que aparezca **en la fila
> principal de la pantalla de inicio del TV** (categoría `LEANBACK_LAUNCHER`
> y banner de 320×180) hace falta la plantilla de compilación Android
> personalizada (build con Gradle) y declarar el banner. Eso queda como
> **paso de la Fase 2**. Mientras tanto, la app se abre desde
> *Ajustes → Aplicaciones* del TV o con un lanzador de apps instaladas.

## Compilar en la nube: GitHub Actions

El conector no puede subir archivos de `.github/workflows/`, así que este
workflow lo creas tú **una sola vez** desde la web de GitHub:
*Add file → Create new file → `.github/workflows/build-apk.yml`* con este contenido:

```yaml
name: Build Android APK (Godot 4.3)

on:
  push:
    branches: [ main ]
  workflow_dispatch:

env:
  GODOT_VERSION: "4.3"
  EXPORT_NAME: "BloquesMagicos"

jobs:
  export-android:
    runs-on: ubuntu-latest
    steps:
      - name: Descargar el código
        uses: actions/checkout@v4

      - name: Instalar Java 17 (para el keytool)
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - name: Instalar el SDK de Android
        uses: android-actions/setup-android@v3
        with:
          # Sin «tools»: el paquete legado ya no existe en las
          # cmdline-tools nuevas y sdkmanager falla (run 1, 2026-10-23).
          packages: "platform-tools platforms;android-34 build-tools;34.0.0"

      - name: Instalar Godot 4.3 y las plantillas de exportación
        run: |
          wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip
          wget -q https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
          unzip -q Godot_v4.3-stable_linux.x86_64.zip -d godot-bin
          sudo install -m 755 godot-bin/Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot
          mkdir -p ~/.local/share/godot/export_templates/4.3.stable
          unzip -q Godot_v4.3-stable_export_templates.tpz -d /tmp/tpz
          cp -r /tmp/tpz/templates/. ~/.local/share/godot/export_templates/4.3.stable/
          godot --version

      - name: Generar keystore de depuración y apuntarla en el preset
        run: |
          keytool -genkeypair -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
          sed -i 's#keystore/debug=""#keystore/debug="debug.keystore"#' export_presets.cfg
          sed -i 's#keystore/debug_user=""#keystore/debug_user="androiddebugkey"#' export_presets.cfg
          sed -i 's#keystore/debug_password=""#keystore/debug_password="android"#' export_presets.cfg

      - name: Importar el proyecto
        run: godot --headless --import

      - name: Exportar el APK (debug)
        run: |
          mkdir -p build
          # Debe ser --export-debug: el preset solo configura la keystore
          # de depuración; con --export-release Godot busca la de release
          # (vacía) y falla al firmar (corregido en v3, 2026-10-23).
          godot --headless --export-debug "Android" "build/${EXPORT_NAME}.apk"

      - name: Subir el APK como artefacto
        uses: actions/upload-artifact@v4
        with:
          name: app-debug
          path: build/*.apk
```

Con eso, cada push a `main` compila el APK y queda descargable en la pestaña
**Actions** del repositorio (artefacto `app-debug`).

## Estructura del proyecto

```
bloques-magicos/
├── project.godot          # Configuración (4.3) y mapa de entradas (mando/teclado)
├── export_presets.cfg     # Preset Android listo (paquete, arquitecturas, sin internet)
├── main.tscn              # Escena principal mínima: nodo Main con el script
├── icon.svg               # Ícono propio: tres cubos de colores
├── scripts/
│   ├── main.gd            # Mundo, construcción, controles, cámara, voz y sonidos
│   ├── palette_ui.gd      # Paleta, botones táctiles, mensajes y reinicio seguro
│   └── world_save.gd      # Guardado/carga del mundo en user://mundo.json
└── README.md
```

## Decisiones técnicas (Fase 1)

- **Números en los cubos con `Label3D`:** el dígito se coloca en la cara
  superior y en las 4 caras laterales de cada cubo numérico. Es la vía más
  robusta en Godot 4.3 (sin generar texturas ni fuentes especiales) y se lee
  desde cualquier ángulo de la cámara orbital. Los cubos numéricos usan un
  material crema con el dígito en azul oscuro para máximo contraste.
- **Sin física para tocar:** la selección táctil usa una intersección
  rayo–caja calculada a mano contra el diccionario de bloques (máximo 600),
  sin cuerpos de colisión. Rápido en hardware débil y sin sorpresas.
- **Rendimiento:** una sola `BoxMesh` compartida por todos los bloques y un
  material por color; cada bloque es un `MeshInstance3D` (máx. 600 nodos),
  holgado para un stick de TV. Renderizador GL Compatibility, sombras suaves
  de una sola luz direccional.
- **Botones sin foco:** todos los botones de la interfaz usan `FOCUS_NONE`;
  el mando se lee por sondeo de acciones (`Input.is_action_pressed`), así la
  interfaz nunca «roba» los botones del gamepad.
- **Tacto como ratón emulado (Fase 1.1):** `emulate_mouse_from_touch` y
  `emulate_touch_from_mouse` están **activados** en `project.godot`. Los
  botones GUI solo entienden eventos de ratón, así que sin emulación el
  dedo no accionaba ningún botón en Android. Para no procesar nada dos
  veces, `main.gd` ya no escucha los eventos táctiles crudos
  (`InputEventScreenTouch`/`Drag`): ratón real y dedo comparten el mismo
  camino (`InputEventMouseButton`/`Motion`).
- **Paleta sin puntero (Fase 1.1):** la pulsación de OK se mide por
  duración (`_poll_ok` en `main.gd`): corta coloca, larga (≥ 0,35 s)
  abre el modo paleta, donde la cruceta navega las 13 opciones y ▲ ▼
  ajustan la altura. El OK que abre la paleta nunca coloca un bloque.
- **TTS protegido:** se busca una voz cuyo idioma empiece por «es»; si el
  dispositivo no tiene voces, todo el sistema de voz se desactiva en silencio.
- **Guardado defensivo:** al cargar, cada bloque se valida (posición dentro
  de la cuadrícula, tipo y dato en rango). Un archivo corrupto nunca rompe
  el juego: se ignoran las entradas inválidas.
- **Sin `class_name`:** los scripts se precargan (`preload`) desde
  `main.gd`; así la exportación headless no depende de la caché de clases
  globales del editor.

## Solución de problemas

- **No se oye la voz:** el dispositivo no tiene motor de texto a voz o le
  falta una voz en español. En Android: *Ajustes → Accesibilidad → Salida de
  texto a voz* e instala la voz en español. El juego funciona igual sin voz.
- **La exportación falla por la firma:** genera una clave de depuración como
  en el workflow (keytool) y pon su ruta en el preset (*Proyecto → Exportar →
  Android → keystore/debug*) o deja el campo vacío para usar la clave de
  depuración del editor.
- **El APK no aparece en la pantalla principal del TV:** es lo esperado en
  la Fase 1 (ver la nota de TV arriba). Ábrelo desde *Ajustes → Aplicaciones*.
- **El proyecto pide otra versión:** debe abrirse con **Godot 4.3** exacto.

## Hoja de ruta

- **Fase 2 — Aprender jugando:** retos guiados con voz («Pon 3 bloques
  azules», contar los bloques de una torre, cubos con **letras** y primeras
  palabras) + banner e ícono de TV (`LEANBACK_LAUNCHER`) con plantilla
  personalizada.
- **Fase 3 — Más mundo:** piezas nuevas (rampas, ruedas, puertas), mundos
  guardados con nombre (varias creaciones), música suave de fondo y efectos
  de celebración al completar construcciones.

---

## Fase 2 — Mundos y niveles para aprender jugando (2026-10-24)

Al abrir el juego aparece un **menú**: «Jugar libre» (todo lo de F1, intacto)
o «Mundos». El menú se navega con la cruceta + OK del control, con el dedo
o con el teclado, y **la voz lee cada pantalla y cada botón** (el niño no
necesita saber leer para jugar).

### Los 4 mundos (5 niveles cada uno, desbloqueo en orden)

Cada nivel superado da **1 estrella** (20 en total). El siguiente nivel se
abre al superar el anterior. El progreso vive en `user://progreso.json`,
**separado** de `user://mundo.json`: el mundo libre nunca se toca desde los
niveles (el tablero del nivel empieza vacío y no se guarda).

| Mundo | Niveles |
|---|---|
| 🌈 Colores | 1. Pon 2 rojos · 2. Pon 3 azules · 3. La voz pide un color al azar · 4. Pon 4 amarillos · 5. Arcoíris en orden (rojo, naranja, amarillo, verde, azul, morado) |
| 🔢 Números | 1. Pon 3 bloques · 2. Pon 6 bloques · 3. Pon el cubo 4 · 4. Pon el cubo 2 · 5. Números en orden 1→5 |
| 🔤 Letras | 1. La voz pide una vocal al azar · 2. Forma MAMÁ · 3. Forma PAPÁ · 4. Forma SOL · 5. Forma LUNA (cubos con letras nuevos: A, E, I, O, U, M, P, S, T, L, N) |
| ➕ Sumas | 1. 1+1 · 2. 2+1 · 3. 3+2 · 4. 4+3 · 5. 5+5 — la voz pregunta y el niño pone esa cantidad de bloques (la respuesta no se dice) |

Al completar un nivel: voz + cartel «¡Lo lograste! ⭐» y OK vuelve al menú.
Al completar un mundo entero: celebración especial con voz. Borrar corrige:
si el niño pone un bloque de más o equivocado, quitarlo lo descuenta de la
meta. «Empezar de nuevo» dentro de un nivel reinicia solo ese nivel.

### Controles en un nivel

Los mismos de F1.1 (paleta TV con OK sostenido, táctil, teclado). En el
Mundo Letras aparece una segunda fila de paleta con las letras. Botón
«Menú» en la barra superior y botón Atrás del control vuelven al menú
sin tocar el mundo libre.

### Archivos nuevos de F2

- `scripts/menu.gd` + `menu.tscn` — menú inicial (ahora es la escena principal).
- `scripts/levels_data.gd` — tabla de niveles guiada por datos (mundo, tipo
  de meta, parámetros); no hay una escena por nivel.
- `scripts/level_logic.gd` — verificación pura de metas (sin nodos).
- `scripts/progress_save.gd` — estrellas y desbloqueos (`progreso.json`).
- `scripts/game_state.gd` — autoload con el modo (libre/nivel) y el nivel
  elegido. `main.gd` y `palette_ui.gd` ganaron el modo nivel y los cubos
  con letras; el juego libre no cambió de comportamiento.

### Verificación F2 (local, sin subir a GitHub)

Import headless sin errores; 97 pruebas de lógica (tabla, 9 tipos de meta
con éxito y fallo, progreso con round-trip) en verde; smoke de 300 frames
del menú, del juego libre y de niveles de Colores y Letras sin errores de
script; APK exportado con el mismo keystore de depuración de F1.1 y
certificado SHA-256 idéntico (instala encima y conserva el mundo).
