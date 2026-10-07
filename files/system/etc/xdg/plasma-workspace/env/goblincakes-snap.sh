# GOBLINCAKES: runs at every login, before Plasma starts (sourced, so no "exit").
# Snap programs (e.g. Claude desktop) put their menu entries in /var/lib/snapd/desktop.
# snapd adds that folder to XDG_DATA_DIRS in /etc/profile.d, which a Plasma session
# doesn't always read – then installed snaps are missing from AppGrid and the dock.
case ":${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:" in
    *:/var/lib/snapd/desktop:*) ;;
    *) export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:/var/lib/snapd/desktop" ;;
esac
