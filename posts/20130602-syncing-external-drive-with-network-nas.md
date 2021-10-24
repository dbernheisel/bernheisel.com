%{
  title: "Syncing an External USB Drive with a Network NAS",
  tags: ["bash"],
  description: """
  I recently bought a MacBook Pro with a limited 256GB SSD. It's great, btw, but it requires me to now store all my music, movies, and archival-type files on an external drive. It scares me a bit to have all that stuff on a single USB-powered drive, so I also set up a network NAS that contains 2 mirrored 1TB drives (I salvaged these from my desktop that I sold to buy my MacBook).

  Enter problem: I'm lazy. I don't like manually backing everything up. I just want to manage the stuff I put on the external drive, not the NAS drive. Enter solution: BASH script, and launchd.
  """
}
---

I recently bought a MacBook Pro with a limited 256GB SSD. It's great, btw, but it requires me to now store all my music, movies, and archival-type files on an external drive. It scares me a bit to have all that stuff on a single USB-powered drive, so I also set up a network NAS that contains 2 mirrored 1TB drives (I salvaged these from my desktop that I sold to buy my MacBook).

Enter problem: I'm lazy. I don't like manually backing everything up. I just want to manage the stuff I put on the external drive, not the NAS drive. Enter solution: BASH script, and launchd.

## Overview

1. I write BASH scripts at work, so this was my goto place for automating something I don't want to do.
1. I use a mac, so I used launchd to kick off the script when relevant
1. I want to know when its running, so I used an icon I found on the internet to make it look pretty, and placed the lock folder on my desktop.


## Getting the core logic:

Here's the BASH Script in its entirety:

```sh
#!/bin/bash
remote="/Volumes/Volume_1"
LOCAL="/Volumes/Storage"
LOCK=~/Desktop/Syncing
logging=~/backup-rsync-log.txt
sleeptime=20
maxthreads=20
set -e

function cleanup {
  echo "Removing Syncing folder"
  rm -rf $LOCK
}

trap cleanup EXIT
mkdir $LOCK || { echo "Backup already running" ; exit 1 ; }
Rez -append ~/backup.rsrc -o ~/Desktop/Syncing/$'Icon\r' # set the icon to lock folder
SetFile -a C ~/Desktop/Syncing # initiate the icon
SetFile -a V ~/Desktop/Syncing/$'Icon\r' # hide the icon file
sleep 15 # give time for mounting

# Check if external drive is mounted
if mount | grep "on ${LOCAL}" > /dev/null; then
  echo "Storage drive is mounted"

  # Check if network NAS is mounted
  if mount | grep "on ${remote}" > /dev/null; then
    echo "Remote NAS is mounted"
    echo "Running rsync"

    # loop over all root external drive folders and do an rsync for each, up to a limit
    for dir in "$LOCAL"/*/; do
      folder=`basename "$dir"`

      # create the folder if it doesn't exist, keeping permissions
      if [ ! -d "${remote}/${folder}" ]; then
        mkdir -p "$remote"/"$folder"
        chown --reference="$dir" "${remote}/${folder}"
        chmod --reference="$dir" "${remote}/${folder}"
      fi
      echo -e "\nStarting rsync $(date +%Y%m%d_%H%M%S) of" $dir >> $logging

      # don't go crazy with rsync, so limit it
      while [ `ps -ef | grep -c [r]sync` -gt ${maxthreads} ]; do
        sleep ${sleeptime}
      done

      # start rsync parallel threads.
      nohup rsync -avh --delete "$dir" "$remote"/"$folder"/ >$logging 2>&amp;1 &amp;
    done
    wait
    echo "Done"
  else
    echo "Remote NAS is NOT mounted"
  fi
else
  echo "Storage drive is NOT mounted"
fi
```

There's a good amount of logic in there, so let's go through it.

I don't like hardcoding stuff I have to say over and over, so I start by naming the variables in case I need to reuse this code later. The variables are
- My external hard drive, put into `$LOCAL`
- My network NAS drive, put into `$remote`
- My rsync limiter, put into `$maxthreads`
- How long I want rsync to wait before trying to launch another thread, put into `$sleeptime`
- Where I want the double-purposed folder, 1) to ensure I only have one of these scripts running at a time, and 2) visually tell me when the script is running; this is put into `$LOCK`
- Lastly, so I can debug if needed, I log all the actions into a text file, put into `$logging`

So now that I have everything named. Now it's time for some real logic.

I start out by checking whether my script is already running. I check by attempting to create a folder. If the folder is already created, it'll fail, and then exit the script. Pretty simple. I can't tell you the specifics, but creating a folder is a great way of setting up a lock without conflicts, from what I've read online. In my script, I also used the folder as a status to inform me when the script is running. I also thought about creating a simple menubar app that'll show a spinning gear, but I don't really feel like overengineering this.

So, I have my safety set so I'm not executing this script over on top of itself. Now I need to determine whether my necessary drives are mounted, I do this by nesting two if statements; one to check if the external drive is mounted, and another to check if the NAS is mounted. Obviously, I don't want anything to happen unless the drives are mounted. If they're not mounted, I exit.

