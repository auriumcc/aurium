#!/bin/bash

gdb="$(dirname "$0")/gdb" # For using a gdb build such as the cathook one (The one included)
libname="libgamemodeauto.so.0" # Pretend to be gamemode, change this to another lib that may be in /maps (if already using real gamemode, I'd suggest using libMangoHud.so)
csgo_pid=$(pidof csgo_linux64)

# Set to true to compile with clang. (if changing to true, make sure to delete the build directory from gcc)
export USE_CLANG="false"

if [[ $EUID -eq 0 ]]; then
    echo "You cannot run this as root." 
    exit 1
fi

rm -rf /tmp/dumps
mkdir -p --mode=000 /tmp/dumps

function unload {
    echo "Unloading..."
    echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
    if grep -q "$libname" "/proc/$csgo_pid/maps"; then
        $gdb -n -q -batch -ex "attach $csgo_pid" \
            -ex "set \$dlopen = (void*(*)(char*, int)) dlopen" \
            -ex "set \$dlclose = (int(*)(void*)) dlclose" \
            -ex "set \$library = \$dlopen(\"/usr/lib/$libname\", 6)" \
            -ex "call \$dlclose(\$library)" \
            -ex "call \$dlclose(\$library)" \
            -ex "detach" \
            -ex "quit"
    fi
    echo "Unloaded!"
}

function load {
    echo "Loading..."
    echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope > /dev/null
    sudo cp build/libaurium.so /usr/lib/$libname
    gdbOut=$(
      $gdb -n -q -batch \
      -ex "set auto-load safe-path /usr/lib/" \
      -ex "attach $csgo_pid" \
      -ex "set \$dlopen = (void*(*)(char*, int)) dlopen" \
      -ex "call \$dlopen(\"/usr/lib/$libname\", 1)" \
      -ex "detach" \
      -ex "quit" 2> /dev/null
    )
    lastLine="${gdbOut##*$'\n'}"
    if [[ "$lastLine" != "\$1 = (void *) 0x0" ]]; then
      echo "Successfully loaded!"
    else
      echo "Loading failed, make sure you have compiled."
    fi
}

function load_debug {
    echo "Loading..."
    echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
    sudo cp build/libaurium.so /usr/lib/$libname
    $gdb -n -q -batch \
        -ex "set auto-load safe-path /usr/lib:/usr/lib/" \
        -ex "attach $csgo_pid" \
        -ex "set \$dlopen = (void*(*)(char*, int)) dlopen" \
        -ex "call \$dlopen(\"/usr/lib/$libname\", 1)" \
        -ex "detach" \
        -ex "quit"
    $gdb -p "$csgo_pid"
    echo "Successfully loaded!"
}

function build {
    echo "Building..."
    mkdir -p build
    cd build
    cmake -D CMAKE_BUILD_TYPE=Release ..
    make -j $(nproc --all)
    cd ..
}

function build_debug {
    echo "Building..."
    mkdir -p build
    cd build
    cmake -D CMAKE_BUILD_TYPE=Debug ..
    make -j $(nproc --all)
    cd ..
}

function pull {
    git pull
}

while [[ $# -gt 0 ]]
do
keys="$1"
case $keys in
    -u|--unload)
        unload
        shift
        ;;
    -l|--load)
        load
        shift
        ;;
    -ld|--load_debug)
        load_debug
        shift
        ;;
    -b|--build)
        build
        shift
        ;;
    -bd|--build_debug)
        build_debug
        shift
        ;;
    -p|--pull)
        pull
        shift
        ;;
    -h|--help)
        echo "
 help
Toolbox script for aurium
=======================================================================
| Argument             | Description                                  |
| -------------------- | -------------------------------------------- |
| -u (--unload)        | Unload.                                      |
| -l (--load)          | Load via gdb.                                |
| -ld (--load_debug)   | Load and debug via gdb.                      |
| -b (--build)         | Build to the build/ dir.                     |
| -bd (--build_debug)  | Build to the build/ dir as debug.            |
| -p (--pull)          | Update.                                      |
| -h (--help)          | Show help.                                   |
=======================================================================

All args are executed in the order they are written in, for
example, \"-p -u -b -l\" would update, then unload, then build it, and
then load it back.
"
        exit
        ;;
    *)
        echo "Unknown arg $1, use -h for help"
        exit
        ;;
esac
done
