# Ardour MIDI mappings

macOS and Linux use the same Ardour 9.8 patch in `overlays/default.nix`: `ardour-midi-mapping.patch`, a single net-delta (the learn button, per-mapping range slider, and the grouped Mappings window, merged from the earlier 4-patch development stack). Only Linux uses the mold linker. The earlier parameter-picker patch is no longer applied.

## Learn

1. Close Ardour and apply `sudo darwin-rebuild switch --flake 'path:.#work'` on macOS.
2. Enable **Generic MIDI** under **Preferences → Control Surfaces** and configure its input to receive your controller.
3. Open a track plugin, tweak a parameter, click **Learn**, and move a MIDI controller.

**Learn** and **Mappings** appear beside the pin-management button, including in windows hosting a plugin's custom GUI. Learn shows the parameter's automation lane without selecting the track, scrolling the editor, switching views, changing automation mode, or hiding other lanes. It starts Ardour's native learn popup, which can be cancelled and expires after 30 seconds. Existing assignments remain active until learning completes; cancellation makes no mapping changes and adds no undo entry.

Learning is exclusive among learned parameter mappings: the received channel/CC is assigned only to the latest learned parameter. Existing learned assignments to that source and the parameter's previous assignment are replaced together. Predefined MIDI-map bindings, actions, and transport controls are not edited by this window or removed by learning.

Right-click **Learn** for **Show lane only** or **Forget this parameter**. Forget removes that parameter's mapping and hides its automation lane without deleting automation data or changing automation mode. A **Mapped: Ch 1 / CC 74** status reflects the current plugin parameter's binding.

## Grouped mappings window

The **Mappings** window groups assignments by channel and CC. Each group heading shows the CC and its mapped parameters, truncated with `...` when too long. **Add last tweaked** is a separate, keyboard-focusable button outside the collapse control, and remains available when the group is collapsed. Learned note and pitch-bend mappings remain visible as separate source groups, with replacement and removal available; adding last tweaked is available for CC groups only.

