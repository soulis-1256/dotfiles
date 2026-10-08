-- DMS Window Rules — managed by DankMaterialShell
-- Do not edit manually; changes may be overwritten

-- DMS-RULE: id=dms_rule_0, name=
hl.window_rule({ match = { class = "^(steam)$" }, float = true })

-- DMS-RULE: id=dms_rule_1, name=
hl.window_rule({ match = { class = "^(steam)$", title = "^(Steam)$" }, tile = true })

-- DMS-RULE: id=dms_rule_3, name=
hl.window_rule({ match = { class = "^([sS]team.*)$" }, no_shadow = true, no_blur = true })

-- DMS-RULE: id=dms_rule_8, name=
hl.window_rule({ match = { title = ".*[Pp]icture[- ][iI]n[- ][pP]icture.*" }, float = true, pin = true })

-- DMS-RULE: id=dms_rule_9, name=
hl.window_rule({ match = { class = "^(com\\.danklinux\\.dms)$", title = "^(Settings)$" }, float = true, size = { 1100, 700 } })

-- DMS-RULE: id=dms_rule_10, name=
hl.window_rule({ match = { class = "^(org\\.gnome\\.Loupe)$" }, float = true, size = { 1100, 700 } })

-- DMS-RULE: id=dms_rule_11, name=
hl.window_rule({ match = { class = "^(dolphin|org\\.kde\\.dolphin|thunar|nemo|caja|pcmanfm.*|krusader|konqueror|vlc)$" }, float = true, size = { 1100, 700 } })

-- DMS-RULE: id=dms-floating-windows, name=DMS Floating Windows
hl.window_rule({ match = { class = "^com.danklinux.dms$" }, float = true })
