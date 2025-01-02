To synchronize only ownerships, permissions, ACLs, and attributes without ever replacing or modifying file contents—even if the file sizes differ—you can use rsync in metadata-only mode with the --no-W option. Here’s how to achieve it:

Command for Metadata Synchronization

sudo rsync -aAXv --progress --no-W --omit-dir-times --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /mnt/target_root

Explanation of Options

	•	-aAX: Standard rsync archive mode, preserving:
	•	-a: Recursive copy with ownerships, permissions, and symbolic links.
	•	-X: Preserve extended attributes.
	•	-A: Preserve ACLs.
	•	--no-W: Ensures whole files are not replaced, regardless of changes in size or modification time.
	•	--omit-dir-times: Prevents unnecessary updates of directory modification times.
	•	--progress: Displays file-by-file progress.
	•	--exclude: Avoids syncing virtual or ephemeral directories like /proc or /tmp.

This setup ensures only metadata like ownership, permissions, ACLs, and extended attributes are synchronized without touching file content.

Dry-Run Mode to Verify

Before running the actual command, always verify with --dry-run:

sudo rsync -aAXv --progress --no-W --omit-dir-times --dry-run --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /mnt/target_root

This will list the actions rsync would take without applying any changes.

What Happens in This Mode

	1.	File Contents: No files are replaced or written to, even if their size differs.
	2.	Metadata Applied:
	•	Ownership (chown equivalent).
	•	Permissions (chmod equivalent).
	•	ACLs (setfacl equivalent).
	•	Extended attributes (setfattr equivalent).

Logging Changes

Add --log-file to capture a log of actions performed:

sudo rsync -aAXv --progress --no-W --omit-dir-times --log-file=/var/log/rsync_metadata.log --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /mnt/target_root

To filter for metadata changes in the log, look for lines mentioning permissions, ownership, or attributes being updated.

Final Note

This configuration ensures:
	•	File contents remain untouched.
	•	Only metadata is synchronized (ownership, permissions, ACLs, extended attributes).
	•	Directories and excluded paths are properly handled.

This approach is ideal for scenarios where only file attributes need to match between two systems, without impacting the file data itself.