The window updates live, so there is no Refresh button: learned, added, replaced, and removed mappings appear immediately (Generic MIDI's `MidiBindingsChanged` signal), and tweaking a plugin parameter while the window is open re-collapses the groups and expands the one holding the last-tweaked parameter. On open, every group is collapsed except the one holding the last-tweaked parameter. Manual expand/collapse via the heading is preserved until the next tweak or reopen.

The header identifies the last-tweaked, available, automatable plugin parameter across track and bus plugins, not only the plugin that opened the window. Tracking uses Ardour's native control-touch signal, not value polling. Plugin GUIs must report gestures to Ardour; Vital VST3 is the initial runtime test target. Region FX are excluded because they do not have track automation lanes.

- **Add last tweaked** adds that parameter to the group's CC while preserving all other parameters in the group. If the parameter is mapped elsewhere, its existing assignment moves here with its range intact. A new mapping starts with the full range. Adding the same parameter to its existing group is a no-op and the button is disabled.
- **Replace with last tweaked** is a text button beside each parameter. It preserves the row's MIDI source and range, removes the incoming parameter's previous learned assignment, and replaces the row's parameter. The tooltip identifies the incoming parameter. The button is disabled when the last-tweaked parameter is already this row.
- **Remove** removes only that parameter's learned assignment and hides its lane. Other parameters sharing the source remain mapped.
- Empty groups remain available for **Add last tweaked** until the mappings window closes. Closing clears remembered empty groups; active groups reappear on reopening. Collapse state is preserved while the window remains open.

There is no manual-add form, numeric CC editor, or searchable parameter picker. Use Learn to create a new source group, then tweak parameters and add them to existing groups. Add and Replace are disabled until an eligible parameter has been tweaked, and validate the target again when invoked.

## Single range slider

Each parameter has one slider with two independently draggable handles. The blue handle sets the parameter value produced at **MIDI 0**; the orange handle sets the value at **MIDI 127**. Formatted endpoint values appear beneath it. Handles can cross for inverted mappings. Dragging a handle previews the corresponding parameter value without writing automation.

Click the slider to focus it. **Space** switches the active handle; **Left/Right** adjusts it by 0.001, or 0.01 with Shift; **Home/End** moves it to an endpoint. **Escape** cancels the current mouse drag's range edit. Tab navigates normally, and modified application shortcuts are not consumed. Mapping ranges and assignments are saved with the session.

## Undo and redo

Assignments, replacement, removal, and completed learning use Ardour's session undo history through a registered stateful memento object. One operation produces one history entry, including every learned assignment it displaced. A completed range drag produces one entry, not one per motion event; keyboard range adjustments produce one entry each. No-op changes and cancelled learning add no entries.

Undo records contain only affected parameter IDs. Restoring a mapping does not clear unrelated assignments, reload a MIDI map, or change port connections. Range history is scoped to the edited parameter so unrelated changes during a drag are not included. Learning completion is dispatched back to the initiating event loop before adding its history entry. A persistent history-object ID supports Ardour's existing memento-history restoration when the Generic MIDI protocol is loaded.

Undo restores learned MIDI assignments and ranges, not automation-lane visibility or the live plugin value used for range preview. If a parameter no longer exists, restoration logs a warning rather than resurrecting a plugin or silently modifying another parameter. Save the session to persist mapping changes.

## Lua fallback

The work configuration also retains the existing Last Tweaked monitor hook and Show Lane action. The native buttons do not depend on these scripts.

1. Close Ardour before applying the configuration.
2. Restart Ardour and tweak one plugin parameter in Manual mode.
3. Focus the Ardour editor and press Command-Control-L.

The action is also under Edit → Lua Scripts. It enables Ardour's Show Automation Lane on Touch feature and sends a synthetic touch to the remembered control. Subsequent native touches can also reveal lanes. This fallback can hide a previously revealed lane when another control is touched; it uses Ardour's existing lane-display behavior.

The monitor polls every 100 ms, remembers only Manual-mode changes, and reports parameter names in Window → Log. Simultaneous multi-parameter changes clear the remembered parameter instead of selecting one arbitrarily. It does not change automation modes, write automation data, or enter MIDI learn.

Home Manager activation merges registration into `ui_scripts` and the hotkey into `ardour.keys`, preserving unrelated scripts and bindings. Existing versions are backed up with `.before-last-tweaked`. An occupied shortcut or a running Ardour instance causes activation to fail visibly. The old test tracker hook is replaced by the new monitor. The timer signal mask targets Ardour 9.8's Lua bindings.

The scripts use an ephemeral `last-tweaked-request` file to communicate between Ardour's separate action and hook Lua states. They require Lua file I/O, which is unavailable when Ardour's all-scripts sandbox is enabled.

## Tests

```sh
ARDOUR_TEST_SOURCE=/path/to/ardour-9.8-source \
ARDOUR_TEST_LUA=/path/to/lua5.3 \
ARDOUR_TEST_KEYS=/path/to/Ardour9.app/Contents/Resources/ardour.keys \
python3 -m unittest discover -s use-cases/music-production -p 'test_ardour_*.py' -v
```

Patch tests apply the shared patch without fuzz. They check lane safety, plugin-instance tracking, grouped layout and empty-group lifetime, last-tweaked actions, range handling, exclusive learning, and undo registration. A compiled test exercises the actual mapping-delta function for additions, removal, replacement, no-ops, and parameter-scoped range history. Lua tests cover registration, preserving scripts, repeat activation, shortcut conflicts, Manual-mode detection, ambiguous changes, automation-mode safety, and session resets. Actual mouse interaction, plugin gestures, MIDI input, and live Undo/Redo still need an Ardour session.

The first macOS build's upstream runner reported an assertion failure in `RWLockTest::run_thread_sequence_test` and a missing `libvamp-sdk.so` dependency for the core test executable. Its runner still returned success. The upstream suite is not fully passing; the patch/Lua regression checks are separate.
