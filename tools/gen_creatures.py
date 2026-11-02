#!/usr/bin/env python3
"""Genera data/creatures.json: las 246 especies del documento de
arquitectura, sin recortes. Estructura del documento (seccion 5):
  - Fauna pacifica, de granja y domable: 22 principales + variantes
  - Depredadores y fauna salvaje: 20 principales + variantes por bioma
  - Criaturas fantasticas, subterraneas y jefes: 40 entradas
    (slime x4 tipos, golem x4 tipos, resto unicas)
  - 10 facciones humanoides x 5 roles tacticos = 50
  - Variantes por bioma + 8 unicos con nombre = 114
Total: 22 + 20 + 40 + 50 + 114 = 246.
Los nombres y datos son nuestros, siguiendo las categorias, roles,
temperamentos, biomas y zonas del documento. Nada copiado de otro
juego: las criaturas se dibujan con cubos procedurales propios.
Uso: python3 tools/gen_creatures.py  (escribe data/creatures.json)
"""
import json
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "data", "creatures.json")

# (key, nombre, arquetipo, biomas, comida, montura)
PEACEFUL = [
    ("oveja", "Oveja", "quadruped", ["pradera_verde", "sabana"], "baya", False),
    ("vaca", "Vaca", "quadruped", ["pradera_verde", "sabana"], "trigo", False),
    ("cerdo", "Cerdo", "quadruped", ["pradera_verde", "bosque_magico"], "zanahoria", False),
    ("gallina", "Gallina", "biped", ["pradera_verde"], "semillas", False),
    ("pato", "Pato", "biped", ["rio", "playa_mar"], "semillas", False),
    ("cabra", "Cabra", "quadruped", ["montana_nevada", "pradera_verde"], "hierba", False),
    ("alpaca", "Alpaca", "quadruped", ["montana_nevada"], "hierba", False),
    ("yak", "Yak", "quadruped", ["montana_nevada", "tundra_nevada"], "hierba", False),
    ("caballo", "Caballo", "quadruped", ["pradera_verde", "sabana"], "manzana", True),
    ("camello", "Camello", "quadruped", ["desierto"], "hierba", True),
    ("reno", "Reno", "quadruped", ["tundra_nevada", "montana_nevada"], "hierba", True),
    ("avestruz", "Avestruz", "biped", ["sabana"], "semillas", True),
    ("perro", "Perro", "quadruped", ["pradera_verde", "bosque_magico"], "carne", False),
    ("gato", "Gato", "quadruped", ["pradera_verde", "bosque_magico"], "pescado", False),
    ("loro", "Loro", "avian", ["jungla", "bosque_magico"], "semillas", False),
    ("conejo", "Conejo", "hopper", ["pradera_verde", "bosque_magico"], "zanahoria", False),
    ("ciervo", "Ciervo", "quadruped", ["bosque_magico"], "hierba", False),
    ("capibara", "Capibara", "quadruped", ["rio", "pantano"], "hierba", False),
    ("tortuga", "Tortuga", "quadruped", ["playa_mar", "rio"], "hierba", False),
    ("rana", "Rana", "hopper", ["pantano", "rio"], "mosca", False),
    ("pinguino", "Pingüino", "biped", ["tundra_nevada"], "pescado", False),
    ("delfin", "Delfín", "aquatic", ["oceano"], "pescado", False),
]

