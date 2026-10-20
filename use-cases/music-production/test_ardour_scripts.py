import base64
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from xml.etree import ElementTree as ET

from install_ardour_scripts import ACTION_NAME, HOOK_NAME, install


ROOT = Path(__file__).parent
LUA = Path(os.environ["ARDOUR_TEST_LUA"])
DEFAULTS = Path(os.environ["ARDOUR_TEST_KEYS"])


class ArdourScriptsTest(unittest.TestCase):
    def test_install_preserves_existing_scripts_and_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            root = ET.Element("UIScripts")
            node = ET.SubElement(root, "ActionScript")
            node.text = base64.b64encode(b'scripts = {} scripts[9] = {n="Other Action", f="return function () end", a={}}').decode()
            hooks = ET.SubElement(root, "ActionHooks")
            ET.SubElement(hooks, "LuaCallback", {"name": "Other Hook", "id": "900000001"})
            ET.SubElement(hooks, "LuaCallback", {"name": "TEST: Last Touched Tracker (touch-based)"})
            ET.ElementTree(root).write(config / "ui_scripts")
            install(config, ROOT / "scripts", DEFAULTS, LUA)
            first = (config / "ui_scripts").read_bytes()
            first_keys = (config / "ardour.keys").read_bytes()
            install(config, ROOT / "scripts", DEFAULTS, LUA)
            self.assertEqual(first, (config / "ui_scripts").read_bytes())
            self.assertEqual(first_keys, (config / "ardour.keys").read_bytes())
            installed = ET.parse(config / "ui_scripts").getroot()
            names = [node.get("name") for node in installed.findall("ActionHooks/LuaCallback")]
            self.assertEqual(names, ["Other Hook", HOOK_NAME])
            state = base64.b64decode(installed.find("ActionScript").text)
            self.assertIn(b"Other Action", state)
            self.assertIn(ACTION_NAME.encode(), state)
            key = ET.parse(config / "ardour.keys").find("Bindings[@name='Editor']/Press/Binding[@key='Primary-Secondary-l']")
            self.assertEqual(key.get("action"), "LuaAction/script-8")
            self.assertTrue((config / "ui_scripts.before-last-tweaked").exists())

    def test_occupied_shortcut_does_not_write_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            keys = ET.parse(DEFAULTS).getroot()
            press = keys.find("Bindings[@name='Editor']/Press")
            ET.SubElement(press, "Binding", {"key": "Primary-Secondary-l", "action": "Editor/other"})
            ET.ElementTree(keys).write(config / "ardour.keys")
            original = (config / "ardour.keys").read_bytes()
            with self.assertRaisesRegex(ValueError, "refusing to replace"):
                install(config, ROOT / "scripts", DEFAULTS, LUA)
            self.assertEqual(original, (config / "ardour.keys").read_bytes())
            self.assertFalse((config / "ui_scripts").exists())

    def test_registered_factories_restore_from_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            install(config, ROOT / "scripts", DEFAULTS, LUA)
            root = ET.parse(config / "ui_scripts").getroot()
            state = base64.b64decode(root.find("ActionScript").text)
            program = 'assert(load(io.read("*a")))(); assert(scripts[9].n == "Last Tweaked: Show Lane"); assert(type(assert(load(scripts[9].f))()) == "function")'
            subprocess.run([str(LUA), "-e", program], input=state, check=True)
            state = base64.b64decode(root.find("ActionHooks/LuaCallback").text)
            program = 'assert(load(io.read("*a")))(); assert(s.n == "Last Tweaked: Monitor"); assert(type(assert(load(s.f))()) == "function")'
            subprocess.run([str(LUA), "-e", program], input=state, check=True, env={**os.environ, "HOME": directory})

    def test_manual_monitor_and_hotkey_request(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "Library/Preferences/Ardour9"
            config.mkdir(parents=True)
            (config / "instant.xml").write_text('<Instant><Editor show-touched-automation="0"/></Instant>')
            subprocess.run([str(LUA), str(ROOT / "test_last_tweaked.lua"), str(ROOT / "scripts")], check=True, env={**os.environ, "HOME": directory})


if __name__ == "__main__":
    unittest.main()
