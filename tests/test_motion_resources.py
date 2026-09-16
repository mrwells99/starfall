"""Linux path adapter coverage; operates on temporary folders, no bundle required."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
spec=importlib.util.spec_from_file_location('motion_resources',Path(__file__).resolve().parents[1]/'tools/motion_resources.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class PortablePaths(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        (self.root/'animation_sources').mkdir()
    def tearDown(self):self.tmp.cleanup()
    def test_flattened_windows_resource(self):
        self.assertEqual(m.local_path(self.root,r'C:\projects\starfall\local_resources\animation_sources\clip.bvh'),self.root/'animation_sources/clip.bvh')
    def test_nested_layout(self):
        (self.root/'local_resources/animation_sources').mkdir(parents=True)
        self.assertEqual(m.resource('animation_sources',self.root),self.root/'local_resources/animation_sources')
    def test_video_relative_to_manifest(self):
        self.assertEqual(m.local_path(self.root,'take.mp4',self.root/'animation_sources'),self.root/'animation_sources/take.mp4')
    def test_containment(self):
        for path in ['https://example.com/file','../../outside','C:/unrelated/file',r'C:\local_resources\animation_sources\..\..\..\outside']:
            with self.subTest(path=path),self.assertRaises(ValueError):m.local_path(self.root,path)
    def test_workflow_names(self):
        path=self.root/'art_source/workflows/starforge-motionlab';path.mkdir(parents=True)
        self.assertEqual(m.motionlab(self.root),path)
if __name__=='__main__':unittest.main()