# (key, nombre, arquetipo, biomas, temperamento, domable)
PREDATORS = [
    ("lobo", "Lobo", "quadruped", ["bosque_magico", "tundra_nevada"], "aggressive", True),
    ("oso_pardo", "Oso Pardo", "quadruped", ["bosque_magico"], "aggressive", False),
    ("oso_polar", "Oso Polar", "quadruped", ["tundra_nevada"], "aggressive", False),
    ("jabali", "Jabalí", "quadruped", ["bosque_magico"], "neutral", False),
    ("aguila", "Águila", "avian", ["montana_nevada"], "aggressive", False),
    ("leon", "León", "quadruped", ["sabana"], "aggressive", False),
    ("tigre", "Tigre", "quadruped", ["jungla"], "aggressive", False),
    ("pantera", "Pantera", "quadruped", ["jungla"], "aggressive", False),
    ("hiena", "Hiena", "quadruped", ["sabana", "desierto"], "aggressive", False),
    ("cocodrilo", "Cocodrilo", "quadruped", ["pantano", "rio"], "aggressive", False),
    ("escorpion", "Escorpión", "arachnid", ["desierto"], "aggressive", False),
    ("vibora", "Víbora", "serpent", ["desierto", "jungla"], "aggressive", False),
    ("buitre", "Buitre", "avian", ["sabana", "desierto"], "neutral", False),
    ("rinoceronte", "Rinoceronte", "quadruped", ["sabana"], "neutral", False),
    ("hipopotamo", "Hipopótamo", "quadruped", ["rio", "sabana"], "neutral", False),
    ("gorila", "Gorila", "biped", ["jungla"], "neutral", False),
    ("mamut", "Mamut", "quadruped", ["tundra_nevada"], "neutral", False),
    ("tiburon", "Tiburón", "aquatic", ["oceano"], "aggressive", False),
    ("pirana", "Piraña", "aquatic", ["rio", "jungla"], "aggressive", False),
    ("arana_gigante", "Araña Gigante", "arachnid", ["bosque_magico"], "aggressive", False),
]

# (key, nombre, arquetipo, biomas, zonaMin, zonaMax, tiempo)
FANTASTIC = [
    ("slime_limo", "Slime de Limo", "hopper", ["pantano"], 2, 4, "any"),
    ("slime_magma", "Slime de Magma", "hopper", ["tierras_magma"], 4, 6, "any"),
    ("slime_hielo", "Slime de Hielo", "hopper", ["tundra_nevada"], 3, 5, "any"),
    ("slime_veneno", "Slime de Veneno", "hopper", ["pantano_niebla"], 3, 5, "any"),
    ("goblin", "Goblin", "biped", ["bosque_magico"], 2, 4, "any"),
    ("orc", "Orco", "biped", ["montana_nevada"], 2, 4, "any"),
    ("troll", "Troll", "biped", ["montana_nevada"], 3, 5, "any"),
    ("ogre", "Ogro", "biped", ["bosque_magico"], 3, 5, "any"),
    ("skeleton", "Esqueleto", "biped", ["desierto"], 2, 5, "night"),
    ("zombie", "Zombi", "biped", ["pradera_verde"], 2, 4, "night"),
    ("mummy", "Momia", "biped", ["desierto"], 2, 4, "any"),
    ("ghost", "Fantasma", "biped", ["bosque_magico"], 3, 5, "night"),
    ("wraith", "Espectro", "biped", ["suelo_corrupto"], 4, 6, "night"),
    ("vampire", "Vampiro", "biped", ["bosque_magico"], 3, 5, "night"),
    ("werewolf", "Hombre Lobo", "biped", ["bosque_magico"], 3, 5, "night"),
    ("gargoyle", "Gárgola", "biped", ["montana_nevada"], 3, 5, "any"),
    ("mimic", "Mímico", "quadruped", ["desierto"], 2, 4, "any"),
    ("harpy", "Arpía", "avian", ["montana_nevada"], 3, 5, "any"),
    ("minotaur", "Minotauro", "biped", ["desierto"], 3, 5, "any"),
    ("centaur", "Centauro", "quadruped", ["pradera_verde"], 3, 5, "any"),
    ("cyclops", "Cíclope", "biped", ["montana_nevada"], 4, 6, "any"),
    ("golem_piedra", "Gólem de Piedra", "biped", ["montana_nevada"], 3, 5, "any"),
    ("golem_hierro", "Gólem de Hierro", "biped", ["montana_nevada"], 4, 6, "any"),
    ("golem_cristal", "Gólem de Cristal", "biped", ["tierras_cristal"], 4, 6, "any"),
    ("golem_magma", "Gólem de Magma", "biped", ["tierras_magma"], 5, 6, "any"),
    ("ice_elemental", "Elemental de Hielo", "biped", ["tundra_nevada"], 4, 6, "any"),
    ("fire_elemental", "Elemental de Fuego", "biped", ["tierras_magma"], 4, 6, "any"),
    ("treant", "Treant", "biped", ["bosque_magico"], 3, 5, "any"),
    ("basilisk", "Basilisco", "serpent", ["desierto"], 4, 6, "any"),
    ("unicorn", "Unicornio", "quadruped", ["tierras_celestiales"], 4, 6, "any"),
    ("phoenix", "Fénix", "avian", ["tierras_magma"], 5, 6, "any"),
    ("griffin", "Grifo", "avian", ["montana_nevada"], 4, 6, "any"),
    ("wyvern", "Wyvern", "avian", ["montana_nevada"], 4, 6, "any"),
    ("manticore", "Mantícora", "quadruped", ["desierto"], 4, 6, "any"),
    ("hydra", "Hidra", "serpent", ["pantano"], 5, 6, "any"),
    ("kraken", "Kraken", "aquatic", ["oceano"], 5, 6, "any"),
    ("leviathan", "Leviatán", "aquatic", ["oceano"], 6, 6, "any"),
    ("void_stalker", "Acechador del Vacío", "biped", ["jardin_vacio"], 5, 6, "any"),
    ("chrono_warden", "Guardián del Tiempo", "biped", ["tierras_celestiales"], 6, 6, "any"),
    ("titan_colossus", "Coloso Titánico", "biped", ["abismo_cristal"], 6, 6, "any"),
]

