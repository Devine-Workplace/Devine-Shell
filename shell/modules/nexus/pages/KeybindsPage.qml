import QtQuick
import QtQuick.Layouts
import Devine.Config
import Devine.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Keyboard shortcuts")

    function commit(slot: string, value: string): void {
        const clean = value.trim().replace(/\s*\+\s*/g, " + ");
        const all = [Keybinds.switcher, Keybinds.switcherBack, Keybinds.overview, Keybinds.launcher, Keybinds.settings, Keybinds.screenshot, Keybinds.clipboard, Keybinds.explorer];
        if (!/^(SUPER|ALT|CTRL)( \+ (SUPER|ALT|CTRL|SHIFT))* \+ ([A-Z0-9]+|SPACE|TAB|ENTER|ESC|BACKSPACE|DELETE|LEFT|RIGHT|UP|DOWN)$/i.test(clean))
            return;
        if (all.some((existing, i) => i !== root.indexFor(slot) && existing.toLowerCase() === clean.toLowerCase()))
            return;
        Keybinds[slot] = clean;
    }

    function indexFor(slot: string): int {
        return ({
                switcher: 0,
                switcherBack: 1,
                overview: 2,
                launcher: 3,
                settings: 4,
                screenshot: 5,
                clipboard: 6,
                explorer: 7
            })[slot] ?? -1;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Window and shell")
        }

        TextFieldRow {
            first: true
            label: Tr.tr("Next window")
            value: Keybinds.switcher
            validate: /^(SUPER|ALT|CTRL)( \+ (SUPER|ALT|CTRL|SHIFT))* \+ ([A-Z0-9]+|SPACE|TAB|ENTER|ESC|BACKSPACE|DELETE|LEFT|RIGHT|UP|DOWN)$/i
            onEditingFinished: value => root.commit("switcher", value)
        }

        TextFieldRow {
            label: Tr.tr("Previous window")
            value: Keybinds.switcherBack
            validate: /^(SUPER|ALT|CTRL)( \+ (SUPER|ALT|CTRL|SHIFT))* \+ ([A-Z0-9]+|SPACE|TAB|ENTER|ESC|BACKSPACE|DELETE|LEFT|RIGHT|UP|DOWN)$/i
            onEditingFinished: value => root.commit("switcherBack", value)
        }

        TextFieldRow {
            label: Tr.tr("Desktop overview")
            value: Keybinds.overview
            validate: /^(SUPER|ALT|CTRL)( \+ (SUPER|ALT|CTRL|SHIFT))* \+ ([A-Z0-9]+|SPACE|TAB|ENTER|ESC|BACKSPACE|DELETE|LEFT|RIGHT|UP|DOWN)$/i
            onEditingFinished: value => root.commit("overview", value)
        }

        TextFieldRow {
            label: Tr.tr("Application chooser")
            value: Keybinds.launcher
            validate: /^(SUPER|ALT|CTRL)( \+ (SUPER|ALT|CTRL|SHIFT))* \+ ([A-Z0-9]+|SPACE|TAB|ENTER|ESC|BACKSPACE|DELETE|LEFT|RIGHT|UP|DOWN)$/i
            onEditingFinished: value => root.commit("launcher", value)
        }

        TextFieldRow {
            label: Tr.tr("Devine settings")
            value: Keybinds.settings
            validate: /^(SUPER|ALT|CTRL)( \+ (SUPER|ALT|CTRL|SHIFT))* \+ ([A-Z0-9]+|SPACE|TAB|ENTER|ESC|BACKSPACE|DELETE|LEFT|RIGHT|UP|DOWN)$/i
            onEditingFinished: value => root.commit("settings", value)
        }

        TextFieldRow {
            label: Tr.tr("Screenshot selection")
            value: Keybinds.screenshot
            validate: /^(SUPER|ALT|CTRL)( \+ (SUPER|ALT|CTRL|SHIFT))* \+ ([A-Z0-9]+|SPACE|TAB|ENTER|ESC|BACKSPACE|DELETE|LEFT|RIGHT|UP|DOWN)$/i
            onEditingFinished: value => root.commit("screenshot", value)
        }

        TextFieldRow {
            label: Tr.tr("Clipboard history")
            value: Keybinds.clipboard
            validate: /^(SUPER|ALT|CTRL)( \+ (SUPER|ALT|CTRL|SHIFT))* \+ ([A-Z0-9]+|SPACE|TAB|ENTER|ESC|BACKSPACE|DELETE|LEFT|RIGHT|UP|DOWN)$/i
            onEditingFinished: value => root.commit("clipboard", value)
        }

        TextFieldRow {
            label: Tr.tr("File explorer")
            value: Keybinds.explorer
            validate: /^(SUPER|ALT|CTRL)( \+ (SUPER|ALT|CTRL|SHIFT))* \+ ([A-Z0-9]+|SPACE|TAB|ENTER|ESC|BACKSPACE|DELETE|LEFT|RIGHT|UP|DOWN)$/i
            onEditingFinished: value => root.commit("explorer", value)
        }

        NavRow {
            last: true
            icon: "restart_alt"
            text: Tr.tr("Restore defaults")
            onClicked: Keybinds.setDefaults()
        }
    }
}
