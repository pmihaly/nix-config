#include <cassert>
#include <map>
#include <memory>
#include <string>
#include <utility>
#include <vector>

class XMLNode
{
public:
    explicit XMLNode (std::string name) : _name (std::move (name)) {}
    XMLNode (XMLNode const& other) : _name (other._name), _properties (other._properties) {
        for (auto node : other._children) {
            _children.push_back (new XMLNode (*node));
        }
    }
    ~XMLNode () {
        for (auto node : _children) {
            delete node;
        }
    }
    std::string const& name () const { return _name; }
    std::vector<XMLNode*> const& children () const { return _children; }
    void add_child_nocopy (XMLNode& child) { _children.push_back (&child); }
    void set_property (std::string const& key, std::string const& value) { _properties[key] = value; }
    bool get_property (std::string const& key, std::string& value) const {
        auto found = _properties.find (key);
        if (found == _properties.end ()) {
            return false;
        }
        value = found->second;
        return true;
    }
    bool operator== (XMLNode const& other) const {
        if (_name != other._name || _properties != other._properties || _children.size () != other._children.size ()) {
            return false;
        }
        for (size_t i = 0; i < _children.size (); ++i) {
            if (!(*_children[i] == *other._children[i])) {
                return false;
            }
        }
        return true;
    }
private:
    std::string _name;
    std::map<std::string, std::string> _properties;
    std::vector<XMLNode*> _children;
};

MIDI_MAPPING_DELTA_IMPLEMENTATION

using State = std::map<std::string, std::pair<std::string, std::string>>;

void mapping (XMLNode& state, std::string const& id, std::string const& source, std::string const& range)
{
    auto node = new XMLNode ("MIDIControllable");
    node->set_property ("id", id);
    node->set_property ("source", source);
    node->set_property ("range", range);
    state.add_child_nocopy (*node);
}

void apply (State& state, XMLNode const& changes)
{
    for (auto node : changes.children ()) {
        std::string id;
        assert (node->get_property ("id", id));
        if (node->name () == "Removed") {
            state.erase (id);
            continue;
        }
        std::string source;
        std::string range;
        assert (node->get_property ("source", source));
        assert (node->get_property ("range", range));
        state[id] = {source, range};
    }
}

State bindings (XMLNode const& snapshot)
{
    State result;
    apply (result, snapshot);
    return result;
}

void round_trip (XMLNode const& before, XMLNode const& after, size_t changed)
{
    auto undo = midi_mapping_delta (before, after, "");
    auto redo = midi_mapping_delta (after, before, "");
    assert (undo->children ().size () == changed);
    assert (redo->children ().size () == changed);
    auto state = bindings (after);
    apply (state, *undo);
    assert (state == bindings (before));
    apply (state, *redo);
    assert (state == bindings (after));
}

int main ()
{
    XMLNode before ("MidiMappings");
    mapping (before, "a", "1/15", "0:1");
    mapping (before, "b", "1/16", "0.2:0.8");
    mapping (before, "d", "2/18", "0:1");

    XMLNode shared ("MidiMappings");
    mapping (shared, "a", "1/16", "0:1");
    mapping (shared, "b", "1/16", "0.2:0.8");
    mapping (shared, "d", "2/18", "0:1");
    round_trip (before, shared, 1);

    XMLNode replacement ("MidiMappings");
    mapping (replacement, "b", "1/15", "0:1");
    mapping (replacement, "d", "2/18", "0:1");
    round_trip (before, replacement, 2);

    XMLNode learned ("MidiMappings");
    mapping (learned, "a", "1/16", "0:1");
    mapping (learned, "d", "2/18", "0:1");
    round_trip (before, learned, 2);

    XMLNode added (before);
    mapping (added, "c", "1/15", "0:1");
    round_trip (before, added, 1);
    round_trip (added, before, 1);
    round_trip (before, before, 0);

    XMLNode concurrent ("MidiMappings");
    mapping (concurrent, "a", "1/15", "0.7:0.3");
    mapping (concurrent, "b", "1/99", "0.2:0.8");
    mapping (concurrent, "d", "2/18", "0:1");
    auto undo_range = midi_mapping_delta (before, concurrent, "a");
    auto redo_range = midi_mapping_delta (concurrent, before, "a");
    assert (undo_range->children ().size () == 1);
    auto state = bindings (concurrent);
    apply (state, *undo_range);
    assert (state.at ("a") == bindings (before).at ("a"));
    assert (state.at ("b") == bindings (concurrent).at ("b"));
    apply (state, *redo_range);
    assert (state == bindings (concurrent));
    assert (midi_mapping_delta (before, concurrent, "missing")->children ().empty ());
}