# (key, nombre, temperamento, zonaMin, zonaMax)
FACTIONS = [
    ("explorers", "Orden de Exploradores", "passive", 1, 2),
    ("bandits", "Bandidos", "aggressive", 1, 3),
    ("ogres", "Clan Ogro", "aggressive", 2, 4),
    ("undead", "Legión No-Muerta", "aggressive", 3, 5),
    ("cultists", "Culto del Vacío", "aggressive", 4, 6),
    ("pirates", "Corsarios", "aggressive", 1, 3),
    ("frostborn", "Hijos del Hielo", "aggressive", 3, 5),
    ("desert_raiders", "Nómadas del Desierto", "aggressive", 2, 4),
    ("sylvan", "Guardianes Silvanos", "neutral", 1, 3),
    ("infernal", "Hueste Infernal", "aggressive", 5, 6),
]
ROLES = [
    ("warrior", "Guerrero", 1.0),
    ("shieldbearer", "Portaescudos", 1.3),
    ("shooter", "Tirador", 0.9),
    ("caster", "Hechicero", 0.9),
    ("leader", "Capitán", 1.5),
]

VARIANT_BIOMES = ["pradera_verde", "bosque_magico", "playa_mar",
                  "montana_nevada", "sabana", "desierto", "jungla",
                  "tundra_nevada"]
VARIANT_BIOME_NAMES = {
    "pradera_verde": "la Pradera", "bosque_magico": "el Bosque",
    "playa_mar": "la Playa", "montana_nevada": "la Montaña",
    "sabana": "la Sabana", "desierto": "el Desierto",
    "jungla": "la Jungla", "tundra_nevada": "la Tundra",
}
UNIQUES = [
    ("lobo_alfa", "Lobo Alfa", "lobo"),
    ("oso_rey", "Oso Rey", "oso_pardo"),
    ("tiburon_blanco", "Tiburón Blanco", "tiburon"),
    ("arana_reina", "Araña Reina", "arana_gigante"),
    ("golem_anciano", "Gólem Anciano", "golem_piedra"),
    ("fenix_renacido", "Fénix Renacido", "phoenix"),
    ("hidra_menor", "Hidra Menor", "hydra"),
    ("kraken_joven", "Kraken Joven", "kraken"),
]


