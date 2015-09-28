#!/bin/sh

if [ -z "$SIM_ROOT" ]; then
    echo "$0: SIM_ROOT not defined.\n\tPlease define SIM_ROOT and then re-run $0"
    exit
fi

echo "Setting up symlinks from $SIM_ROOT/S10image."

cd $SIM_ROOT/sam-t2/config/n2/solaris/int12

if [ -f $SIM_ROOT/S10image/1c1t/legion-hv.md ]; then
        /bin/rm -f 1c1t-hv.bin
        echo "Linking $SIM_ROOT/S10image/1c1t/legion-hv.md..."
        ln -s $SIM_ROOT/S10image/1c1t/legion-hv.md 1c1t-hv.bin
else
        echo "ERROR: $SIM_ROOT/S10image/1c1t/legion-hv.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/1c1t/legion-guest-domain0.md ]; then
        /bin/rm -f 1c1t-md.bin
        echo "Linking $SIM_ROOT/S10image/1c1t/legion-guest-domain0.md..."
        ln -s $SIM_ROOT/S10image/1c1t/legion-guest-domain0.md 1c1t-md.bin
else
        echo "ERROR: $SIM_ROOT/S10image/1c1t/legion-guest-domain0.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/1c2t/legion-hv.md ]; then
        /bin/rm -f 1c2t-hv.bin 
        echo "Linking $SIM_ROOT/S10image/1c2t/legion-hv.md..."
        ln -s $SIM_ROOT/S10image/1c2t/legion-hv.md 1c2t-hv.bin
else
        echo "ERROR: $SIM_ROOT/S10image/1c2t/legion-hv.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/1c2t/legion-guest-domain0.md ]; then
        /bin/rm -f 1c2t-md.bin
        echo "Linking $SIM_ROOT/S10image/1c2t/legion-guest-domain0.md..."
        ln -s  $SIM_ROOT/S10image/1c2t/legion-guest-domain0.md 1c2t-md.bin
else
        echo "ERROR: $SIM_ROOT/S10image/1c2t/legion-guest-domain0.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/1c8t/legion-hv.md ]; then
        /bin/rm -f 1c8t-hv.bin 
        echo "Linking $SIM_ROOT/S10image/1c8t/legion-hv.md..."
        ln -s $SIM_ROOT/S10image/1c8t/legion-hv.md 1c8t-hv.bin
else
        echo "ERROR: $SIM_ROOT/S10image/1c8t/legion-hv.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/1c8t/legion-guest-domain0.md ]; then
        /bin/rm -f 1c8t-md.bin
        echo "Linking $SIM_ROOT/S10image/1c8t/legion-guest-domain0.md..."
        ln -s  $SIM_ROOT/S10image/1c8t/legion-guest-domain0.md 1c8t-md.bin
else
        echo "ERROR: $SIM_ROOT/S10image/1c8t/legion-guest-domain0.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/2c8t/legion-hv.md ]; then
        /bin/rm -f 2c8t-hv.bin 
        echo "Linking $SIM_ROOT/S10image/2c8t/legion-hv.md..."
        ln -s $SIM_ROOT/S10image/2c8t/legion-hv.md 2c8t-hv.bin
else
        echo "ERROR: $SIM_ROOT/S10image/2c8t/legion-hv.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/2c8t/legion-guest-domain0.md ]; then
        /bin/rm -f 2c8t-md.bin
        echo "Linking $SIM_ROOT/S10image/2c8t/legion-guest-domain0.md..."
        ln -s  $SIM_ROOT/S10image/2c8t/legion-guest-domain0.md 2c8t-md.bin
else
        echo "ERROR: $SIM_ROOT/S10image/2c8t/legion-guest-domain0.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/4c8t/legion-hv.md ]; then
        /bin/rm -f 4c8t-hv.bin 
        echo "Linking $SIM_ROOT/S10image/4c8t/legion-hv.md..."
        ln -s $SIM_ROOT/S10image/4c8t/legion-hv.md 4c8t-hv.bin
else
        echo "ERROR: $SIM_ROOT/S10image/4c8t/legion-hv.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/4c8t/legion-guest-domain0.md ]; then
        /bin/rm -f 4c8t-md.bin
        echo "Linking $SIM_ROOT/S10image/4c8t/legion-guest-domain0.md..."
        ln -s  $SIM_ROOT/S10image/4c8t/legion-guest-domain0.md 4c8t-md.bin
else
        echo "ERROR: $SIM_ROOT/S10image/4c8t/legion-guest-domain0.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/8c8t/legion-hv.md ]; then
        /bin/rm -f 8c8t-hv.bin 
        echo "Linking $SIM_ROOT/S10image/8c8t/legion-hv.md..."
        ln -s $SIM_ROOT/S10image/8c8t/legion-hv.md 8c8t-hv.bin
else
        echo "ERROR: $SIM_ROOT/S10image/8c8t/legion-hv.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/8c8t/legion-guest-domain0.md ]; then
        /bin/rm -f 8c8t-md.bin
        echo "Linking $SIM_ROOT/S10image/8c8t/legion-guest-domain0.md..."
        ln -s  $SIM_ROOT/S10image/8c8t/legion-guest-domain0.md 8c8t-md.bin
else
        echo "ERROR: $SIM_ROOT/S10image/8c8t/legion-guest-domain0.md not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/disk1.img ]; then
        /bin/rm -f disk1.img
        echo "Linking $SIM_ROOT/S10image/disk1.img..."
        ln -s  $SIM_ROOT/S10image/disk1.img
else
        echo "ERROR: $SIM_ROOT/S10image/disk1.img not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/nvram.bin ]; then
        /bin/rm -f nvram1
        echo "Linking $SIM_ROOT/S10image/nvram.bin..."
        ln -s  $SIM_ROOT/S10image/nvram.bin nvram1
else
        echo "ERROR: $SIM_ROOT/S10image/nvram.bin not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/openboot.bin ]; then
        /bin/rm -f openboot.bin
        echo "Linking $SIM_ROOT/S10image/openboot.bin..."
        ln -s  $SIM_ROOT/S10image/openboot.bin
else
        echo "ERROR: $SIM_ROOT/S10image/openboot.bin not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/q.bin ]; then
        /bin/rm -f q.bin
        echo "Linking $SIM_ROOT/S10image/q.bin..."
        ln -s  $SIM_ROOT/S10image/q.bin
else
        echo "ERROR: $SIM_ROOT/S10image/q.bin not found!"
        exit
fi

if [ -f $SIM_ROOT/S10image/reset.bin ]; then
        /bin/rm -f reset.bin
        echo "Linking $SIM_ROOT/S10image/reset.bin..."
        ln -s  $SIM_ROOT/S10image/reset.bin
else
        echo "ERROR: $SIM_ROOT/S10image/reset.bin not found!"
        exit
fi

echo "Done setting up symlinks from $SIM_ROOT/S10image."
