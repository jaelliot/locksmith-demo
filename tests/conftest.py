import os

# Must be set before any Qt import so tests run headlessly on CI and on machines
# without a display (e.g. SSH sessions, preflight checks).
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