def entry(key, name, category, archetype, temperament, tameable,
          food, rideable, biomes, time, zone_min, zone_max,
          group, boss=False, faction="", role="", base=""):
    return {
        "id": key, "name": name, "category": category,
        "archetype": archetype, "temperament": temperament,
        "tameable": tameable, "food": food, "rideable": rideable,
        "biomes": biomes, "time": time,
        "zoneMin": zone_min, "zoneMax": zone_max,
        "group": group, "boss": boss,
        "faction": faction, "role": role, "base": base,
    }


def build():
    out = []
    for key, name, arch, biomes, food, ride in PEACEFUL:
        out.append(entry(key, name, "pacifica", arch, "passive", True,
                          food, ride, biomes, "any", 1, 2, [3, 6]))
    for key, name, arch, biomes, temp, tame in PREDATORS:
        food = "carne" if tame else ""
        out.append(entry(key, name, "depredador", arch, temp, tame,
                          food, False, biomes, "any", 1, 3, [1, 5]))
    for key, name, arch, biomes, zmin, zmax, time in FANTASTIC:
        tame = key == "unicorn"
        temp = "passive" if key == "unicorn" else (
            "neutral" if key == "treant" else "aggressive")
        boss = key in ("titan_colossus", "kraken", "leviathan",
                       "chrono_warden", "void_stalker", "hydra")
        ride = key in ("griffin", "wyvern")
        out.append(entry(key, name, "fantastica", arch, temp, tame,
                          "manzana" if tame else "", ride, biomes,
                          time, zmin, zmax, [1, 1], boss=boss))
    for fkey, fname, temp, zmin, zmax in FACTIONS:
        for rkey, rname, scale in ROLES:
            out.append(entry(
                f"{fkey}_{rkey}", f"{rname} {fname}", "faccion",
                "biped", temp, False, "", False,
                ["pradera_verde", "bosque_magico", "desierto",
                 "tundra_nevada"], "any", zmin, zmax, [2, 5],
                boss=(rkey == "leader"), faction=fkey, role=rkey))
    # Variantes por bioma: 22 pacificas x3 + 20 depredadores x2 = 106
    for i, (key, name, arch, biomes, food, ride) in enumerate(PEACEFUL):
        for j in range(3):
            b = VARIANT_BIOMES[(i + j * 3) % len(VARIANT_BIOMES)]
            out.append(entry(
                f"{key}_{b}", f"{name} de {VARIANT_BIOME_NAMES[b]}",
                "pacifica", arch, "passive", True, food, ride,
                [b], "any", 1, 3, [2, 5], base=key))
    for i, (key, name, arch, biomes, temp, tame) in enumerate(PREDATORS):
        for j in range(2):
            b = VARIANT_BIOMES[(i + j * 3 + 1) % len(VARIANT_BIOMES)]
            out.append(entry(
                f"{key}_{b}", f"{name} de {VARIANT_BIOME_NAMES[b]}",
                "depredador", arch, temp, tame,
                "carne" if tame else "", False, [b], "any", 1, 4,
                [1, 4], base=key))
    for key, name, base in UNIQUES:
        out.append(entry(key, name, "unico", "biped", "aggressive",
                          False, "", False, ["bosque_magico"], "any",
                          3, 6, [1, 1], boss=True, base=base))
    return out


def main():
    creatures = build()
    assert len(creatures) == 246, f"conteo {len(creatures)} != 246"
    ids = [c["id"] for c in creatures]
    assert len(set(ids)) == 246, "ids duplicados"
    data = {
        "version": 1,
        "count": 246,
        "nota": ("Catalogo de criaturas 3.0 segun la seccion 5 del "
                 "documento de arquitectura: 22 pacificas + 20 "
                 "depredadores + 40 fantasticas/jefes + 50 de "
                 "facciones (10 x 5 roles) + 106 variantes por bioma "
                 "+ 8 unicos con nombre = 246. Nombres y datos "
                 "propios; las criaturas se dibujan con cubos "
                 "procedurales, no con modelos .vox ajenos."),
        "creatures": creatures,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print(f"creatures.json: {len(creatures)} especies")


if __name__ == "__main__":
    main()
