# Cyrus mailbox loss recovery

The upgrade of Cyrus to 3.6.1 in Debian [can cause complete mailbox loss](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1037346).

The script here (and this doc) will help you recover your mail.

# Overview

There's a migration of the mailbox data from a previous per-user hierarchy, held in `/var/spool/cyrus/mail/<hashletter>/user/<user>` to a new user-agnostic per-folder hierarchy in `/var/spool/cyrus/mail/uuid/<hash_digit_1>/<hash_digit_2>/<uuid>`.

Folder paths/names are mapped to these new UUID directories in a database, and you find out where a specific folder is with `/usr/lib/cyrus/bin/mbpath user.<user>.<folder>` for example: `/usr/lib/cyrus/bin/mbpath user.phil.work` for user `phil`'s "work" IMAP folder.

During the upgrade to 3.6.1 in Debian, many users found all of their email appeared gone. For many users the mail had not been migrated to the new locations. For some especially unlucky users the old mail had also been deleted.

# Recovery

# Ensuring the data still exists (in the old format)

The first thing to do is check that you still have mail in the old format. Look in `/var/spool/cyrus/mail`. Pick a user, for example `phil`, and then look in the <first-letter-of-that-username> -> user -> <username>, for example `p/user/phil`. If this directory is not empty, you (likely) still have all of your data. If not, the first thing you'll need to do is restore `/var/spool/cyrus/mail` from your most recent backups (you **do** have backups, right?). For me, I had to restore from the previous night's backups. There had been a temporary space issue on the device, and so there were a few blocks in the tar file corrupted, so I restored from 2 nights prior, then restored the previous nights on top of that to get as close as possible to a complete restoration.

# Migrating/Recovering the data

The script in this repo will attempt to help you recover your data. Initially written by Kai Lindenberg <kai@ldbg.de>, I've extended and modified it.

The script is incredibly conservative - it will generate two scripts for you, and then have you inspect them and run them yourself. This is to ensure that your data isn't trampled on.

Place the script somewhere and make it executable (`chmod +x recover_cyrus_user.sh`).

For each user on your system, you'll run `recover_cyrus_user.sh <full_user_hash>`. So for example, `recover_cyrus_user.sh p/user/phil`.

The script will first walk all folders it can find for that user, and then generate a script you will pass to `cyradm` to generate those folders (which will create the UUID directories). It will then spawn a shell so you may inspect the script and pass it to `cyradm`. It'll look like this:

```shell
# recover_cyrus_user.sh p/user/phil
starting shell to examine the situation
creatembx.cyradm created to feed cyradm
please review the file and then:
   cat creatembx.cyradm | cyradm --user cyrus localhost
once complete, continue with "exit"'
#
```

You cna then look at `creatembox.cyradm` with your favorite editor, or `less` or whatever you choose. When you're happy run it as the script instructs with `cat creatembx.cyradm | cyradm --user cyrus localhost`, and enter the `cyrus` password. If you've setup cyrus to have a different user be the admin, adjust accordingly.

Then type `exit` and the script will create a shell script which *hardlinks* files from the new path to the old path.

Why hardlinks? Well, for one, we're gauranteed to be on the same filesystem here, so they'll definitely work. Second, not copying avoids space issues. Third, by hardlinking (instead of symlinking), if we ever want to remove the original paths, we can.

The script will then tell you to inspect the script and run it, as well as tell you how to recover the inbox (it does not do this for you for safety reasons). It will look like this:

```shell
...
# exit
linkmbx.bash created, please review before executing and then run it
manual work:
1. might be too many argument, review output
2. main inbox not linked, create inbox_recovered and link the contents
```

Inspect `linkmbx.bash` and then run it (as root):

```shell
# bash ./linkmbx.bash
```

If there's any errors, inspect, and fix.

Finally you can recover the user's inbox an as `inbox_recovered` (so as not to mess with any email received since the migration, by doing the following. First create a new, empty `inbox_recovered` in the new strufture using `cyradm`:

```shell
# cyradm --user cyrus localhost
> cm user.<whatever>.inbox_recovered
> ^D
```

For example, that might be `cm user.phil.inbox_recovered`.

Then cd into the path to this new directory and link the old inbox to it:

```shell
# cd $(mbpath user.<whatever>.inbox_recovered)
ls -f /var/spool/cyrus/mail/<hashletter>/user/<whatever>/ | xargs -I{} ln -f '/var/spool/cyrus/mail/<hashletter>/user/<whatever>/{}' .
```

For example that might be `ls -f /var/spool/cyrus/mail/p/user/phil/ | xargs -I{} ln -f '/var/spool/cyrus/mail/p/user/phil/{}' .

# Final words

The script could do a lot more on its own with extra error checking. Both Kai and I only had a few users to recover, and so this was enough of the process automated to suffice. I've added a variety of safety checks to the script, but there's still many things that can go wrong. If you have many users, this may not be enough and it may be worth having the script actually run the commands instead of generating scripts and recovering the inboxes as well. PRs welcome.
