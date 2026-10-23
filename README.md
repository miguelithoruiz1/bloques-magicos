# Bloques Mágicos 🧱

Constructor de bloques 3D tipo Minecraft, **educativo y seguro para un niño de 5 años**.
Mundo de pradera con cuadrícula de 16×16 donde se ponen y quitan cubos de colores
y cubos con números, con voz en español que nombra cada bloque al colocarlo.

- **Motor:** Godot **4.3** (GDScript), renderizador *GL Compatibility* (pensado para hardware modesto, como un stick de TV).
- **Paquete Android:** `com.miguelitho.bloquesmagicos`
- **Sin red, sin anuncios, sin cuentas, sin compras.** Todo funciona sin conexión.
- **Plataformas:** Android y Google TV (APK), orientación horizontal.

> Estado: **Fase 1** — construir libre, guardar automático y controles de mando + táctil.

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

### Con mando (gamepad / control de TV)

| Acción | Botón |
|---|---|
| Mover el cursor | Stick izquierdo o cruceta (D-pad) |
| Poner bloque | **A** / Cross (✕) |
| Quitar bloque | **B** / Circle (○) |
| Subir el cursor (altura) | Gatillo derecho (RT) o RB |
| Bajar el cursor (altura) | Gatillo izquierdo (LT) o LB |
| Girar la cámara | Stick derecho (izquierda / derecha) |

La cámara orbital sigue al cursor con un giro suave. El cursor se mueve
relativo a la cámara (redondeado a 90°), así «hacia adelante» siempre es
hacia donde se está mirando.

### Con pantalla táctil (celular o tableta)

| Acción | Cómo |
|---|---|
| Mover el cursor | Tocar el suelo o un bloque (el fantasma salta ahí; si tocas la parte de arriba de un bloque, el cursor sube sobre él) |
| Poner / Quitar | Botones grandes **Poner** y **Quitar** |
| Subir / Bajar el cursor | Botones **Subir** y **Bajar** |
| Girar la cámara | Arrastrar el dedo sobre la pantalla, o mantener **Girar ← / →** |

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
          godot --headless --export-release "Android" "build/${EXPORT_NAME}.apk"

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
- **Sin emulación cruzada:** `emulate_mouse_from_touch` y
  `emulate_touch_from_mouse` están desactivados en `project.godot` para que
  un toque no se procese dos veces.
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
