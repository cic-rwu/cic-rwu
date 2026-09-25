Find 8 flags in your container in 45 minutes (2 bonus flags if you finish early).
Every flag will look like `CIC{...}`

# Getting Started

Login with the address or hostname provided to you:
```bash
ssh cic-guest@{container IP}
```
- This container is yours to break
- Each task gives you a goal and a hint. If you're stuck, try `man {command}` or `{command} --help`
- Really stuck? Ask one of the officers for assistance
- Keep track of your found flags at the bottom of this document

# 1 - Navigation

### 1.1 - Where am I?

>Find out *which directory you're in*, *list what is there*, and *read the file inside **welcome***

*Hint*: `pwd ls cd cat`

---

### 1.2 - Hidden in plain sight

>Your home directory contains a file that plain `ls` won't show.

*Hint*: Files beginning with `.` are hidden. See if there is a flag for `ls` that will show them. (`ls --help`)

### 1.3 - Deep Dive

>A flag sits at the bottom of `/opt/cic/maze`. See if you can find it

*Hint*: **Tab** will autocomplete file names. `cd ..` goes up a level, while `cd ~` goes home.
___

# 2 - Reading and Searching (15 mins)

### 2.1 - The Last Word

> `/var/log/cic/server.log` is 5,000 lines long. The flag is on the very last line.

*Hint*: Don't cat it all, maybe theres a command for this? (*head*, *tail*, *less*).

### 2.2 - Needle in A Haystack

> One of the 10,000 lines in `/opt/cic/haystack.txt` holds a flag.

*Hint*: `grep` prints only the lines that match a pattern. What do all the flags start with?

### 2.3 - Lost File

> A file named `lost_flag.txt` is somewhere on the system. Nobody remembers where.

*Hint*: `find -name`


# 3 - Permissions (10 mins)

### 3.1 - Locked Out

> `~/locked.txt` is your file, but `cat` says *permission denied*. Fix the permissions for the key to the next flag.

*Hint*: `ls -l` shows permissions, `chmod u+r` gives the owner read access

### 3.2 - Run it

> `~/run_me.sh` prints a flag when it runs. Try `./run_me.sh` and read the error.

*Hint*: Scripts need the `+x` (execute) bit to run.


# Bonus

### b.1 - Count Them

> How many lines in `/opt/cic/words.txt` contain the word `tux`? The flag is `CIC{that number}`

*Hint*: The pipe `|` sends *one commands output into another*. Try piping `grep` into `wc -l`.

### b.2 - Something's Running

> A process on your container has a flag in its command line

*Hint* `ps aux` lists every process. Try piping it ( `|` ) into `grep`.