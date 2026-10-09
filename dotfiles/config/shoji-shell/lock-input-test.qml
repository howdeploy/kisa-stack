//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "lock"

ShellRoot {
    id: root
    property string sharedPassword: ""
    property string submittedPassword: ""
    FloatingWindow {
        id: window
        implicitWidth: 800; implicitHeight: 640
        visible: true
        LockView {
            id: first
            width: 400; height: 640
            preview: true
            passwordText: root.sharedPassword
            onPasswordEdited: value => root.sharedPassword = value
            onSubmitted: value => root.submittedPassword = value
        }
        LockView {
            id: second
            x: 400; width: 400; height: 640
            preview: true
            passwordText: root.sharedPassword
            onPasswordEdited: value => root.sharedPassword = value
            onSubmitted: value => root.submittedPassword = value
        }
        Component {
            id: lateView
            LockView {
                width: 400; height: 640; inputEnabled: false
                passwordText: root.sharedPassword
                onPasswordEdited: value => root.sharedPassword = value
            }
        }
        TestCase {
            name: "LockInputSync"
            when: window.visible
            property int passed: 0
            function cleanupTestCase() {
                if (passed === 5) console.log("SHOJI_LOCK_INPUT_TESTS_OK: 5");
                else console.error("SHOJI_LOCK_INPUT_TESTS_FAILED: " + passed + "/5");
            }
            function init() {
                root.sharedPassword = "";
                root.submittedPassword = "";
                first.focusPassword();
                wait(20);
            }
            function field(view) { return findChild(view, "lockPasswordInput"); }
            function test_edits_and_backspace_sync_both_directions() {
                keyClick("a"); keyClick("b");
                compare(root.sharedPassword, "ab");
                compare(field(second).text, "ab");
                verify(field(first).activeFocus);
                second.focusPassword();
                keyClick("c");
                compare(field(first).text, "abc");
                verify(field(second).activeFocus);
                keyClick(Qt.Key_Backspace);
                compare(field(first).text, "ab");
                compare(root.sharedPassword, "ab");
                passed += 1;
            }
            function test_escape_clears_every_view() {
                keyClick("a");
                keyClick(Qt.Key_Escape);
                compare(root.sharedPassword, "");
                compare(field(first).text, "");
                compare(field(second).text, "");
                passed += 1;
            }
            function test_enter_from_other_view_submits_and_clears_shared_value() {
                keyClick("a"); keyClick("b");
                second.focusPassword();
                keyClick(Qt.Key_Return);
                compare(root.submittedPassword, "ab");
                compare(root.sharedPassword, "");
                compare(field(first).text, "");
                compare(field(second).text, "");
                passed += 1;
            }
            function test_active_cursor_is_preserved() {
                keyClick("a"); keyClick("b");
                field(first).cursorPosition = 1;
                keyClick("c");
                compare(field(first).text, "acb");
                compare(field(second).text, "acb");
                compare(field(first).cursorPosition, 2);
                verify(field(first).activeFocus);
                passed += 1;
            }
            function test_new_output_gets_existing_buffer() {
                keyClick("a"); keyClick("b");
                const view = lateView.createObject(window.contentItem);
                verify(view !== null);
                compare(field(view).text, "ab");
                view.destroy();
                compare(root.sharedPassword, "ab");
                passed += 1;
            }
        }
    }
}
