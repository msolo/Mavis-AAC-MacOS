# NSUserDefaults

Data doesn't match when you have a containerized version of the application storage.

Correct: `plutil -p Library/Preferences/com.lazybearlabs.MavisAAC.plist`

Wrong: `defaults com.lazybearlabs.MavisAAC`

Container seems to take precendence.

Deleting the stale container restores correct behavior.
