## Function to add a repo to pacman.conf
```bash
migrate-repo() {
	# Add garuda repo if it doesn't exist
	gawk -i inplace 'BEGIN {
        err=1
    }
    {
    if (rm)
    {
        if ($0 ~ /^ *(Include|Server) *=/)
        {
            next
        }
        # Check for empty line
        else if ($0 ~ /^ *$/)
        {
            next
        }
        else
        {
            rm=0
        }
    }
    if ($0 == "[options]")
    {
        print
        next
    }
    else if ($0 == "[garuda]")
    {
      if (set) {
        rm=1
        next
      }
      set=1
    }
    else if ($0 == "[core-testing]")
    {
        print "[testing]"
        err=0
        next
    }
    else if ($0 == "[community-testing]")
    {
        print "[extra-testing]"
        err=0
        next
    }
    else if ($0 == "[community]")
    {
        rm=1
        err=0
        next
    }
  }
  /^\[[^ \[\]]+\]/ {
    if (!set) {
        print "[garuda]"
        print "Include = /etc/pacman.d/chaotic-mirrorlist"
        print ""
        set=1
        err=0
    }
  }
  END {exit err}
  1' /etc/pacman.conf
}
```

# Function to check if a package is installed:
```bash
package-exists-fast() {
	if compgen -G "/var/lib/pacman/local/$1-*" >/dev/null; then
		return 0
	else
		return 1
	fi
}
```
