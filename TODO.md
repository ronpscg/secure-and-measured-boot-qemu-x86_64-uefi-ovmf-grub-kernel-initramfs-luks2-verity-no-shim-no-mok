- Probably separating some things from common.sh
- Moving all the mkfs.ext4 dependent files (rootfs, bootfs) to use the common function in the newly introduced datafs creation function (done) and moving the files to make main less dense (will not do now)
- GRUB key creation - there is full automation (no need for user interaction) in the docker/... folder.  **In general, basically merge setup completely probably, and get it out of the bindmounts/modify how things are.**
- Maybe exporting etc.
- It would be nicer to cleanup and have folders inside GRUB
- Update README.md and maybe STEPS.md (which is the more accurate README but they have not been updated, I think since the docker readmes, and I don't think I plan to update them either"


I will not do a dedicated installer and recovery, at least not now. But it's very easily doable.
