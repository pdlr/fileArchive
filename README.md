# fileArchive
This is a simple collection of scripts for automated backup of a Unix/Linux machine to a locally attached hard drive.  I wrote it in the mid-1990s, when I didn't have an easy backup solution.  It's worked well since then, so I'm still using it, even though there are now many other backup options easily available.

## How it Works
Everything is driven by the cron service.  Backups are made by firing off a python script that spiders your filesystem, creating  a series of .tgz files containing backed-up data, plus an index showing what files are saved in what tarball.  The default configuration does a full backup every Sunday morning, and an incremental backup every other day of the week.  Incremental backups are based on the file modification timestamp, so -- for example -- Thursday's incremental backup includes everything that's changed since the last Sunday.

There's functionality to mount and unmount your backup drive if you like.

## Caveats and Warnings
The only major failing I've been bitten by is if you don't check log files, it's possible to have a persistent failure without being aware of it.  For example, if you backup drive fills up, this utility won't give you a popup dialog box warning you.

The concern about disk space can grow over time.  By default, fileArchive makes a full backup every week (weekly backups are kept around for two weeks), a full backup every month (monthly backups are kept around for two months), a full backup every six months (semiannual backups are kept around for one year), and a full backup every year (yearly backups are kept around for two years).  This means that backup space requirements grow until the beginning of the second year, when there will be a total of 8 full backups stored on the backup drive.  You can reduce this by creating fewer backups (i.e., by editing cron.d/fileArchive_backup), or by modifying the fileArchive program so that it doesn't simply replaces each archive, rather than keeping it around for an additional week/month/5-months/year.

**One potential security risk:** this is a 500-ish line python script that interacts with arbitrary files on your machine, was written by somebody without a strong security background, spawns external programs, and has publicly available source code.  It's probably an attractive attack surface if bad guys have a way to put files on your filesystem.  Especially so if you choose to run it as root.  Please don't hold back on comments and criticism if you see vulnerabilities in the source code.

## Getting Started
 1. Set up your backup drive.  Be sure to set the LABEL of the newly created filesystem to something like FA_BACKUP.  You'll use this label in the next step:
    * \# cfdisk /dev/<block device name\>
    * \# mkfs.ext4 /dev/<partition id\>
 2. Configure your machine to mount the backup drive:
    * \# mkdir /backup
    * Copy the contents of the file fstab_entry.txt to the end of your /etc/fstab file, being sure to edit the LABEL field so it matches the label you used when setting up your backup drive.  If you plan to run fileArchive as a non-privileged user, you may want to change "noauto,rw,noexec,nosuid,nodev,async" to "user,noauto,rw,noexec,nosuid,nodev,async"
  3. Mount the backup drive, and set up the appropriate directory structure.  This directory structure is described in the comment at the top of the file cron/fileArchive_backup.  You can also see the supplied script file setupDirectoryStructure.sh for shell code that makes these directories.
    * IMPORTANT: Make sure to set the access permissions on these directories so that arbitrary users can't browse the backup files to see content they shouldn't be able to see.
  4. Edit the file cron/fileArchive_backup to your liking, and copy it to /etc/cron.d/.

Note that the "noauto" field in the fstab entry, and the "-m /backup" flag in the cron file will normally leave the backup drive unmounted, and try to mount/unmount whenever backups are generated.

## Exempting Files from Backup
There are often files or directories that you don't want to have backed up.  For example, if you mount external filesystems to your local drive, you may not want fileArchive to spider those filesystems.  Similarly, you might have large virtual machine files or data directories that you don't want to back up repeatedly.

To avoid backing up a file or directory, simply create file with the same name and the extension ".noBackup" so that fileArchive knows to skip it.  This file must be in the same directory as the file or directory that you want to exempt from backup.  For example:

      > touch my_data_directory.noBackup
      > touch file_I_do_not_want_to_backup.bin.noBackup
      > ls -1C
        an_important_file.txt
        an_important_directory/
        file_I_do_not_want_to_backup.bin
        file_I_do_not_want_to_backup.bin.noBackup
        my_data_directory/
        my_data_directory.noBackup

## The Archive
In the default configuration, the backup includes the following files:

    /backup
      /tar_Monday                       # An incremental backup containing only
                                        #   files with modification dates since
                                        #   last Sunday.
          incremental_index.txt         # A list indicating which files are
                                        #   backed up in which .tgz archive.
          incremental_0000.tgz          # A series of .tgz archives containing
          incremental_0001.tgz          #   all of the backed-up files.
          [...]
          incremental_index.txt.backup  # Last week's files are kept around for
          incremental_0000.tgz.backup   # for one extra week, then deleted.
          incremental_0001.tgz.backup
          [...]
      /tar_Tuesday                      # Incremental backups are created every
      /tar_Wednesday                    #   weekday except Sunday.
      /tar_Thursday
      /tar_Friday
      /tar_Saturday
      /tar_Sunday                       # A full backup is created every week.
          full_index.txt                # A list indicating which files are
                                        #   backed up in which .tgz archive.
          full_0000.tgz                 # A series of .tgz archives containing
          full_0001.tgz                 #   all of the backed-up files.
          [...]
          full_index.txt.backup         # Last week's files are kept around for
          full_0000.tgz.backup          # for one extra week, then deleted.
          full_0001.tgz.backup
          [...]
      /tar_monthly                      # A full backup is created every month.
      /tar_semiannual                   # A full backup is created semiannually.
      /tar_annual                       # A full backup is created annually.

## Restoring Files
There are two ways to restore a file or directory. The direct way is to find it in the index file of a recent backup (e.g., /backup/tar_Wednesday/incremental_index.txt), then search backward in the index file for the preceding "New archive" line.  At this point you know the name of the file or directory, and the .tgz file that contains it, so you can manually extract the backed up file using the "tar -zx ..." command.

Alternatively, you can use the fileRestore python script.  You invoke it like 
this:

      # fileRestore /backup/full_Sunday/full_index.txt <regular_expression>

where <regular_expression\> is a regular expression in the syntax of the python re module that matches the filename of the files or directories you'd like to extract.  I've used the fileRestore script much less than the other parts of this repo, so it likely has more issues per line than the rest of the code.  Please proceed with caution.

Note that files are stored in the archives using relative filenames that capture the full path of the file.  So a backup of a file in your home directory will be saved with the path:

      home/username/path/to/file

This means that when you restore files, they will be unpacked into a local directory that has the same relative structure as the root directory at the time that the backup was created.  If you run the command from the root directory, the restored files will theoretically be written to the right places, but this is far too scary for me.  Much better to create a temporary directory, restore the files there, and then copy them to their respective homes.  This also gives you a chance to make sure file ownership, access permissions, etc., are correct in the restored copies.

