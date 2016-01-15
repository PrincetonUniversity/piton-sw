
# User needs to define these new variables

export SIM_ROOT=$HOME/piton-sw/subos

export SUN_STUDIO=/opt/sunstudio/SUNWspro
export LD_LIBRARY_PATH="$SIM_ROOT/sam-t2/devtools/v9/lib:$LD_LIBRARY_PATH"
export PERL5LIB="$SIM_ROOT/sam-t2/devtools/v9/lib/perl5/5.8.8:$SIM_ROOT/sam-t2/devtools/v9/lib/perl5/site_perl/5.8.8"
export PYTHONHOME="$SIM_ROOT/sam-t2/devtools/v9"

# Set path

export PATH=".:/pkg/gnu/bin:/usr/sbin:$SIM_ROOT/bin:/usr/ccs/bin:$PATH"
