from pathlib import Path
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OBJ = ROOT / "native3d" / "objects" / "xphud_native_combiner.obj"
PNG = ROOT / "native3d" / "objects" / "xphud_native_combiner.png"


class Native3DAssetTests(unittest.TestCase):
    def test_obj8_header_texture_and_png(self):
        text = OBJ.read_text(encoding="ascii")
        self.assertTrue(text.startswith("A\n800\nOBJ\n"))
        self.assertIn("TEXTURE xphud_native_combiner.png", text)
        with Image.open(PNG) as im:
            im.load()
            self.assertEqual(im.mode, "RGBA")
            self.assertEqual(im.size, (64, 64))

    def test_vertex_index_counts(self):
        lines = OBJ.read_text(encoding="ascii").splitlines()
        counts = next(line for line in lines if line.startswith("POINT_COUNTS ")).split()
        vertex_count, index_count = int(counts[1]), int(counts[4])
        vertices = [line for line in lines if line.startswith("VT ")]
        indices = [int(n) for line in lines if line.startswith("IDX ") for n in line.split()[1:]]
        self.assertEqual(len(vertices), vertex_count)
        self.assertEqual(len(indices), index_count)
        self.assertEqual(index_count % 3, 0)
        self.assertGreater(len(indices), 50)
        self.assertGreaterEqual(min(indices), 0)
        self.assertLess(max(indices), vertex_count)
        self.assertTrue(all(len(line.split()) == 9 for line in vertices))

    def test_external_view_hide_and_scope_limitations(self):
        text = OBJ.read_text(encoding="ascii")
        self.assertIn("ANIM_hide 1 1 sim/graphics/view/view_is_external", text)
        self.assertNotIn("ATTR_hud_glass", text)
        self.assertIn("ATTR_blend", text)

    def test_metal_and_combiner_have_separate_uv_regions(self):
        vertices = [line.split() for line in OBJ.read_text(encoding="ascii").splitlines() if line.startswith("VT ")]
        self.assertEqual(len(vertices), 40)
        metal_v = [float(v[8]) for v in vertices[:36]]
        glass_v = [float(v[8]) for v in vertices[36:]]
        self.assertGreaterEqual(min(metal_v), 0.62)
        self.assertLessEqual(max(metal_v), 0.96)
        self.assertGreaterEqual(min(glass_v), 0.04)
        self.assertLessEqual(max(glass_v), 0.34)

    def test_combiner_texture_is_translucent_and_metal_is_opaque(self):
        with Image.open(PNG) as im:
            im.load()
            alpha = im.getchannel("A")
            self.assertEqual(alpha.getextrema()[0], 0)
            self.assertEqual(alpha.getextrema()[1], 255)
            # OBJ V=.62-.96 selects the metal band; V=.04-.34 selects the pane band.
            metal = alpha.crop((0, 2, 64, 25))
            pane = alpha.crop((0, 42, 64, 62))
            self.assertEqual(metal.getextrema(), (255, 255))
            self.assertGreater(pane.getextrema()[0], 0)
            self.assertLess(pane.getextrema()[1], 255)


if __name__ == "__main__":
    unittest.main()