Next, I go through the folders in the root of the external drive. I want to be somewhat recursive, so I do a for loop over the root folders on the drive, and start an rsync on each folder. For that to work, I need to make sure the destination folder is created, preferably with the same permissions.

If you have one root folder with a bunch of subfolders (for example a Music folder with a bunch of Artist subfolders), then it might be good for you to start your loop there so this is a more-effective script.

Inside every folder, I start an rsync thread distributed among the folders. However, I don't want to stress my computer out with a thousand rsync threads, so before I start a new thread, I check to see how many there are and possibly limit it (for me, I arbitrarily chose a 20 thread cap). I determine this by counting how many rsync processes there are, so I execute ps, pipe it to grep to grab what I need. the grep -c flag counts them. Then, I compare it to my previously-defined cap. If it's at the limit, then I put it in a while loop that sleeps until the thread count is back down.

If you're familiar with command line operations, then you should read up on the rsync manual (run "man rsync" in the terminal). There's a lot of nifty things you can do with this, for example, you can backup over SSH or SFTP. I opted for the flags -a (archive, aka carry over all the permissions and recurse any subdirectories), -v (be verbose, I want this so I can catch everything it's doing and redirect that to my log file in `$logging`), and -h (output human-readable stuff, so I don't have to count the zeros in all the file sizes).

Lastly (as far as the script goes), I want to make sure that whenever my script exits, be it because of an error or anything else, I want my lock/status folder is removed. To accomplish this, I just trapped any kind of exit by executing a small function that removes the lock folder. I put it near the top since it needs to be defined before it could be used. Sometimes I forget that you can create functions in BASH.

This can be optimized more, but this is where I'm finished since it achieves my goal of lazily backing up my external hard drive. If you have ideas, drop them in the comments or link out to your explanation!


## Launching it when I need to.

So far, we just have a script that we have to manually kick off in order for it to work. I am still too lazy and instead want my $2000 computer to do the work for me. I was tempted to just use cron to have this script run automatically every 5 minutes, but I thought that was wasteful, since it's probable that this script will fail most times it's launched. I read around and found Mac's tool called launchd, which watches for events, and then launches actions.

I'm unfamiliar with plists still, so I really just piggybacked on the backs of other giants. Step 3 on this page shows me how to do this (btw, this  guy solves the same problem here, but does it differently; check his solution out if you're interested). Summed up, create a plist, place it in your ~/Library/LaunchAgents folder (tilde represents your home folder), and you're done!

The important bits of the .plist file are the
- Program
- WatchPaths
- LowPriorityIO

For the program key, I'm putting the path to the BASH script I created above.

For the WatchPaths key, I'm putting in /Volumes directory, since I want this script to launch every time something changes in /Volumes. You could change this to the specific name of your drive as well--it should work the same and probably better.

For the LowPriorityIO key, I'm putting the "YES" value, so I can tell my computer to not really give a lot of resources to this script. Again, I want this to be nearly invisible to me--I'd hate to feel my computer choke just because of a backup script.

You still need to add a label to the plist, so call it whatever you want.

Save it, and place it in your ~/Library/LaunchAgents folder. Restart.

Now you should have a fully working solution.

## Making it look *slightly* better

I'm not _quite_ finished yet. I wanted to have my lock folder be pretty with an icon, so I went back to my BASH script and added a couple lines to set the folder icon. I found the commands here [Stack Exchange](https://apple.stackexchange.com/questions/6901/how-can-i-change-a-file-or-folder-icon-using-the-terminal).

First, grab an icon you want. I supplied one already, but you might have a different preference. I found mine by googling, and you might find it helpful to google with "filetype:png" so you find an icon with transparency. Find an icns conerter and convert it to Mac-compatible .icns.

Second, create a new temporary folder. We're going to apply this icon to it so we can grab a file we need from it once it's set. Then, right-click the folder, and drag-and-drop the .icns file to the Icon in the top left.

Third, run a command-line tool against the folder.

`DeRez -only icns path/to/tempfolder/$'Icon\r' > backup.rsrc`

This will give you what you need in order to set the lock folder icon. Store this file somewhere you don't look often (I stored mine next to the backup script in my home folder). You can delete the temporary folder now and the original image you downloaded.

Fourth, modify the backup script to apply the icon.

After the line where we make the lock folder, run a Rez command and a couple SetFile commands.

`Rez -append ~/backup.rsrc -o ~/Desktop/Syncing/$'Icon\r' # set the icon to lock folder`

`SetFile -a C ~/Desktop/Syncing # initiate the icon`

`SetFile -a V ~/Desktop/Syncing/$'Icon\r' # hide the icon file`

The first command adds the icon to the lock directory.

The second command sets the folder attributes, which allows Finder to appreciate your new icon (otherwise, it won't recognize that cool icon you added)

The third command sets the folder to invisible. This is totally optional, but if you ever double-click the "Syncing" folder you'll find the icon resource, and that just seems ugly to me--so let's hide it.

*OK! YOU'RE DONE!*

I guess I'm not so lazy after all.
