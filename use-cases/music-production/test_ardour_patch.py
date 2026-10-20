import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).parent


def method(source: str, signature: str) -> str:
    start = source.index(signature + "\n{")
    end = source.index("\n}\n", start) + 3
    return source[start:end]


class ArdourPatchTest(unittest.TestCase):
    patched: Path

    @classmethod
    def setUpClass(cls) -> None:
        source_path = os.environ.get("ARDOUR_TEST_SOURCE")
        if not source_path:
            raise unittest.SkipTest("Set ARDOUR_TEST_SOURCE to the unmodified Ardour 9.8 source")
        directory = tempfile.TemporaryDirectory()
        cls.addClassCleanup(directory.cleanup)
        cls.patched = Path(directory.name)
        patches = [ROOT.parent.parent / "overlays" / "ardour-midi-mapping.patch"]
        paths = set(re.findall(r"^--- a/(.+)$", "\n".join(p.read_text() for p in patches), re.MULTILINE))
        for relative in paths:
            target = cls.patched / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(Path(source_path) / relative, target)
        for patch in patches:
            subprocess.run(["patch", "-p1", "-F0", "-d", str(cls.patched)], input=patch.read_bytes(), check=True)

    def test_lane_display_does_not_focus_scroll_hide_or_touch(self) -> None:
        source = (self.patched / "gtk2_ardour/route_time_axis.cc").read_text()
        operation = method(source, "RouteTimeAxisView::show_automation_lane (std::shared_ptr<AutomationControl> control)")
        self.assertIn("item->set_active (true)", operation)
        self.assertIn("find_atav_by_ctrl (control, false)", operation)
        self.assertIn("lane->set_marked_for_display (true)", operation)
        for forbidden in ["_editor", "signal_ctrl_touched", "start_touch", "automation_state", "set_selected"]:
            self.assertNotIn(forbidden, operation)

    def test_tracking_remembers_global_target_before_plugin_instance_filter(self) -> None:
        source = (self.patched / "gtk2_ardour/plugin_ui.cc").read_text()
        operation = method(source, "PlugUIBase::remember_touched_parameter (std::weak_ptr<Controllable> touched)")
        self.assertIn("ControlTouched.connect", source)
        self.assertIn("control->parameter ().type () != PluginAutomation", operation)
        self.assertLess(operation.index("_last_midi_parameter = control"), operation.index("_pi->automation_control"))
        self.assertIn("_learn_binding.set_controllable (control)", operation)
        self.assertNotIn("get_value", operation)
        self.assertNotIn("automation_state", operation)

    def test_button_shows_lane_before_starting_native_learn(self) -> None:
        source = (self.patched / "gtk2_ardour/plugin_ui.cc").read_text()
        operation = method(source, "PlugUIBase::learn_last_parameter ()")
        self.assertLess(operation.index("show_last_parameter"), operation.index("_learn_binding.start_learning"))
        self.assertIn("Enable Generic MIDI", operation)
        self.assertIn("b->pack_end (_mappings_button", source)
        self.assertEqual(source.count('_learn_button (_("Learn"))'), 1)

    def test_removing_mapping_hides_lane_without_deleting_automation(self) -> None:
        source = (self.patched / "gtk2_ardour/plugin_ui.cc").read_text()
        operation = method(source, "PlugUIBase::remove_midi_mapping (std::shared_ptr<Controllable> control)")
        self.assertLess(operation.index("UnmapMidi"), operation.index("hide_automation_lane"))
        lane = (self.patched / "gtk2_ardour/route_time_axis.cc").read_text()
        hide = method(lane, "RouteTimeAxisView::hide_automation_lane (std::shared_ptr<AutomationControl> control)")
        self.assertIn("item->set_active (false)", hide)
        for forbidden in ["_editor", "clear", "erase", "automation_state", "start_touch"]:
            self.assertNotIn(forbidden, hide)

    def test_unmap_is_idempotent_and_notifies_after_unlocking(self) -> None:
        source = (self.patched / "libs/surfaces/generic_midi/generic_midi_control_protocol.cc").read_text()
        operation = method(source, "GenericMidiControlProtocol::unmap_midi (std::weak_ptr<Controllable> weak_control)")
        self.assertIn("(*i)->get_controllable () != control || !(*i)->learned ()", operation)
        self.assertIn('record_mapping_change (_("Remove MIDI mapping")', operation)
        self.assertLess(operation.index("lock.release ()"), operation.index("MidiBindingsChanged"))
        self.assertTrue(operation.rstrip().endswith("return true;\n}"))

    def test_grouping_uses_channel_event_and_number_and_keeps_empty_groups(self) -> None:
        source = (self.patched / "gtk2_ardour/plugin_ui.cc").read_text()
        refresh = method(source, "PlugUIBase::refresh_midi_mappings ()")
        self.assertIn("MidiMappingSource source (binding.channel, binding.event, binding.number)", refresh)
        self.assertIn("_midi_groups[source].label = binding.source", refresh)
        self.assertIn("for (auto const& group : _midi_groups)", refresh)
        self.assertNotIn("_midi_groups.clear", refresh)
        self.assertIn("binding.low, binding.high", refresh)
        close = method(source, "PlugUIBase::midi_mapping_response (int response)")
        self.assertIn("_midi_groups.clear ()", close)
        self.assertIn("signal_delete_event ().connect", source)
        group = method(source, "PlugUIBase::build_midi_mapping_group (MidiMappingSource const& source, std::vector<Controllable::MidiBinding> const& bindings)")
        for expected in ["Gtk::Expander", "group.expanded", "bindings.empty ()", '_("Add last tweaked")']:
            self.assertIn(expected, group)

    def test_group_add_button_is_focusable_and_outside_expander(self) -> None:
        source = (self.patched / "gtk2_ardour/plugin_ui.cc").read_text()
        group = method(source, "PlugUIBase::build_midi_mapping_group (MidiMappingSource const& source, std::vector<Controllable::MidiBinding> const& bindings)")
        for expected in ["header->pack_start (*expander, true, true)", "header->pack_end (*add, false, false)", "expander->set_label_widget (*title_box)", "add->set_can_focus (true)", "body->set_no_show_all (true)", "body->set_visible (group.expanded)", "body->set_visible (expander->get_expanded ())"]:
            self.assertIn(expected, group)
        self.assertNotIn("expander->set_label_widget (*header)", group)
        self.assertNotIn("expander->add (*body)", group)

    def test_replace_uses_explicit_label_and_window_has_no_footer_disclaimer(self) -> None:
        source = (self.patched / "gtk2_ardour/plugin_ui.cc").read_text()
        self.assertIn('new Gtk::Button (_("Replace with last tweaked"))', source)
        self.assertNotIn("Gtk::Stock::PREFERENCES", source)
        self.assertNotIn("Changes support Undo/Redo.", source)
        window = method(source, "PlugUIBase::show_midi_mappings ()")
        self.assertNotIn("Gtk::Label* hint", window)

    def test_last_tweaked_is_revalidated_and_buttons_describe_replacement(self) -> None:
        source = (self.patched / "gtk2_ardour/plugin_ui.cc").read_text()
        target = method(source, "PlugUIBase::last_midi_parameter ()")
        for expected in ["_last_midi_parameter.lock ()", "PluginAutomation", "Controllable::NotAutomatable", "midi_mapping_target (control).empty ()"]:
            self.assertIn(expected, target)
        refresh = method(source, "PlugUIBase::refresh_midi_last_tweaked ()")
        self.assertIn("Already mapped to this CC", refresh)
        self.assertIn("Replace with last tweaked: %1", refresh)
        self.assertIn("set_sensitive (control && entry.second.lock () != control)", refresh)
        self.assertNotIn("show_midi_parameter_picker", source)
        self.assertNotIn("Add mapping manually", source)
        self.assertNotIn("Gtk::SpinButton", source)

    def test_add_last_tweaked_preserves_sharing_and_moves_existing_assignment(self) -> None:
        source = (self.patched / "libs/surfaces/generic_midi/generic_midi_control_protocol.cc").read_text()
        operation = method(source, "GenericMidiControlProtocol::map_midi_cc (std::weak_ptr<Controllable> weak_control, int channel, int cc)")
        self.assertIn("candidate->get_controllable () != control || !candidate->learned ()", operation)
        self.assertIn("mapping = candidate", operation)
        self.assertIn("if (!mapping)", operation)
        self.assertIn("mapping->bind_midi", operation)
        self.assertIn("record_mapping_change", operation)
        for forbidden in ["remove_used_event", "set_learned_range", "delete", "erase"]:
            self.assertNotIn(forbidden, operation)

    def test_replace_preserves_row_range_and_removes_incoming_assignment(self) -> None:
        source = (self.patched / "libs/surfaces/generic_midi/generic_midi_control_protocol.cc").read_text()
        operation = method(source, "GenericMidiControlProtocol::retarget_midi (std::weak_ptr<Controllable> weak_previous, std::weak_ptr<Controllable> weak_target)")
        self.assertIn("if (previous == target)", operation)
        self.assertLess(operation.index("if (!mapping)"), operation.index("delete *i"))
        self.assertIn("(*i)->get_controllable () != target", operation)
        self.assertIn("mapping->set_controllable (target, true)", operation)
        self.assertIn("record_mapping_change", operation)
        self.assertNotIn("bind_midi", operation)
        controller = (self.patched / "libs/surfaces/generic_midi/midicontrollable.cc").read_text()
        setter = method(controller, "MIDIControllable::set_controllable (std::shared_ptr<PBD::Controllable> c, bool preserve_range)")
        self.assertIn("if (!preserve_range)", setter)
        self.assertLess(setter.index("if (!preserve_range)"), setter.index("last_controllable_value = control_to_midi"))

    def test_range_uses_two_independent_handles_and_one_drag_transaction(self) -> None:
        source = (self.patched / "gtk2_ardour/plugin_ui.cc").read_text()
        widget = source[source.index("class MidiMappingRange"):source.index("PlugUIBase::build_midi_mapping_group")]
        for expected in ["_active_low ? _low : _high", "begin.emit ()", "finished.emit ()", "GDK_KEY_Escape", "_low = _initial_low", "_high = _initial_high", "GDK_KEY_space", "GDK_KEY_Home", "GDK_KEY_End", "remove_modal_grab ()"]:
            self.assertIn(expected, widget)
        self.assertNotIn("std::swap", widget)
        self.assertNotIn("record_mapping_change", widget)
        self.assertNotIn("Gtk::HScale", source)
        self.assertIn("Controllable::BeginMidiRange (control)", source)
        self.assertIn("Controllable::EndMidiRange ()", source)
        self.assertIn('_("MIDI 0: %1")', source)
        self.assertIn('_("MIDI 127: %1")', source)

    def test_range_changes_reject_invalid_values_and_coalesce_history(self) -> None:
        source = (self.patched / "libs/surfaces/generic_midi/generic_midi_control_protocol.cc").read_text()
        operation = method(source, "GenericMidiControlProtocol::map_midi_range (std::weak_ptr<Controllable> weak_control, float low, float high)")
        self.assertIn("!std::isfinite (low)", operation)
        self.assertIn("!std::isfinite (high)", operation)
        self.assertIn("if (!_range_before && changed)", operation)
        ending = method(source, "GenericMidiControlProtocol::end_midi_range ()")
        self.assertIn("std::move (_range_before)", ending)
        self.assertIn("std::move (_range_parameter)", ending)
        self.assertIn("record_mapping_change", ending)

    def test_learning_keeps_old_mapping_until_completion_and_is_exclusive(self) -> None:
        source = (self.patched / "libs/surfaces/generic_midi/generic_midi_control_protocol.cc").read_text()
        start = method(source, "GenericMidiControlProtocol::start_learning (std::weak_ptr <Controllable> wc)")
        for forbidden in ["controllables.erase", "remove_used_event", "record_mapping_change"]:
            self.assertNotIn(forbidden, start)
        complete = method(source, "GenericMidiControlProtocol::learning_stopped (MIDIControllable* mc)")
        self.assertLess(complete.index("mapping_snapshot ()"), complete.index("remove_used_event"))
        self.assertLess(complete.index("remove_used_event"), complete.index("controllables.push_back (mc)"))
        self.assertLess(complete.index("lock.release ()"), complete.index("event_loop->call_slot"))
        self.assertIn("PBD::EventLoop::__invalidator (_mapping_state, __FILE__, __LINE__)", complete)
        self.assertIn('_("Learn MIDI mapping")', complete)
        exclusive = method(source, "GenericMidiControlProtocol::remove_used_event (int pos, int control_number)")
        self.assertIn("!mapping->learned () || !same_source || !same_number", exclusive)
        self.assertNotIn("functions.erase", exclusive)
        self.assertNotIn("actions.erase", exclusive)

    def test_history_uses_registered_mementos_and_preserves_unaffected_mappings(self) -> None:
        source = (self.patched / "libs/surfaces/generic_midi/generic_midi_control_protocol.cc").read_text()
        record = method(source, "GenericMidiControlProtocol::record_mapping_change (std::string const& name, std::shared_ptr<XMLNode> before, std::shared_ptr<XMLNode> after, std::string const& only_parameter)")
        for expected in ["undo->children ().empty ()", "begin_reversible_command", "commit_reversible_command", "MementoCommand<MappingState>"]:
            self.assertIn(expected, record)
        restore = method(source, "GenericMidiControlProtocol::restore_mappings (XMLNode const& state)")
        self.assertIn("erase_learned_mapping (id)", restore)
        self.assertIn('node->name () == "Removed"', restore)
        self.assertIn("no longer exists", restore)
        for forbidden in ["controllables.clear", "reload_maps", "set_active", "get_state ()"]:
            self.assertNotIn(forbidden, restore)
        self.assertIn('node.set_property ("mapping-history-id", _mapping_state.id ())', source)
        self.assertIn("register_with_memento_command_factory (_mapping_state.id (), &_mapping_state)", source)

    def test_mapping_range_is_saved_with_session(self) -> None:
        source = (self.patched / "libs/surfaces/generic_midi/midicontrollable.cc").read_text()
        for endpoint in ["low", "high"]:
            self.assertIn(f'node.get_property ("{endpoint}", _learned_{endpoint})', source)
            self.assertIn(f'node->set_property ("{endpoint}", _learned_{endpoint})', source)

    def test_popup_completion_is_gui_safe_and_repeatable(self) -> None:
        source = (self.patched / "libs/widgets/binding_proxy.cc").read_text()
        operation = method(source, "BindingProxy::start_learning ()")
        self.assertIn("Controllable::StartLearning (controllable)", operation)
        self.assertIn("gui_context ()", operation)
        self.assertNotIn("connect_same_thread", operation)
        self.assertIn("prompter && prompter->get_visible ()", method(source, "BindingProxy::learning_finished ()"))

    def test_actual_history_delta_handles_moves_replacement_removal_and_scoping(self) -> None:
        compiler = shutil.which("c++")
        if not compiler:
            self.skipTest("A C++ compiler is required for the history-delta test")
        source = (self.patched / "libs/surfaces/generic_midi/generic_midi_control_protocol.cc").read_text()
        delta = method(source, "midi_mapping_delta (XMLNode const& state, XMLNode const& other, std::string const& only_parameter)")
        fixture = (ROOT / "test_midi_mapping_history.cc").read_text()
        program = fixture.replace("MIDI_MAPPING_DELTA_IMPLEMENTATION", "std::unique_ptr<XMLNode>\n" + delta)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "history.cc"
            path.write_text(program)
            executable = Path(directory) / "history"
            subprocess.run([compiler, "-std=c++11", str(path), "-o", str(executable)], check=True)
            subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    unittest.main()
