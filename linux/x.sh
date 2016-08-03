#!/bin/sh
#
# Make linux system based on X to start without mouse cursor(hide cursor).
#
# When user using vnc connecting to virtual machine, there will be two mouse
# cursors overlap together, and you will see "cursor drifting" when move your
# mouse in heavy network latency. This scipt is aim to improve user experience
# under this circumstances
#
# Copyright (c) 2016 FUJITSU LIMITED
# Author: Cao jin <caoj.fnst@cn.fujitsu.com>
#
# TBD:
# 1. make X server executive name pattern as input param. This feature could be
#    add according to the requirement.
#
# Limitation:
# 1. This script is developed & tested under bash 4.3, not sure it will works
#    well on toooold version of bash, or other shells. So it is recommended to
#    run this script via `sudo bash ./script` on system whose default shell
#    isn't bash.
# 2. Xorg version MUST be >= 1.7 (released on Oct 2009).
# 3. This script only works with X Windows(Xorg) started, or else it won't work
#
# Usage:
#
# We now just support the basic two functionality, hack X to hide mouse cursor,
# and revert the hacking. So the usage is very simple as following:
#
# 1. Hack X to make system start without mouse cursor:
#    `./x.sh`    or    `bash ./x.sh`
# 2. Revert what we hack
#    `./x.sh -r`    or    `bash ./x.sh -r`
#

ROOT_UID=0

R_GENERAL_FAIL=89
R_GENERAL_OK=90

R_REVERT_OK=87
R_GOTX=86
R_HACKED_REBOOTED=85
R_HACKED_NREBOOTED=84
R_REVERTED_NREBOOTED=83

# it means not hacked, also means reverted & rebooted
R_NOTHACKED=82

X_OP_HACK=0
X_OP_REVERT=1

ps_output=
x_op=
x_path=
x_dir=
x_bin=
x_suffix=".orig"
x_newbin=
#testx=
#return_val=

X_patterns=("Xorg" "X")
x_pattern=

# Run as root
if [ "$UID" -ne "$ROOT_UID" ]
then
    echo "Must be root to run this script."
    exit 88
fi

show_help () {
    if [[ -n $1 ]]
    then
        echo -e "Unknown parameter: $1\n"
    fi

    echo "Usage:"
    echo -e "  script [option]  # no option means default to hack X\n"
    echo "Options:"
    echo "-r        Revert the hacking after hacked X"
}

# Only for developer debug. replace "cat" with ":" when release
_logx () {
cat <<DEBUGX
$1
DEBUGX
}

# 1st step of finding X, make sure we have a X process.
TestPS() {
    _logx "Finding pattern $1"
    ps_output=`ps -eo args | grep "$1"`

    # ps output test
    local lines=`echo "$ps_output" | wc -l`
    if [ $lines -lt 2 ]
    then
        echo "There should be at least 2 lines in output of ps. Bye~"
        return $R_GENERAL_FAIL
        #exit 88
    else
        _logx "There is 2 or more lines in the output. Ok"
        return $R_GENERAL_OK
    fi
}

# R_GENERAL_FAIL means x_bin don't looks like X server; or it looks like,
# but actually not. Should never happen
TestCandidate() {
    _logx "Testing $x_path"
    local testx

    if [[ "$x_bin" =~ "$x_pattern" ]]
    then
        # dir & binary test
        if [[ -e $x_path ]] && [[ -x $x_path ]]
        then
            _logx "$x_path is effective"
        else
            if [[ "$x_bin" =~ "$x_suffix" ]]
            then
                echo "$x_path file doesn't exit, meaning reverted but not reboot"
                return $R_REVERTED_NREBOOTED
            fi
        fi

        # X server command output test
        testx=`$x_path -help 2>&1`
        for str in $testx
        do
            if [[ "$str" == "-nocursor" ]]
            then
                _logx "find param $str! Gotcha X!"
                return $R_GOTX
            fi
        done
    else
        _logx "$x_bin seems not a conceivable X name. Check next line"
    fi

    return $R_GENERAL_FAIL
}

# 3 return value: R_GOTX, R_REVERTED_NREBOOTED, R_GENERAL_FAIL
# R_GENERAL_FAIL means all lines of ps_output have nothing to do with X server,
ParseLine() {
    while read line
    do
        local ret

        _logx "line"
        _logx "$line"

        x_path=`echo $line | cut -f1 -d " "`
        x_dir=`dirname $x_path`
        x_bin=`basename $x_path`
        _logx "Find $x_bin in $x_dir"

        TestCandidate
        ret=$?
        if [ "$ret" -eq $R_GOTX ]
        then
            _logx "Found X in process list & directory"
            return $ret
        elif [ "$ret" -eq $R_REVERTED_NREBOOTED ]
        then
            # _logx "Have reverted, please reboot"
            return $ret
        else
            _logx "keep looking for X"
        fi
    done <<< "$ps_output"

    return $R_GENERAL_FAIL
}


