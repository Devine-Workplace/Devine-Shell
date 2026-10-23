pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    property string popupSide: "right"
    property bool showImagePreviews: true
    property bool loading: true

    function save(): void {
        if (loading)
            return;
        settingsFile.setText(JSON.stringify({
            popupSide,
            showImagePreviews
        }, null, 2));
    }

    onPopupSideChanged: save()
    onShowImagePreviewsChanged: save()

    FileView {
        id: settingsFile
        path: Paths.config + "/clipboard.json"
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                root.popupSide = saved.popupSide === "left" ? "left" : "right";
                root.showImagePreviews = saved.showImagePreviews !== false;
            } catch (e) {}
            root.loading = false;
        }
        onLoadFailed: root.loading = false
    }
}
