NixOS on virsh
--------------

This is very simple and naive implementation.

It forces you to have virsh in system mode (so you can setup a network through virsh daemon).
Probably you want

```
export VIRSH_DEFAULT_CONNECT_URI=qemu:///system
```

You must also set some directory where images are stored (must be writable by user)

```
export XC_VIRSH_IMAGES_PATH=/mnt/virsh-images
```

This implementation is just a toy. A lot of implementations have shortcuts, like no checking ssh fingerprints, 
like sequential nix images building, with no caching (can be slow).

Really, just make your own implementation and/or contribute :-)

