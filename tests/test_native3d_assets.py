from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
OBJ = ROOT / "native3d" / "objects" / "xphud_native_combiner.obj"
PNG = ROOT / "native3d" / "objects" / "xphud_native_combiner.png"

class Native3DAssetTests(unittest.TestCase):
    def test_obj8_header_texture_and_png(self):
        text = OBJ.read_text(encoding="ascii")
        self.assertTrue(text.startswith("A\n800\nOBJ\n"))
        self.assertIn("TEXTURE xphud_native_combiner.png", text)
        self.assertEqual(PNG.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")

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

    def test_transparent_glass_uses_lower_texture_band(self):
        vertices = [line.split() for line in OBJ.read_text(encoding="ascii").splitlines() if line.startswith("VT ")]
        pane = [v for v in vertices if float(v[3]) == 0.116 and float(v[6]) > 0.9]
        self.assertEqual(len(pane), 4)
        values = [float(v[8]) for v in pane]
        self.assertGreaterEqual(min(values), 0.0)
        self.assertLessEqual(max(values), 0.34)

if __name__ == "__main__":
    unittest.main()
