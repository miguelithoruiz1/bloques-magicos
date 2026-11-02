# Bloques Mágicos 🧱 — 3.0.2

Juego de construcción con cubos en 3D, tipo Minecraft, para **aprender jugando
a cualquier edad (5 a 60+ años)**: construir, palabras, números y operaciones,
misiones, criaturas amigas, cuevas, forja y multijugador en red local.

- **Motor:** Godot **4.3** (GDScript). Escena principal: `scenes/refactor_main.tscn`.
- **Paquete Android:** `com.miguelitho.bloquesmagicos` (TV y celular, horizontal).
- **Sin internet, sin cuentas, sin anuncios, sin compras.** El multijugador es
  solo en red local (Wi-Fi de la casa), sin servidores.
- **El repo contiene solo código y datos.** Los APK (TV y celular), los audios
  `.ogg` de voces familiares y el `export_presets.cfg` (contiene datos del
  keystore) **no** están aquí: los APK se distribuyen desde Drive.

> Estado: **3.0.2** — TV con mando a distancia funcional (título con foco,
> OK pone bloque, Atrás abre la pausa) y celular sin botones encimados
> (columnas ancladas encima de la hotbar, rejilla en pantallas cortas).

## Qué trae la 3.0

- **20 misiones** «Aventuras para empezar» (construir, domar un amigo, palabras,
  cuentas, explorar, noche de antorchas…), cada una 1 estrella + 15 EXP.
- **Niveles y EXP, estaciones del año** (cada 5 días) y **zonas 1–6** según la
  distancia del inicio.
- **41 biomas**: 11 base (pradera, playa, bosque, nieve…) + 26 especiales por
  anillos de distancia + 4 de mundos anteriores. Clima por estación, pájaros
  ambiente y música procedural distinta por grupo de bioma.
- **173 bloques** en 8 categorías (suelos, rocas, minerales, maderas,
  construcción, fluidos, flora, trampas): vetas subterráneas por profundidad
  (carbón, cobre, estaño, hierro, plata, oro, azufre, yeso, cronolita) y
  **roca madre indestructible** en el fondo.
- **246 criaturas en catálogo** (`data/creatures.json`): pacíficas, depredadores,
  fantásticas, 10 facciones × 5 roles y 8 únicos. En el mundo viven
  **16 animales amigos** con domesticación (acercarse agachado + su comida
  favorita), manadas, huida, persecución y **montura de caballo**; en
  **Luna Carmesí** (cada 8 noches) llega la horda.
- **Combate y vitales**: salud, maná, estamina, oxígeno y temperatura; ataque
  cuerpo a cuerpo y onda con maná, esquiva con i-frames, jefes con 3 fases.
- **6 razas** (humano, elfo, enano, orco, hombre rana, gólem) con efectos reales,
  **forja de escultura** (acero y espadas con espíritu) y **personaje separado
  del mundo** (equipo, materiales, espíritus, pociones, monedas, habilidades).
- **8 estaciones de artesanía**: mano, mesa de trabajo, horno, yunque,
  yunque titán, telar, olla y mesa de alquimia, además de la forja.
- **Cuevas en 3 estratos** (con temas de cristal, hongos y magma) y estructuras
  (torre, obelisco, portal, árbol, ruina). Se entra picando hacia abajo o volando.
- **Taller** de crafteo, **minimapa**, línea de stats (nivel, EXP, día, estación,
  zona, clima) y **bandas de edad 5–7 / 8–12 / 13+**: las palabras y operaciones
  se abren por banda (el bloque ÷ solo aparece en 13+).
- **Editor TouchHud** (Ajustes → Táctil): tamaño y opacidad de botones, y modo
  «Mover botones» con asa ⠿ para arrastrar las columnas de acciones.
- **Multijugador LAN** (UDP puerto 27016, 1–7 jugadores): descubrimiento por
  broadcast, entrada fiable, posiciones en vivo y bloques sincronizados. Al
  entrar se recibe la foto de los bloques modificados del anfitrión.
- La **Plaza y los niveles de 1.15.0** siguen intactos («Volver a la Plaza»).

## Controles

### Con el control del TV (mando a distancia: cruceta, OK, Atrás)

| Acción | Botón |
|---|---|
| Moverse | Cruceta |
| Elegir en menús y título | Cruceta + **OK** (el título arranca con foco en «Jugar») |
| Poner bloque | **OK** |
| Abrir/cerrar pausa, cerrar paneles | **Atrás** |
| Girar la cámara | Mando con stick derecho, si está conectado |

### Con mando (gamepad)

| Acción | Botón |
|---|---|
| Moverse | Stick izquierdo o cruceta |
| Poner bloque | **A** / Cross |
| Quitar bloque | **B** / Circle |
| Saltar / Agacharse | **A** / **B** |
| Inventario | **X** / Square |
| Cambiar bloque de la hotbar | **LB / RB** |
| Girar la cámara | Stick derecho |

### Con pantalla táctil (celular o tableta)

