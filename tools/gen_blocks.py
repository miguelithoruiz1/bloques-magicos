#!/usr/bin/env python3
"""Genera data/blocks.json v2: el catalogo de bloques 3.0 segun
la seccion 4 del documento de arquitectura (160+ bloques).
Conserva las 18 entradas existentes (ids 0-93 del generador:
hierba, tierra, piedra, madera, hojas, agua, arena, flores,
antorcha, cofre, portal, tablones, ladrillo, vidrio, nieve,
cristal brillo) y anade las del documento que no existen, con
ids desde 100, en 8 categorias: suelos, rocas, minerales,
madera, construccion, fluidos, flora y trampas.
Los nombres, colores y datos son nuestros; el documento da
las categorias, las bandas de vetas y las durezas de
referencia (piedra 1.5, hojas 0.2, roca madre -1).
Uso: python3 tools/gen_blocks.py  (reescribe data/blocks.json)
"""
import json
import os

HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "..", "data", "blocks.json")

# (key, nombre, color, dureza, forma, luz, sonido, categoria)
NEW = [
    # Suelos (16): el documento lista 20; hierba, tierra, arena
    # y nieve ya existen con ids 1, 2, 7 y 87.
    ("clay", "Arcilla", [0.72, 0.55, 0.45], 0.6, "solid", 0, "dirt", "suelos"),
    ("mud", "Barro", [0.45, 0.32, 0.22], 0.5, "solid", 0, "dirt", "suelos"),
    ("red_sand", "Arena roja", [0.80, 0.50, 0.30], 0.45, "solid", 0, "sand", "suelos"),
    ("gravel", "Grava", [0.55, 0.52, 0.50], 0.7, "solid", 0, "stone", "suelos"),
    ("snow_grass", "Hierba nevada", [0.65, 0.80, 0.65], 0.55, "solid", 0, "snow", "suelos"),
    ("savanna_grass", "Hierba de sabana", [0.65, 0.70, 0.30], 0.55, "solid", 0, "grass", "suelos"),
    ("jungle_grass", "Hierba de jungla", [0.15, 0.55, 0.25], 0.55, "solid", 0, "grass", "suelos"),
    ("autumn_grass", "Hierba otoñal", [0.75, 0.55, 0.20], 0.55, "solid", 0, "grass", "suelos"),
    ("bog_mud", "Lodo de pantano", [0.35, 0.28, 0.20], 0.5, "solid", 0, "dirt", "suelos"),
    ("peat", "Turba", [0.30, 0.22, 0.15], 0.5, "solid", 0, "dirt", "suelos"),
    ("mycelium", "Micelio", [0.55, 0.45, 0.55], 0.6, "solid", 0, "dirt", "suelos"),
    ("ash_block", "Ceniza", [0.45, 0.45, 0.45], 0.4, "solid", 0, "sand", "suelos"),
    ("salt_crust", "Costra de sal", [0.95, 0.95, 0.90], 0.4, "solid", 0, "snow", "suelos"),
    ("permafrost", "Permafrost", [0.70, 0.75, 0.80], 0.8, "solid", 0, "snow", "suelos"),
    ("celestial_turf", "Césped celestial", [0.65, 0.80, 1.0], 0.6, "solid", 0, "grass", "suelos"),
    ("corrupted_soil", "Tierra corrupta", [0.30, 0.20, 0.35], 0.6, "solid", 0, "dirt", "suelos"),
    ("moss_block", "Bloque de musgo", [0.25, 0.55, 0.30], 0.5, "solid", 0, "grass", "suelos"),
    ("path_block", "Camino", [0.65, 0.58, 0.45], 0.6, "solid", 0, "dirt", "suelos"),
    # Rocas (27): piedra ya existe con id 3.
    ("cobblestone", "Adoquín", [0.45, 0.45, 0.48], 1.6, "solid", 0, "stone", "rocas"),
    ("mossy_cobble", "Adoquín con musgo", [0.40, 0.48, 0.35], 1.6, "solid", 0, "stone", "rocas"),
    ("granite", "Granito", [0.60, 0.45, 0.40], 1.8, "solid", 0, "stone", "rocas"),
    ("diorite", "Diorita", [0.75, 0.75, 0.75], 1.7, "solid", 0, "stone", "rocas"),
    ("andesite", "Andesita", [0.55, 0.55, 0.58], 1.7, "solid", 0, "stone", "rocas"),
    ("limestone", "Caliza", [0.85, 0.82, 0.70], 1.4, "solid", 0, "stone", "rocas"),
    ("slate", "Pizarra", [0.35, 0.35, 0.40], 1.6, "solid", 0, "stone", "rocas"),
    ("shale", "Esquisto", [0.40, 0.38, 0.35], 1.3, "solid", 0, "stone", "rocas"),
    ("marble", "Mármol", [0.95, 0.95, 0.93], 1.5, "solid", 0, "stone", "rocas"),
    ("travertine", "Travertino", [0.88, 0.80, 0.65], 1.4, "solid", 0, "stone", "rocas"),
    ("chalk", "Tiza", [0.98, 0.98, 0.95], 1.0, "solid", 0, "stone", "rocas"),
    ("basalt", "Basalto", [0.25, 0.25, 0.28], 1.9, "solid", 0, "stone", "rocas"),
    ("obsidian", "Obsidiana", [0.12, 0.10, 0.18], 2.5, "solid", 0, "stone", "rocas"),
    ("sandstone", "Arenisca", [0.85, 0.75, 0.55], 1.3, "solid", 0, "stone", "rocas"),
    ("red_sandstone", "Arenisca roja", [0.75, 0.45, 0.30], 1.3, "solid", 0, "stone", "rocas"),
    ("terracotta", "Terracota", [0.70, 0.45, 0.30], 1.2, "solid", 0, "stone", "rocas"),
    ("terracotta_red", "Terracota roja", [0.65, 0.25, 0.20], 1.2, "solid", 0, "stone", "rocas"),
    ("terracotta_orange", "Terracota naranja", [0.85, 0.50, 0.20], 1.2, "solid", 0, "stone", "rocas"),
    ("terracotta_yellow", "Terracota amarilla", [0.90, 0.75, 0.30], 1.2, "solid", 0, "stone", "rocas"),
    ("terracotta_blue", "Terracota azul", [0.30, 0.45, 0.70], 1.2, "solid", 0, "stone", "rocas"),
    ("terracotta_white", "Terracota blanca", [0.92, 0.90, 0.85], 1.2, "solid", 0, "stone", "rocas"),
    ("glacial_stone", "Piedra glacial", [0.70, 0.85, 0.90], 1.7, "solid", 0, "snow", "rocas"),
    ("dark_stone", "Piedra oscura", [0.20, 0.20, 0.22], 1.8, "solid", 0, "stone", "rocas"),
    ("void_stone", "Piedra del vacío", [0.15, 0.10, 0.25], 2.2, "solid", 0, "stone", "rocas"),
    ("null_stone", "Piedra nula", [0.10, 0.10, 0.10], 2.4, "solid", 0, "stone", "rocas"),
    ("abyssal_rock", "Roca abisal", [0.18, 0.12, 0.20], 2.3, "solid", 0, "stone", "rocas"),
    ("bedrock", "Roca madre", [0.08, 0.08, 0.08], -1.0, "solid", 0, "stone", "rocas"),
    # Minerales (9): vetas subterraneas por bandas de profundidad.
    ("coal_ore", "Mena de carbón", [0.30, 0.30, 0.30], 1.5, "solid", 0, "stone", "minerales"),
    ("copper_ore", "Mena de cobre", [0.75, 0.45, 0.25], 1.6, "solid", 0, "metal", "minerales"),
    ("tin_ore", "Mena de estaño", [0.70, 0.72, 0.75], 1.6, "solid", 0, "metal", "minerales"),
    ("iron_ore", "Mena de hierro", [0.80, 0.65, 0.55], 1.8, "solid", 0, "metal", "minerales"),
    ("silver_ore", "Mena de plata", [0.85, 0.88, 0.90], 2.0, "solid", 0, "metal", "minerales"),
    ("gold_ore", "Mena de oro", [1.0, 0.85, 0.20], 2.2, "solid", 0, "metal", "minerales"),
    ("sulfur", "Azufre", [0.90, 0.80, 0.15], 1.2, "solid", 0, "stone", "minerales"),
    ("gypsum", "Yeso", [0.95, 0.95, 0.90], 1.0, "solid", 0, "stone", "minerales"),
    ("chronolite", "Cronolita", [0.50, 0.30, 0.85], 2.5, "solid", 6, "crystal", "minerales"),
    # Madera (33): 16 especies x tronco+hojas + bambu.
    # Los tablones genericos ya existen con id 84.
    ("oak_trunk", "Tronco de roble", [0.45, 0.30, 0.15], 1.2, "solid", 0, "wood", "madera"),
    ("oak_leaves", "Hojas de roble", [0.15, 0.50, 0.20], 0.2, "solid", 0, "foliage", "madera"),
    ("birch_trunk", "Tronco de abedul", [0.75, 0.70, 0.60], 1.1, "solid", 0, "wood", "madera"),
    ("birch_leaves", "Hojas de abedul", [0.35, 0.65, 0.25], 0.2, "solid", 0, "foliage", "madera"),
    ("pine_trunk", "Tronco de pino", [0.40, 0.26, 0.14], 1.2, "solid", 0, "wood", "madera"),
    ("pine_leaves", "Hojas de pino", [0.10, 0.40, 0.25], 0.2, "solid", 0, "foliage", "madera"),
    ("acacia_trunk", "Tronco de acacia", [0.55, 0.35, 0.20], 1.2, "solid", 0, "wood", "madera"),
    ("acacia_leaves", "Hojas de acacia", [0.45, 0.60, 0.20], 0.2, "solid", 0, "foliage", "madera"),
    ("jungle_trunk", "Tronco de jungla", [0.35, 0.25, 0.12], 1.3, "solid", 0, "wood", "madera"),
    ("jungle_leaves", "Hojas de jungla", [0.10, 0.55, 0.15], 0.2, "solid", 0, "foliage", "madera"),
    ("palm_trunk", "Tronco de palmera", [0.60, 0.45, 0.25], 1.1, "solid", 0, "wood", "madera"),
    ("palm_leaves", "Hojas de palmera", [0.20, 0.65, 0.30], 0.2, "solid", 0, "foliage", "madera"),
    ("mangrove_trunk", "Tronco de mangle", [0.38, 0.28, 0.18], 1.2, "solid", 0, "wood", "madera"),
    ("mangrove_leaves", "Hojas de mangle", [0.15, 0.50, 0.35], 0.2, "solid", 0, "foliage", "madera"),
    ("maple_trunk", "Tronco de arce", [0.50, 0.32, 0.18], 1.2, "solid", 0, "wood", "madera"),
    ("maple_leaves", "Hojas de arce", [0.80, 0.35, 0.15], 0.2, "solid", 0, "foliage", "madera"),
    ("cherry_trunk", "Tronco de cerezo", [0.42, 0.26, 0.20], 1.2, "solid", 0, "wood", "madera"),
    ("cherry_leaves", "Hojas de cerezo", [0.95, 0.65, 0.75], 0.2, "solid", 0, "foliage", "madera"),
    ("willow_trunk", "Tronco de sauce", [0.45, 0.35, 0.22], 1.1, "solid", 0, "wood", "madera"),
    ("willow_leaves", "Hojas de sauce", [0.35, 0.60, 0.35], 0.2, "solid", 0, "foliage", "madera"),
    ("cypress_trunk", "Tronco de ciprés", [0.35, 0.25, 0.15], 1.2, "solid", 0, "wood", "madera"),
    ("cypress_leaves", "Hojas de ciprés", [0.12, 0.35, 0.22], 0.2, "solid", 0, "foliage", "madera"),
    ("darkwood_trunk", "Tronco oscuro", [0.22, 0.15, 0.10], 1.4, "solid", 0, "wood", "madera"),
    ("darkwood_leaves", "Hojas oscuras", [0.15, 0.25, 0.30], 0.2, "solid", 0, "foliage", "madera"),
    ("baobab_trunk", "Tronco de baobab", [0.60, 0.45, 0.30], 1.3, "solid", 0, "wood", "madera"),
    ("baobab_leaves", "Hojas de baobab", [0.30, 0.55, 0.25], 0.2, "solid", 0, "foliage", "madera"),
    ("charred_trunk", "Tronco carbonizado", [0.12, 0.10, 0.10], 1.0, "solid", 0, "wood", "madera"),
    ("charred_leaves", "Hojas carbonizadas", [0.25, 0.15, 0.10], 0.2, "solid", 0, "foliage", "madera"),
    ("primordial_trunk", "Tronco primordial", [0.30, 0.45, 0.25], 1.5, "solid", 0, "wood", "madera"),
    ("primordial_leaves", "Hojas primordiales", [0.20, 0.70, 0.40], 0.2, "solid", 0, "foliage", "madera"),
    ("celestial_trunk", "Tronco celestial", [0.60, 0.70, 0.90], 1.5, "solid", 0, "wood", "madera"),
    ("celestial_leaves", "Hojas celestiales", [0.65, 0.80, 1.0], 0.2, "solid", 0, "foliage", "madera"),
    ("bamboo", "Bambú", [0.45, 0.70, 0.30], 0.8, "solid", 0, "wood", "madera"),
    # Construccion (16): ladrillo generico ya existe con id 85.
    ("stone_bricks", "Ladrillos de piedra", [0.55, 0.55, 0.58], 1.7, "solid", 0, "stone", "construccion"),
    ("cracked_bricks", "Ladrillos agrietados", [0.50, 0.50, 0.52], 1.5, "solid", 0, "stone", "construccion"),
    ("chiseled_stone", "Piedra cincelada", [0.60, 0.60, 0.62], 1.7, "solid", 0, "stone", "construccion"),
    ("sandstone_bricks", "Ladrillos de arenisca", [0.85, 0.75, 0.55], 1.4, "solid", 0, "stone", "construccion"),
    ("roof_tiles", "Tejas", [0.70, 0.30, 0.25], 1.3, "solid", 0, "stone", "construccion"),
    ("polished_granite", "Granito pulido", [0.65, 0.50, 0.45], 1.8, "solid", 0, "stone", "construccion"),
    ("polished_marble", "Mármol pulido", [0.97, 0.97, 0.95], 1.5, "solid", 0, "stone", "construccion"),
    ("polished_basalt", "Basalto pulido", [0.28, 0.28, 0.30], 1.9, "solid", 0, "stone", "construccion"),
    ("dungeon_stone", "Piedra de mazmorra", [0.30, 0.30, 0.35], 2.0, "solid", 0, "stone", "construccion"),
    ("dungeon_floor", "Suelo de mazmorra", [0.38, 0.38, 0.42], 1.8, "solid", 0, "stone", "construccion"),
    ("wood_beam", "Viga de madera", [0.40, 0.26, 0.12], 1.2, "solid", 0, "wood", "construccion"),
    ("thatch", "Paja", [0.85, 0.75, 0.40], 0.4, "solid", 0, "grass", "construccion"),
    ("bone_block", "Bloque de hueso", [0.90, 0.88, 0.80], 1.2, "solid", 0, "stone", "construccion"),
    ("titan_bone", "Hueso titánico", [0.85, 0.82, 0.70], 2.0, "solid", 0, "stone", "construccion"),
    ("titan_ivory", "Marfil titánico", [0.95, 0.93, 0.85], 1.8, "solid", 0, "stone", "construccion"),
    ("draconic_fossil", "Fósil dracónico", [0.70, 0.65, 0.55], 2.0, "solid", 0, "stone", "construccion"),
    # Fluidos, hielo y cristales (11): agua, vidrio y cristal
    # cian ya existen con ids 6, 86 y 88.
    ("lava", "Lava", [1.0, 0.45, 0.10], -1.0, "liquid", 15, "stone", "fluidos"),
    ("poison_sludge", "Lodo venenoso", [0.40, 0.70, 0.20], -1.0, "liquid", 0, "water", "fluidos"),
    ("acid_pool", "Ácido", [0.60, 0.90, 0.30], -1.0, "liquid", 0, "water", "fluidos"),
    ("ice", "Hielo", [0.70, 0.90, 0.95], 0.5, "solid", 0, "snow", "fluidos"),
    ("packed_ice", "Hielo compacto", [0.60, 0.82, 0.90], 0.8, "solid", 0, "snow", "fluidos"),
    ("blue_ice", "Hielo azul", [0.40, 0.70, 0.95], 1.0, "solid", 0, "snow", "fluidos"),
    ("eternal_ice", "Hielo eterno", [0.80, 0.95, 1.0], 1.5, "solid", 0, "snow", "fluidos"),
    ("stygian_ice", "Hielo estigio", [0.20, 0.30, 0.45], 1.5, "solid", 0, "snow", "fluidos"),
    ("vitrified_sand", "Arena vitrificada", [0.75, 0.85, 0.70], 1.0, "solid", 0, "crystal", "fluidos"),
    ("fulgurite", "Fulgurita", [0.65, 0.60, 0.45], 1.4, "solid", 0, "crystal", "fluidos"),
    ("crystal_magenta", "Cristal magenta", [0.95, 0.20, 0.85], 0.8, "solid", 11, "crystal", "fluidos"),
    # Flora (25): flor roja y amarilla ya existen con ids 8 y 9.
    ("tall_grass", "Hierba alta", [0.30, 0.65, 0.30], 0.1, "cross", 0, "grass", "flora"),
    ("fern", "Helecho", [0.20, 0.55, 0.30], 0.1, "cross", 0, "foliage", "flora"),
    ("sunflower", "Girasol", [0.95, 0.80, 0.15], 0.1, "cross", 0, "foliage", "flora"),
    ("lavender", "Lavanda", [0.65, 0.50, 0.85], 0.1, "cross", 0, "foliage", "flora"),
    ("rose_bush", "Rosal", [0.85, 0.20, 0.30], 0.1, "cross", 0, "foliage", "flora"),
    ("blue_flower", "Flor azul", [0.30, 0.50, 0.95], 0.1, "cross", 0, "foliage", "flora"),
    ("white_flower", "Flor blanca", [0.95, 0.95, 0.90], 0.1, "cross", 0, "foliage", "flora"),
    ("purple_flower", "Flor morada", [0.60, 0.30, 0.85], 0.1, "cross", 0, "foliage", "flora"),
    ("berry_bush", "Arbusto de bayas", [0.25, 0.55, 0.25], 0.3, "cross", 0, "foliage", "flora"),
    ("cactus", "Cactus", [0.25, 0.60, 0.30], 0.4, "solid", 0, "foliage", "flora"),
    ("tall_cactus", "Cactus alto", [0.20, 0.55, 0.25], 0.4, "solid", 0, "foliage", "flora"),
    ("flowering_cactus", "Cactus en flor", [0.30, 0.60, 0.30], 0.4, "solid", 0, "foliage", "flora"),
    ("reeds", "Juncos", [0.50, 0.65, 0.30], 0.1, "cross", 0, "grass", "flora"),
    ("lily_pad", "Nenúfar", [0.25, 0.65, 0.30], 0.1, "carpet", 0, "foliage", "flora"),
    ("vine", "Enredadera", [0.20, 0.50, 0.20], 0.1, "cross", 0, "foliage", "flora"),
    ("glow_vine", "Enredadera brillante", [0.30, 0.90, 0.70], 0.1, "cross", 6, "foliage", "flora"),
    ("mushroom_red", "Seta roja", [0.85, 0.25, 0.20], 0.1, "cross", 0, "foliage", "flora"),
    ("mushroom_blue", "Seta azul", [0.30, 0.45, 0.85], 0.1, "cross", 0, "foliage", "flora"),
    ("glow_shroom", "Seta brillante", [0.20, 0.95, 1.0], 0.1, "cross", 11, "foliage", "flora"),
    ("kelp", "Alga", [0.15, 0.50, 0.35], 0.1, "cross", 0, "water", "flora"),
    ("coral_red", "Coral rojo", [0.90, 0.25, 0.25], 0.3, "cross", 0, "stone", "flora"),
    ("coral_pink", "Coral rosado", [0.95, 0.60, 0.70], 0.3, "cross", 0, "stone", "flora"),
    ("coral_blue", "Coral azul", [0.30, 0.55, 0.95], 0.3, "cross", 0, "stone", "flora"),
    ("coral_yellow", "Coral amarillo", [0.95, 0.85, 0.25], 0.3, "cross", 0, "stone", "flora"),
    ("coral_purple", "Coral morado", [0.60, 0.35, 0.85], 0.3, "cross", 0, "stone", "flora"),
    # Trampas y mecanismos (8).
    ("spikes", "Púas", [0.60, 0.60, 0.65], 1.5, "solid", 0, "metal", "trampas"),
    ("dart_trap", "Trampa de dardos", [0.50, 0.45, 0.40], 1.5, "solid", 0, "metal", "trampas"),
    ("flame_jet", "Chorro de llamas", [1.0, 0.50, 0.10], 1.5, "solid", 13, "stone", "trampas"),
    ("poison_vent", "Respiradero venenoso", [0.40, 0.65, 0.25], 1.5, "solid", 0, "metal", "trampas"),
    ("crumbling_floor", "Suelo frágil", [0.55, 0.50, 0.45], 0.3, "slab", 0, "stone", "trampas"),
    ("boulder_spawner", "Generador de rocas", [0.45, 0.42, 0.40], 2.0, "solid", 0, "stone", "trampas"),
    ("pressure_plate", "Placa de presión", [0.65, 0.60, 0.55], 0.8, "slab", 0, "metal", "trampas"),
    ("dungeon_bars", "Barrotes de mazmorra", [0.35, 0.35, 0.38], 1.8, "fence", 0, "metal", "trampas"),
    # Estaciones 3.0 (8), AL FINAL a propósito: añadirlas
    # en medio desplazaría los ids de fluidos, flora y
    # trampas que el código ya referencia (lava 203, baya
    # 222). Bloques colocables que desbloquean sus recetas
    # al estar cerca (documento 7.4). Se fabrican en
    # cadena: la mano hace la mesa, la mesa hace el resto.
    ("workbench", "Mesa de trabajo", [0.55, 0.40, 0.20], 1.2, "solid", 0, "wood", "construccion"),
    ("furnace", "Horno", [0.35, 0.35, 0.38], 1.8, "solid", 0, "stone", "construccion"),
    ("anvil", "Yunque", [0.45, 0.45, 0.48], 1.9, "solid", 0, "stone", "construccion"),
    ("titan_anvil", "Yunque titán", [0.55, 0.45, 0.75], 2.0, "solid", 0, "stone", "construccion"),
    ("loom", "Telar", [0.70, 0.55, 0.35], 1.1, "solid", 0, "wood", "construccion"),
    ("cooking_pot", "Olla de cocina", [0.30, 0.30, 0.32], 1.5, "solid", 0, "stone", "construccion"),
    ("alchemy_table", "Mesa de alquimia", [0.20, 0.60, 0.55], 1.2, "solid", 0, "wood", "construccion"),
    ("sculpting_forge", "Forja de escultura", [0.90, 0.60, 0.10], 2.0, "solid", 0, "stone", "construccion"),
]


