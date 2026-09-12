"""Editable Null ability art matching Outlaw's celestial icon set."""
from pathlib import Path
import math
import random
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/icons/abilities/null"
G = "#dfb77b"
B = "#81d5ff"
R = "#ef697b"
W = "#eee0c8"
D = "#191e2b"
STEEL = "#607a8e"
SHADE = "#344354"
LEATHER = "#65442d"


def path(d, fill="none", stroke=G, width=4):
    return (f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" '
            'stroke-linecap="round" stroke-linejoin="round"/>')


def circle(x, y, radius, fill="none", stroke=G, width=4):
    return (f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{width}"/>')


def star(x, y, radius=18, color=W):
    inner = radius * .22
    return path(
        f"M{x} {y-radius} L{x+inner} {y-inner} L{x+radius} {y} "
        f"L{x+inner} {y+inner} L{x} {y+radius} L{x-inner} {y+inner} "
        f"L{x-radius} {y} L{x-inner} {y-inner} Z", color, color, 1,
    )


def group(body, x=128, y=128, angle=0, scale=1, opacity=1):
    return (f'<g transform="translate({x} {y}) rotate({angle}) scale({scale}) '
            f'translate(-128 -128)" opacity="{opacity}">{body}</g>')


def knife(accent=B):
    """Slender, faceted dagger pointing up; transforms define the attack."""
    return (
        path("M117 166 L139 166 L137 200 L128 208 L119 200 Z", LEATHER, G, 4)
        + path("M119 178 L137 174 M120 189 L136 185", "none", W, 2)
        + path("M110 148 L128 48 L146 148 L133 164 L123 164 Z", STEEL, W, 4)
        + path("M128 55 L128 159 L115 147 Z", "#a2b4bc", "none", 0)
        + path("M128 73 L136 142 L128 154", "none", accent, 2.5)
        + path("M100 157 Q128 169 156 157 L152 167 Q128 175 104 167 Z", LEATHER, G, 3)
        + circle(128, 166, 5, D, G, 2)
        + star(128, 166, 3.5, W)
    )


def cowl():
    """Folded hood with a covered face and narrow eye slit."""
    return (
        path("M128 46 Q155 50 179 84 L191 139 L210 189 "
             "L166 203 L128 192 L90 203 L46 189 L65 139 L77 84 Z", SHADE, G, 4)
        + path("M128 49 L107 96 L81 142 L72 184 L49 188 L66 136 L79 84 Z", "#526577", "none", 0)
        + path("M128 49 L155 89 L175 148 L187 186 L207 189 L189 137 L177 85 Z", "#242d3c", "none", 0)
        + path("M128 74 L158 106 L174 148 L155 178 L128 190 "
               "L101 178 L82 148 L98 106 Z", "#0b101c", W, 3)
        + path("M90 139 L128 147 L166 139 L155 169 L128 184 L101 169 Z", "#3d5062", G, 2.5)
        + path("M97 123 L119 128 M137 128 L159 123", "none", B, 3.5)
        + path("M103 148 L127 157 L152 148 M128 157 L128 176", "none", "#71889b", 2)
        + path("M91 187 L78 174 M165 187 L178 174", "none", W, 2.5)
    )


def boot():
    return (
        path("M89 60 L141 65 L137 119 L146 140 Q156 151 174 155 "
             "L189 160 Q203 165 201 182 L196 190 L92 190 L80 180 "
             "L85 150 L88 118 Z", SHADE, W, 4)
        + path("M88 68 L140 73 L139 85 L88 80 Z", LEATHER, G, 3)
        + path("M99 86 L128 89 L124 132 L103 148 L90 148 L95 118 Z", STEEL, "none", 0)
        + path("M104 137 L136 143 L140 156 L112 162 L94 154 Z", LEATHER, G, 3)
        + path("M119 143 L129 145 L127 154 L117 152 Z", D, W, 2)
        + path("M87 178 Q130 182 200 178 L196 190 L92 190 L81 181 Z", LEATHER, G, 3)
        + path("M88 190 L88 198 L110 198 L113 191 M126 191 L193 191", "none", G, 4)
        + path("M146 158 L141 166 M159 163 L155 171", "none", W, 2.5)
    )


art = {}
# A sharp thrust crosses a broken clock dial; time remains the secondary motif.
ticks = ""
for angle in (15, 45, 75, 135, 165, 195, 225, 255, 315, 345):
    a = math.radians(angle)
    ticks += path(f"M{128+68*math.cos(a):.2f} {125+68*math.sin(a):.2f} "
                  f"L{128+75*math.cos(a):.2f} {125+75*math.sin(a):.2f}", "none", G, 2)
art["stab"] = (
    path("M69 164 A69 69 0 0 1 152 61 M187 86 A69 69 0 0 1 104 189", "none", G, 3)
    + ticks
    + path("M51 186 L76 161 M47 170 L62 155 M83 206 L103 186", "none", B, 3)
    + group(knife(), 129, 128, 42, .99)
    + star(198, 58, 17, B)
    + star(209, 91, 7)
)
# A rear shoulder silhouette; red converges at the blade entry.
art["backstab"] = (
    path("M66 205 L70 157 Q74 143 99 137 L107 121 "
         "Q89 105 94 81 Q97 57 121 57 Q146 56 153 81 "
         "Q159 104 140 122 L147 137 Q170 143 175 161 L181 205 Z", SHADE, G, 4)
    + path("M121 60 Q103 68 103 91 Q102 106 116 120 L111 143 "
           "L84 157 L78 201 L68 204 L72 158 L101 139 L108 120 "
           "Q91 103 96 80 Q100 60 121 60 Z", STEEL, "none", 0)
    + path("M96 151 Q120 164 145 151 M121 164 L121 194", "none", "#849aaa", 2.5)
    + path("M192 53 Q216 103 172 142", "none", R, 4)
    + group(knife(R), 154, 119, -140, .72)
    + star(127, 157, 21, R)
    + star(127, 157, 9, W)
    + path("M103 173 L93 183 M150 168 L161 178", "none", R, 3)
)
art["kick"] = (
    path("M43 169 Q30 119 62 74", "none", G, 3)
    + path("M46 181 Q27 137 38 110", "none", B, 2)
    + group(boot(), 117, 133, -24, .96)
    + star(207, 141, 23, B)
    + star(207, 141, 10, W)
    + path("M196 104 L202 87 M226 122 L237 114 M223 166 L232 178", "none", G, 3)
)
# Neck pressure point and binding arcs.
art["nerve_lock"] = (
    path("M74 205 L79 172 Q84 154 109 147 L114 122 "
         "Q98 110 99 94 L98 74 Q98 51 123 47 Q148 47 155 69 "
         "L156 87 L167 100 L156 106 L154 122 L140 124 "
         "L142 144 Q174 151 184 174 L188 205 Z", SHADE, W, 4)
    + path("M123 49 Q106 64 110 90 L117 118 L126 125 "
           "L120 153 Q98 162 94 201 L77 203 L82 173 Q88 157 111 149 "
           "L115 123 Q101 112 101 93 L100 75 Q99 53 123 49 Z", STEEL, "none", 0)
    + path("M115 161 Q141 173 161 159 M143 170 L157 201", "none", G, 3)
    + path("M62 106 Q85 129 115 137 M58 123 Q74 147 105 153", "none", B, 4)
    + circle(121, 136, 20, D, R, 3)
    + star(121, 136, 13, R)
    + star(121, 136, 5, W)
    + path("M137 114 L149 105 M143 139 L167 138 M134 157 L147 171", "none", R, 3)
)
art["stealth"] = (
    path("M59 164 A80 80 0 0 1 149 47", "none", B, 3)
    + group(cowl(), 128, 129, 0, .93)
    + path("M47 187 Q101 209 170 186 M78 206 Q135 214 193 188", "none", B, 3)
    + star(192, 67, 13, W)
    + star(208, 90, 6, G)
)
# Winged greave; quickness expressed as equipment and motion.
art["haste"] = (
    path("M120 108 Q92 68 49 51 L58 87 L78 108 L58 100 "
         "Q66 128 101 144 L120 144 Z", STEEL, W, 4)
    + path("M57 65 L108 120 M62 88 L95 111 M76 114 L109 133", "none", G, 3)
    + group(boot(), 150, 137, 12, .69)
    + path("M41 166 L87 166 M31 181 L98 181 M49 197 L77 197", "none", B, 4)
    + path("M169 44 L156 64 L178 63 L165 88", "none", B, 4)
    + star(205, 76, 12, G)
)
# A shadow leaving a portal while a blade arrives from its flank.
art["blindside"] = (
    path("M75 203 Q49 163 59 110 Q66 60 101 48 Q134 38 154 75", "none", B, 4)
    + group(cowl(), 100, 127, -8, .64)
    + path("M63 182 Q102 194 133 164 M70 194 Q113 197 147 171", "none", B, 2.5)
    + path("M129 184 Q192 181 205 118", "none", G, 4)
    + path("M199 143 L205 117 L215 138", "none", G, 4)
    + group(knife(), 177, 121, 32, .7)
    + star(212, 62, 13, B)
    + path("M42 139 L34 139 M48 154 L35 154 M53 169 L43 169", "none", B, 3)
)
# An inverted blade drops to a marked point, framed by vertical star trails.
art["vantage_point"] = (
    path("M62 185 L108 168 L156 177 L196 196 L150 214 L106 205 Z", "#242d3b", G, 3)
    + path("M63 186 L107 193 L150 214 M107 193 L154 178", "none", "#6b604f", 2)
    + path("M82 57 L82 112 M174 61 L174 115 M65 94 L65 134 M191 99 L191 139", "none", B, 3)
    + group(knife(), 128, 118, 180, .95)
    + star(128, 195, 24, B)
    + star(128, 195, 10, W)
    + star(82, 62, 10, G)
    + star(174, 77, 7, W)
)
# Outlaw's glass, cork, brass and astral-liquid vocabulary.
art["regen_pot"] = (
    path("M110 65 L146 65 L147 98 Q178 117 178 147 "
         "L173 184 Q165 205 129 208 Q93 205 84 184 L79 147 "
         "Q80 117 109 98 Z", "#2e5967", G, 4)
    + path("M110 69 L109 99 Q86 120 87 140 L90 178", "none", W, 3)
    + path("M89 151 Q111 132 137 146 Q157 158 169 146 "
           "L165 181 Q154 198 129 199 Q103 197 94 182 Z", "#68adb3", B, 2)
    + path("M91 162 Q125 180 166 159", "none", "#a7d6d5", 2)
    + path("M106 47 L149 47 L153 68 L102 68 Z", LEATHER, W, 3)
    + path("M103 78 L154 78 L153 90 L104 90 Z", LEATHER, G, 3)
    + path("M115 49 L115 60 M139 50 L141 60", "none", G, 2)
    + circle(129, 86, 5, D, G, 2)
    + star(129, 153, 23, W)
    + star(104, 182, 6, W)
    + circle(148, 127, 4, "none", B, 2)
    + path("M194 61 L194 89 M180 75 L208 75", "none", B, 4)
    + star(62, 111, 10, G)
)
# An hourglass suspended in a rewind orbit.
art["chronoshift"] = (
    path("M65 173 A80 80 0 1 1 202 160", "none", B, 4)
    + path("M77 157 L63 177 L44 163", "none", B, 4)
    + path("M79 207 Q139 237 189 187", "none", G, 3)
    + path("M92 70 L164 70 L163 86 Q157 110 139 125 "
           "Q158 143 163 166 L164 181 L92 181 L93 166 "
           "Q98 143 117 125 Q98 110 93 86 Z", "#253b4e", W, 3)
    + path("M101 87 Q127 97 155 87 Q147 108 128 120 Q109 108 101 87 Z", "#68adb3", B, 2)
    + path("M103 173 Q114 157 128 151 Q142 157 153 173 Z", "#9c713c", G, 2)
    + path("M128 128 L128 145", "none", G, 3)
    + path("M84 62 L172 62 L172 75 L84 75 Z", LEATHER, G, 3)
    + path("M84 178 L172 178 L172 191 L84 191 Z", LEATHER, G, 3)
    + path("M87 79 L87 174 M169 79 L169 174", "none", G, 3)
    + star(128, 124, 13, W)
    + star(196, 180, 13, G)
    + star(66, 55, 8, W)
)


def render(body):
    rng = random.Random(122)
    specks = "".join(
        circle(rng.randint(24, 232), rng.randint(24, 232), rng.choice([.6, 1, 1.4]),
               "#8193b5", "none", 0)
        for _ in range(35)
    )
    # The same background and frame as Outlaw; only the central motifs differ.
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">\n'
        '<defs><radialGradient id="sky"><stop stop-color="#28374c"/>'
        '<stop offset="1" stop-color="#090d18"/></radialGradient></defs>\n'
        '<rect width="256" height="256" rx="18" fill="url(#sky)"/>\n'
        '<rect x="10" y="10" width="236" height="236" rx="12" fill="none" '
        'stroke="#9f8054" stroke-width="3"/>\n'
        + specks + "\n" + body + "\n"
        + '<path d="M17 36V18H35 M221 18H239V36 M17 220V238H35 M220 238H239V220" '
        'fill="none" stroke="#dfb77b" stroke-width="3"/>\n</svg>\n'
    )


if __name__ == "__main__":
    rendered = {name: render(body) for name, body in art.items()}
    if "--emit-patch" in sys.argv:
        print("*** Begin Patch")
        for name, svg in rendered.items():
            target = OUT / f"{name}.svg"
            old = target.read_text(encoding="utf-8")
            if old == svg:
                continue
            print(f"*** Update File: {target.as_posix()}\n@@")
            for line in old.splitlines():
                print(f"-{line}")
            for line in svg.splitlines():
                print(f"+{line}")
        print("*** End Patch")
    else:
        for name, svg in rendered.items():
            (OUT / f"{name}.svg").write_text(svg, encoding="utf-8")
        print("NULL_CELESTIAL_ICONS", len(rendered))