Joystick izquierdo para moverse, botones de acción a la derecha (poner, quitar,
saltar, agacharse, perspectiva, montura, ataque, esquiva, forja, estaciones,
personaje, poción, comida, LAN), hotbar abajo y minimapa arriba a la derecha.
En **Ajustes → Táctil** se cambian tamaño, opacidad y posición de los botones.

### Con teclado (para probar en el PC)

Flechas o WASD mueven · **Espacio/Enter** pone · **X/Supr/Retroceso** quita.

## Abrir el proyecto en Godot 4.3

1. Descarga **Godot 4.3** (versión exacta 4.3-stable) desde
   [godotengine.org](https://godotengine.org/download/).
2. Abre Godot → **Importar** → selecciona el `project.godot` de esta carpeta.
3. Pulsa **Ejecutar** (F5) para jugar en el PC con teclado.

## Exportar el APK

El preset de exportación **no** está en el repo (contiene datos del keystore).
Para exportar, crea un preset **Android** en tu Godot con:

- Paquete: `com.miguelitho.bloquesmagicos`
- Arquitecturas: `arm64-v8a` + `armeabi-v7a`
- Versión: la de `project.godot` (`config/version` y `config/version_code`)

Para TV, el APK lleva además categoría `LEANBACK_LAUNCHER` y banner
(`android:banner`), que se añaden al manifiesto tras exportar. La firma de
depuración (`androiddebugkey`) instala encima de las versiones anteriores y
conserva el progreso.

## Estructura del proyecto

```
bloques-magicos/
├── project.godot            # Configuración (4.3) y mapa de entradas
├── README.md                # Este archivo
├── data/
│   ├── blocks.json          # Catálogo de 173 bloques (generado por tools/gen_blocks.py)
│   └── creatures.json       # Catálogo de 246 criaturas (generado por tools/gen_creatures.py)
├── scenes/
│   ├── refactor_main.tscn   # Escena principal (mundo 3.0)
│   ├── touch_and_tv_controls.tscn  # HUD táctil / TV
│   └── settings_refactor.tscn      # Ajustes
├── scripts/
│   └── refactor/
│       ├── refactor_main.gd        # Título, pausa, mundo, combate, LAN, personaje
│       ├── ui_controller.gd        # HUD, hotbar, modales, editor TouchHud
│       ├── voxel_world_generator.gd# Terreno, biomas, cuevas, vetas, estructuras
│       ├── friendly_animal.gd      # IA: doma, huida, persecución, montura
│       ├── horde_system.gd         # Hordas y Luna Carmesí
│       ├── vitals.gd               # Salud, maná, estamina, oxígeno, temperatura
│       ├── character.gd            # Personaje separado del mundo
│       ├── sculpting_forge.gd      # Forja de escultura
│       ├── stations.gd             # 8 estaciones de artesanía
│       ├── quest_system.gd         # 20 misiones
│       ├── level_system.gd         # Niveles, EXP, estaciones, zonas
│       ├── lan_net.gd              # Multijugador LAN (UDP 27016)
│       ├── music_system.gd         # Música procedural por bioma
│       └── minimap.gd              # Minimapa
├── tests/
│   └── refactor/
│       ├── test_3_0.gd       # Pruebas 3.0 (lógica, sin escena)
│       ├── test_3_0_scene.gd # Pruebas 3.0 instanciando la escena
│       └── test_2_0.gd       # Pruebas 2.0 (compatibilidad)
├── tools/
│   ├── gen_blocks.py         # Genera data/blocks.json
│   └── gen_creatures.py      # Genera data/creatures.json
└── audio/                    # Solo archivos .import: los .ogg van en el APK
```

## Notas honestas

- **LAN**: el protocolo está probado en headless (descubrimiento, entrada,
  estado, bloques fiables, snapshot). La partida real entre dos dispositivos
  (celular + TV en la misma Wi-Fi) queda por probar en casa.
- **Fauna**: el catálogo de 246 existe en datos y el mundo tiene 16 amigos +
  hordas; todavía no hay un spawner de las 246 especies con visuales por
  arquetipo ni facciones con roles caminando por el mundo.
- **Voces**: los clips `.ogg` grabados por la familia no están en el repo; si
  un clip no existe, el juego muestra el texto y sigue en silencio.
- **Minería**: quitar un bloque es instantáneo (el documento pedía tiempo por
  dureza); la luz es la del sol, sin flood-fill por antorchas.

## Historial

- **1.15.0**: mundo libre, niveles guiados (colores, números, letras, sumas).
- **2.0.2**: variante refactor (mundo con biomas, animales amigos, avatar,
  ala delta) con HUD corregido.
- **3.0.0**: 20 misiones, niveles, taller, 41 biomas, 246 criaturas (datos).
- **3.0.1**: 173 bloques, IA completa, combate y vitales, razas, forja,
  estaciones, cuevas, música, LAN.
- **3.0.2**: TV con mando a distancia funcional y celular sin botones encimados.