def main():
    with open(SRC, encoding="utf-8") as f:
        old = json.load(f)
    blocks = list(old["blocks"])
    used = {int(b["id"]) for b in blocks}
    assert 100 not in used
    by_cat = {}
    key_ids = {}
    next_id = 100
    for key, name, color, hardness, shape, light, sound, cat in NEW:
        entry = {"id": next_id, "key": key, "name": name,
                 "color": color, "hardness": hardness,
                 "shape": shape, "light": light, "sound": sound,
                 "category": cat}
        blocks.append(entry)
        by_cat.setdefault(cat, []).append(next_id)
        key_ids[key] = next_id
        next_id += 1
    data = {
        "version": 2,
        "count": len(blocks),
        "nota": ("Catalogo de bloques 3.0 segun la seccion 4 del "
                 "documento de arquitectura: las 18 entradas "
                 "originales (ids 0-93) mas las del documento "
                 "con ids desde 100, en 8 categorias. Nombres y "
                 "datos propios; nada copiado de otro juego."),
        "blocks": blocks,
    }
    with open(SRC, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print(f"blocks.json v2: {len(blocks)} bloques")
    for cat, ids in by_cat.items():
        print(f"  {cat}: {len(ids)} ids {ids[0]}-{ids[-1]}")
    for key in ("coal_ore", "copper_ore", "tin_ore", "iron_ore",
                "silver_ore", "gold_ore", "sulfur", "gypsum",
                "chronolite", "bedrock", "lava"):
        print(f"  {key} = {key_ids[key]}")


if __name__ == "__main__":
    main()
