pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Devine.Config
import Devine.I18n
import qs.utils

Singleton {
    id: root

    property string osName
    property string osPrettyName
    property string osId
    property list<string> osIdLike
    property string osLogo
    property string systemLogo
    readonly property list<var> distroLogoCandidates: [
        { name: "Arch Linux", icons: ["archlinux", "distributor-logo-archlinux", "arch"] },
        { name: "AlmaLinux", icons: ["almalinux", "distributor-logo-almalinux"] },
        { name: "Alpine Linux", icons: ["alpine", "alpinelinux", "distributor-logo-alpine"] },
        { name: "CachyOS", icons: ["cachyos", "cachyos-logo", "distributor-logo-cachyos"] },
        { name: "Debian", icons: ["debian", "distributor-logo-debian"] },
        { name: "EndeavourOS", icons: ["endeavouros", "distributor-logo-endeavouros"] },
        { name: "elementary OS", icons: ["elementary", "distributor-logo-elementary"] },
        { name: "Fedora", icons: ["fedora", "distributor-logo-fedora"] },
        { name: "Garuda Linux", icons: ["garuda", "garuda-linux", "distributor-logo-garuda"] },
        { name: "Gentoo", icons: ["gentoo", "distributor-logo-gentoo"] },
        { name: "Kali Linux", icons: ["kali", "kali-linux", "distributor-logo-kali"] },
        { name: "Linux Mint", icons: ["linuxmint", "distributor-logo-linuxmint"] },
        { name: "Manjaro", icons: ["manjaro", "distributor-logo-manjaro"] },
        { name: "Mageia", icons: ["mageia", "distributor-logo-mageia"] },
        { name: "MX Linux", icons: ["mx-linux", "mxlinux", "distributor-logo-mx"] },
        { name: "NixOS", icons: ["nixos", "nix-snowflake", "distributor-logo-nixos"] },
        { name: "openSUSE", icons: ["opensuse", "distributor-logo-opensuse"] },
        { name: "Pop!_OS", icons: ["pop-os", "pop", "distributor-logo-pop-os"] },
        { name: "Rocky Linux", icons: ["rocky", "rocky-linux", "distributor-logo-rocky"] },
        { name: "Red Hat", icons: ["redhat", "red-hat", "distributor-logo-redhat"] },
        { name: "Slackware", icons: ["slackware", "distributor-logo-slackware"] },
        { name: "Solus", icons: ["solus", "distributor-logo-solus"] },
        { name: "Ubuntu", icons: ["ubuntu", "distributor-logo-ubuntu"] },
        { name: "Zorin OS", icons: ["zorin", "zorin-os", "distributor-logo-zorin"] },
        { name: "Void Linux", icons: ["void", "distributor-logo-void"] }
    ]
    readonly property list<var> distroLogos: distroLogoCandidates.map(item => {
        const icon = item.icons.find(name => Quickshell.iconPath(name, true));
        return icon ? { name: item.name, value: icon, path: Quickshell.iconPath(icon, true) } : null;
    }).filter(item => item)
    readonly property list<var> logoOptions: [
        { name: "System logo", value: "", path: root.systemLogo },
        ...root.distroLogos
    ]

    property string uptime
    // Uptime trimmed to its two largest components
    property string uptimeShort
    readonly property string user: Quickshell.env("USER")
    readonly property string wm: Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("XDG_SESSION_DESKTOP")
    readonly property string shell: Quickshell.env("SHELL").split("/").pop()

    property string kernel
    property string hostname
    property string firmware

    // DMI vendor/model, combined into a single human-readable device name
    property string boardVendor
    property string boardName
    readonly property string device: {
        if (!boardName)
            return boardVendor;
        if (!boardVendor || boardName.toLowerCase().startsWith(boardVendor.toLowerCase()))
            return boardName;
        return `${boardVendor} ${boardName}`;
    }

    // Strips the placeholder strings OEMs commonly leave in DMI fields
    function sanitiseDmi(s: string): string {
        const t = s.trim();
        const junk = ["to be filled by o.e.m.", "system product name", "system manufacturer", "system version", "default string", "o.e.m.", "not specified", "not applicable", "unknown", "none", ""];
        return junk.includes(t.toLowerCase()) ? "" : t;
    }

    function updateLogo(): void {
        const configured = GlobalConfig.general.logo;
        if (configured && configured !== "devine") {
            root.osLogo = Quickshell.iconPath(configured, true) || "file://" + Paths.absolutePath(configured);
            return;
        }
        root.osLogo = root.systemLogo || Quickshell.iconPath(root.osId, true) || Quickshell.iconPath("computer", true);
    }

    FileView {
        id: osRelease

        path: "/etc/os-release"
        onLoaded: {
            const lines = text().split("\n");

            const fd = key => lines.find(l => l.startsWith(`${key}=`))?.split("=")[1].replace(/"/g, "") ?? "";

            root.osName = fd("NAME");
            root.osPrettyName = fd("PRETTY_NAME");
            root.osId = fd("ID");
            root.osIdLike = fd("ID_LIKE").split(" ");
            root.systemLogo = Quickshell.iconPath(fd("LOGO"), true);
            root.updateLogo();
        }
    }

    Connections {
        function onLogoChanged(): void {
            root.updateLogo();
        }

        target: GlobalConfig.general
    }

    FileView {
        path: "/proc/sys/kernel/osrelease"
        onLoaded: root.kernel = text().trim()
    }

    FileView {
        path: "/proc/sys/kernel/hostname"
        onLoaded: root.hostname = text().trim()
    }

    FileView {
        path: "/sys/class/dmi/id/sys_vendor"
        printErrors: false
        onLoaded: root.boardVendor = root.sanitiseDmi(text())
    }

    FileView {
        path: "/sys/class/dmi/id/product_name"
        printErrors: false
        onLoaded: root.boardName = root.sanitiseDmi(text())
    }

    FileView {
        path: "/sys/class/dmi/id/bios_version"
        printErrors: false
        onLoaded: root.firmware = root.sanitiseDmi(text())
    }

    Timer {
        running: true
        repeat: true
        interval: 15000
        onTriggered: fileUptime.reload()
    }

    FileView {
        id: fileUptime

        path: "/proc/uptime"
        onLoaded: {
            const up = parseInt(text().split(" ")[0] ?? 0);

            const days = Math.floor(up / 86400);
            const hours = Math.floor((up % 86400) / 3600);
            const minutes = Math.floor((up % 3600) / 60);

            // TRANSLATORS: joins uptime components, e.g. "2 days, 3 hours"
            const sep = Tr.trCtx(", ", "uptime component separator");

            const parts = [];
            if (days > 0)
                parts.push(Tr.trN("%n day", "%n days", days));
            if (hours > 0)
                parts.push(Tr.trN("%n hour", "%n hours", hours));
            if (minutes > 0 || parts.length === 0)
                parts.push(Tr.trN("%n minute", "%n minutes", minutes));

            root.uptime = parts.join(sep);
            root.uptimeShort = parts.slice(0, 2).join(sep);
        }
    }
}
