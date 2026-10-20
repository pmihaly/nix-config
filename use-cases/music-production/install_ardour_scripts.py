import argparse
import base64
import json
import shutil
import subprocess
from pathlib import Path
from xml.etree import ElementTree as ET


ACTION_NAME = "Last Tweaked: Show Lane"
HOOK_NAME = "Last Tweaked: Monitor"
KEY = "Primary-Secondary-l"
TIMER_SIGNALS = "0010000000000000000000000000000000000000000000000000"


def load_xml(path: Path, root_name: str) -> ET.Element:
    if not path.exists():
        return ET.Element(root_name)
    root = ET.parse(path).getroot()
    if root.tag != root_name:
        raise ValueError(f"Expected {root_name} in {path}, found {root.tag}")
    return root


def child(root: ET.Element, name: str) -> ET.Element:
    node = root.find(name)
    if node is not None:
        return node
    return ET.SubElement(root, name)


def factory_chunk(source: str) -> str:
    local_source = source.replace("function factory ()", "local function factory ()", 1)
    return f"local params = ...\nlocal ardour = function () end\n{local_source}\nreturn factory (params)"


def action_slot(lua: Path, state: bytes) -> int:
    program = '''local env = {}
assert (load (io.read ("*a"), "ui_scripts", "t", env)) ()
local scripts = env.scripts or {}
for i = 1, 9 do
    if scripts[i] and scripts[i].n == "Last Tweaked: Show Lane" then print (i); return end
end
for i = 9, 1, -1 do
    if scripts[i] == nil then print (i); return end
end
error ("No free Ardour action-script slot; remove an unused action first.")
'''
    result = subprocess.run([str(lua), "-e", program], input=state, capture_output=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode(errors="replace"))
    return int(result.stdout)


def register_action(root: ET.Element, source_path: Path, lua: Path) -> int:
    node = child(root, "ActionScript")
    state = base64.b64decode(node.text) if node.text else b"scripts = {}"
    slot = action_slot(lua, state)
    source = source_path.read_text()
    fields = {
        "n": ACTION_NAME,
        "s": source,
        "f": factory_chunk(source),
    }
    assignment = f"\nscripts[{slot}] = {{}}\n"
    assignment += "\n".join(f"scripts[{slot}][{json.dumps(key)}] = {json.dumps(value)}" for key, value in fields.items())
    assignment += f'\nscripts[{slot}]["a"] = {{ ["x-script-origin"] = {json.dumps(str(source_path))} }}\n'
    node.set("lua", "Lua 5.3")
    appended = assignment.encode()
    updated = state
    if not state.endswith(appended):
        updated += appended
    node.text = base64.b64encode(updated).decode()
    return slot


def register_hook(root: ET.Element, source_path: Path) -> None:
    hooks = child(root, "ActionHooks")
    replaced = {HOOK_NAME, "TEST: Last Touched Tracker (touch-based)", "TEST: Last Touched Tracker"}
    for node in list(hooks):
        if node.get("name") in replaced:
            hooks.remove(node)
    source = source_path.read_text()
    state = f's = {{ ["n"] = {json.dumps(HOOK_NAME)}, ["s"] = {json.dumps(source)}, ["f"] = {json.dumps(factory_chunk(source))}, ["a"] = {{}} }}'
    ids = {node.get("id") for node in hooks}
    hook_id = 900000001
    while str(hook_id) in ids:
        hook_id += 1
    node = ET.SubElement(hooks, "LuaCallback", {"lua": "Lua 5.3", "id": str(hook_id), "name": HOOK_NAME, "signals": TIMER_SIGNALS})
    node.text = base64.b64encode(state.encode()).decode()


def register_key(root: ET.Element, slot: int) -> None:
    bindings = root.find("Bindings[@name='Editor']")
    if bindings is None:
        bindings = ET.SubElement(root, "Bindings", {"name": "Editor"})
    press = child(bindings, "Press")
    action = f"LuaAction/script-{slot}"
    existing = press.find(f"Binding[@key='{KEY}']")
    if existing is not None and existing.get("action") != action:
        raise ValueError(f"{KEY} is already bound to {existing.get('action')}; refusing to replace it.")
    if existing is not None:
        return
    ET.SubElement(press, "Binding", {"key": KEY, "action": action, "group": "Lua Scripts"})


def save_xml(path: Path, root: ET.Element) -> None:
    data = ET.tostring(root, encoding="utf-8", xml_declaration=True) + b"\n"
    if path.exists() and path.read_bytes() == data:
        return
    if path.exists() and not path.with_suffix(path.suffix + ".before-last-tweaked").exists():
        shutil.copy2(path, path.with_suffix(path.suffix + ".before-last-tweaked"))
    temporary = path.with_suffix(path.suffix + ".last-tweaked-new")
    temporary.write_bytes(data)
    temporary.replace(path)


def install(config: Path, scripts: Path, defaults: Path, lua: Path) -> None:
    config.mkdir(parents=True, exist_ok=True)
    script_root = load_xml(config / "ui_scripts", "UIScripts")
    slot = register_action(script_root, scripts / "show_last_tweaked.lua", lua)
    register_hook(script_root, scripts / "last_tweaked_monitor.lua")
    keys_path = config / "ardour.keys"
    key_root = load_xml(keys_path if keys_path.exists() else defaults, "BindingSet")
    register_key(key_root, slot)
    save_xml(config / "ui_scripts", script_root)
    save_xml(keys_path, key_root)
    print(f"Ardour Last Tweaked installed in action slot {slot}: Command-Control-L")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--scripts", type=Path, required=True)
    parser.add_argument("--defaults", type=Path, required=True)
    parser.add_argument("--lua", type=Path, required=True)
    args = parser.parse_args()
    running = subprocess.run(["/usr/bin/pgrep", "-x", "Ardour9"], capture_output=True, check=False)
    if running.returncode == 0:
        raise RuntimeError("Close Ardour9 before rebuilding so it cannot overwrite the script and hotkey registration.")
    if running.returncode != 1:
        raise RuntimeError(running.stderr.decode(errors="replace"))
    install(args.config, args.scripts, args.defaults, args.lua)


if __name__ == "__main__":
    main()