CheckStatus() {
    cd $x_dir
    if [ $? ]
    then
        _logx "Enter $x_dir to check current status"
    else
        echo "No dir $x_dir? Bye~"
        exit 88
    fi

    if [[ "$x_bin" =~ "$x_suffix" ]] && [[ $x_bin =~ "$x_pattern" ]]
    then
        for file in `ls`
        do
            if [[ "$file" =~ "$x_suffix" ]] && [[ "$file" =~ "$x_pattern" ]]
            then
                return $R_HACKED_REBOOTED
            fi
        done

        return $R_REVERTED_NREBOOTED
    else
        for file in `ls`
        do
            if [[ "$file" =~ "$x_suffix" ]] && [[ "$file" =~ "$x_pattern" ]]
            then
                #_logx "Hacked BUT NOT reboot"
                return $R_HACKED_NREBOOTED
            fi
        done
    fi

    return $R_NOTHACKED
}


# find the current X process in system, and confirm the dir of X server.
# So we can check current status later.
FindX() {
    local ret

    for pattern in `echo ${X_patterns[@]:0}`
    do
        x_pattern=$pattern
        TestPS $pattern
        if [ $? == $R_GENERAL_OK ]
        then
            ParseLine
            ret=$?
            if [ "$ret" -ne $R_GENERAL_FAIL ]
            then
                return $ret
            else
                echo "Should never happen"
            fi
        else
            _logx "Try another pattern to find X"
        fi
    done

    return $R_GENERAL_FAIL
}


RevertX() {
    local ret
    _logx "Revert X"

    FindX
    ret=$?
    if [ "$ret" -ne $R_GENERAL_FAIL ]
    then
        CheckStatus
        ret=$?
        if [ "$ret" -eq $R_NOTHACKED ]
        then
            echo "No Hack, no revert. Bye~"
            exit
        elif [ "$ret" -eq $R_REVERTED_NREBOOTED ]
        then
            echo "Already reverted BUT NOT reboot, don't repeat doing it. Bye~"
            exit
        elif [ "$ret" -eq $R_HACKED_REBOOTED ]
        then
            x_newbin=${x_path%$x_suffix}
            _logx "Hacked & Rebooted. Revert $x_path to $x_newbin"
        elif [ "$ret" -eq $R_HACKED_NREBOOTED ]
        then
            x_newbin=$x_bin
            x_bin=$x_path$x_suffix
            _logx "Hacked BUT NOT rebooted. Revert $x_bin to $x_newbin"
        fi
    else
        echo "Didn't find X, Fail to revert. Bye~"
        exit
    fi

    cd $x_dir
    _logx "Now reverting to: $x_newbin"

    if [ -e $x_newbin ] && [ -x $x_newbin ]
    then
        rm -f $x_newbin
        if [ ! $? ]
        then
            echo "rm $x_newbin fail. Bye~"
            exit
        fi

        mv $x_bin $x_newbin
        if [ ! $? ]
        then
            echo "mv $x_bin $x_newbin fail. Bye~"
            exit
        fi

        echo "Reverting is success, please reboot"
        return $R_REVERT_OK
    else
        echo "There is no executable $x_newbin. Failed to revert. Bye~"
        exit
    fi
}


HackX() {
    local ret

    FindX
    if [ "$?" -ne $R_GENERAL_FAIL ]
    then
        CheckStatus
        ret=$?
        if [ "$ret" -eq $R_HACKED_REBOOTED ] || [ "$ret" -eq $R_HACKED_NREBOOTED ]
        then
            echo "Already hacked X, don't repeat Hack it. Bye~"
            exit
        fi
    else
        echo "Don't Find X. Bye~"
        exit
    fi

    echo
    _logx "Finally, going to hack $x_bin in $x_dir"
    echo

    cd $x_dir
    if [[ $? ]]
    then
        _logx "Entered $PWD"
    else
        echo "No dir $x_dir, hacking terminated. Bye~"
        exit
    fi

    # Gnerate script
    if [ "$ret" -eq $R_REVERTED_NREBOOTED ]
    then
        x_bin=${x_path%$x_suffix}
        x_newbin=$x_path
        _logx "Reverted but not reboot. hack $x_bin to $x_newbin"
    else
        x_bin=$x_path
        x_newbin=$x_path$x_suffix
        _logx "The default normal hack $x_bin to $x_newbin"
    fi

    if [ -e $x_newbin ]
    then
        echo " $x_newbin already exist! Cannot change filename to it. Bye~"
        exit
    else
        _logx "Start creating script"
    fi

    mv $x_bin $x_newbin
    if [ ! $? ]
    then
        echo "mv fail. Bye~"
        exit
    fi

    touch $x_bin

    cat > $x_bin <<SPT
#!/bin/sh

exec $x_newbin -nocursor "\$@"
SPT

    if [ -f "$x_bin" ]
    then
        chmod 755 $x_bin
    fi

    echo "Hacking done, please reboot the system."
}


# handle option & arguement
while getopts ":r" optname
do
    case "$optname" in
        r ) x_op=$X_OP_REVERT
            _logx "Going to revert"

            # no matter success or not, after revert, exit
            #exit
            ;;
        * ) echo -e "Unimplemented option chosen: $OPTARG\n"
            show_help
            exit
            ;;
    esac
done

shift $(($OPTIND - 1))
if [[ $OPTIND == 1 && -z "$1" ]]
then
    _logx "No options specified, default to hack"
    x_op=$X_OP_HACK
elif [ -n "$1" ]
then
    # Currently, never go into this path. It can be usefull
    # when we want user specify a X pattern.
    show_help $1
fi


if [ $x_op -eq $X_OP_HACK ]
then
    # default to hack X
    HackX
elif [ $x_op -eq $X_OP_REVERT ]
then
    # Revert
    RevertX
else
    echo "Impossible to be here!"
fi

