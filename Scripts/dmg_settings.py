"""A two-icon installer. Loaded by dmgbuild with explicit app and asset paths."""
from pathlib import Path

application = Path(defines["app"])
assets = Path(defines["assets"])
format = "UDZO"
filesystem = "HFS+"
files = [str(application)]
symlinks = {"Applications": "/Applications"}
icon = str(assets / "AppIcon.icns")
background = str(assets / "DMGBackground.tiff")
# Do not alter the signed app's FinderInfo attributes when packaging it.
icon_locations = {application.name: (170, 190), "Applications": (470, 190)}
window_rect = ((180, 180), (640, 360))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
arrange_by = None
grid_spacing = 80
icon_size = 112
text_size = 13
label_pos = "bottom"
