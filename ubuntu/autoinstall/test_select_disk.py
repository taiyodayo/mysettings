import contextlib
import importlib.util
import io
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("select_disk", Path(__file__).with_name("select-disk.py"))
selector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selector)


def disk(name="/dev/nvme0n1", **overrides):
    return dict(name=name, type="disk", size=128 * 1024**3,
                tran="nvme", ro=False, mountpoints=[None], **overrides)


class DiskSelectionTests(unittest.TestCase):
    def test_excludes_installer_usb_mounted_readonly_and_small_disks(self):
        good = disk()
        usb = dict(good, name="/dev/sdb", tran="usb")
        mounted = dict(good, name="/dev/sdc", children=[{"mountpoints": ["/cdrom"]}])
        nested = dict(good, name="/dev/sdd", children=[{"children": [{"mountpoints": ["/"]}]}])
        readonly = dict(good, ro=True)
        tiny = dict(good, size=1024**3)
        self.assertEqual(selector.eligible_disks([usb, mounted, nested, readonly, tiny, good]), [good])

    def test_no_default_or_out_of_range_choice(self):
        answers = iter(["", "0", "99", "bad", "2"])
        with contextlib.redirect_stdout(io.StringIO()):
            chosen = selector.select_disk([disk(), disk("/dev/sda")], lambda _: next(answers))
        self.assertEqual(chosen, "/dev/sda")

    def test_cancel_and_empty_disk_list_fail(self):
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(ValueError):
                selector.select_disk([disk()], lambda _: "q")
            with self.assertRaises(ValueError):
                selector.select_disk([])

    def test_only_selected_disk_token_changes(self):
        config = 'storage:\n  path: "__SELECT_INSTALL_DISK__"\npassword: "!"\n'
        rendered = selector.render_config(config, "/dev/nvme0n1")
        self.assertEqual(rendered, config.replace(selector.TOKEN, '"/dev/nvme0n1"'))

    def test_rejects_missing_key_bad_path_or_ambiguous_token(self):
        for config, path in [
            (selector.TOKEN + ' REPLACE_WITH_YOUR_PUBLIC_KEY', '/dev/sda'),
            (selector.TOKEN, '/dev/sda\nmalicious: true'),
            ('no token', '/dev/sda'),
            (selector.TOKEN * 2, '/dev/sda'),
        ]:
            with self.subTest(config=config, path=path), self.assertRaises(ValueError):
                selector.render_config(config, path)


if __name__ == "__main__":
    unittest.main()
