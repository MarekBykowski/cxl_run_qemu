# cxl_run_qemu

branches:
- master: branch main is for the system in which the user has sudo rights.
- santa-clara: is for the HOST such as `santa_clara` in which the (regular) users do not have the root rigths. It must have the artifcats copied before running the script
- docker-generic: for containers which are not ready to run dracut and mkosi but which have the sudo rights

Artifacts needed are in this repo packages link.

Pick `docker-generic` if unsure. Howto for downlading artifacts in here https://github.com/MarekBykowski/ghcr-publish-install-packages
