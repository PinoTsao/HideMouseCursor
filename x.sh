#!/bin/sh
#
# Make linux system based on X to start without mouse cursor(hide cursor)
# Copyright (c) 2016 FUJITSU LIMITED
# Author: Cao jin <caoj.fnst@cn.fujitsu.com>
#
# Extension:
# 1. make X server executive name pattern as input param. TBD. defaul is "Xorg".
# 2. revert operation
# 3. Better way to deal with arguments, TBD
# 4. Better definition of return value, TBD
#
# Limitation:
# 1. Only guarantee it works well under bash. On system whose default shell isn't bash, one should use `sudo bash ./script`
# 2. Xorg version MUST >= 1.7 (released on Oct 2009)
# 3. This script only works with X Windows(Xorg) started, or else it won't work
#
# Usage:
# 1. Hack X to make system start without mouse cursor:
#    `./x.sh`    or    `bash ./x.sh`
# 2. Revert what we hack
#    `./x.sh revert`    or    `bash ./x.sh revert`
#

ROOT_UID=0

R_REVERT_OK=87
R_GOTX=86
R_HACKED_REBOOTED=85
R_HACKED_NREBOOTED=84
R_REVERTED_NREBOOTED=83
CURRENT=
# it means not hacked, also means reverted & rebooted
R_NOTHACKED=82

ps_output=
x_path=
x_dir=
x_bin=
x_pattern="Xorg"
x_suffix=".orig"
x_newbin=
testx=
return_val=

# Run as root
if [ "$UID" -ne "$ROOT_UID" ]
then
    echo "Must be root to run this script."
    exit 88
fi

# Only for developer debug. replace "cat" with ":" when release
_logx () {
cat <<DEBUGX
$1
DEBUGX
}

# 1st step to find X, make sure we have a x process.
TestPS() {
    ps_output=`ps -eo args | grep $x_pattern`

    # ps output test
    testx=`echo "$ps_output" | wc -l`
    if [ $testx -lt 2 ]
    then
        echo "There should be at least 2 lines in output of ps. Bye~"
        exit 88
    else
        _logx "There is 2 or more lines in the output. Ok"
    fi
}

TestCandidateLine() {
    _logx "Testing $x_path ..."

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
            if [[ "$str" =~ "nocursor" ]]
            then
                _logx "find param $str! Gotcha X!"
                return $R_GOTX
            fi
        done
    else
        _logx "$x_bin seems not a conceivable X name. Check next line"
    fi
}

ParseLine() {
    while read line
    do
        _logx "line"
        _logx "$line"

        x_path=`echo $line | cut -f1 -d " "`
        x_dir=`dirname $x_path`
        x_bin=`basename $x_path`
        _logx "Find $x_bin in $x_dir"

        TestCandidateLine
        return_val=$?
        if [ "$return_val" -eq $R_GOTX ]
        then
            _logx "Found X in process list"
            return $R_GOTX
        elif [ "$return_val" -eq $R_REVERTED_NREBOOTED ]
        then
            _logx "Have reverted, please reboot"
            return $R_REVERTED_NREBOOTED
        else
            _logx "keep looking for X"
        fi
    done <<< "$ps_output"

    return 88
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
                _logx "Hacked and rebooted"
                return $R_HACKED_REBOOTED
            fi
        done

        _logx "Reverted but not reboot"
        return $R_REVERTED_NREBOOTED
    else
        for file in `ls`
        do
            if [[ "$file" =~ "$x_suffix" ]] && [[ "$file" =~ "$x_pattern" ]]
            then
                _logx "Hacked but not reboot"
                return $R_HACKED_NREBOOTED
            fi
        done
    fi

    return $R_NOTHACKED
}

RevertX() {
    _logx "Revert X"

    TestPS
    ParseLine
    return_val=$?
    if [ ! "$return_val" -eq 88 ]
    then
        CheckStatus
        return_val=$?
        if [ "$return_val" -eq $R_NOTHACKED ]
        then
            echo "No Hack, no revert. Bye~"
            exit 88
        elif [ "$return_val" -eq $R_REVERTED_NREBOOTED ]
        then
            echo "Already reverted, don't repeat doing it. Bye~"
            exit 88
        elif [ "$return_val" -eq $R_HACKED_REBOOTED ]
        then
            x_newbin=${x_path%$x_suffix}
            _logx "Rebooted. Revert $x_path to $x_newbin"
        elif [ "$return_val" -eq $R_HACKED_NREBOOTED ]
        then
            x_newbin=$x_bin
            x_bin=$x_path$x_suffix
            _logx "Not rebooted. Revert $x_bin to $x_newbin"
        fi
    else
        echo "Didn't find X, Fail to revert. Bye~"
        exit 88
    fi

    cd $x_dir
    _logx "Reverting to: $x_newbin"

    if [ -e $x_newbin ] && [ -x $x_newbin ]
    then
        rm -f $x_newbin
        if [ ! $? ]
        then
            echo "rm $x_newbin fail. Bye~"
            exit 88
        fi

        mv $x_bin $x_newbin
        if [ ! $? ]
        then
            echo "mv $x_bin $x_newbin fail. Bye~"
            exit 88
        fi

        return $R_REVERT_OK
    else
        echo "There is no executable $x_newbin. Failed to revert. Bye~"
        exit 88
    fi
}


# handle argument
if [ "$#" -gt 1 ]
then
    echo "Asage: `basename $0` [revert]"
    echo "give 'revert' param when you want to revert the hacking."
    echo "When this script fails to hack, check absolute path of X via 'ps aux'"
    exit 88
elif [ ! -z "$1" ]
then
    if [[ "$1" =~ "revert" ]]
    then
        RevertX
        if [ "$?" -eq $R_REVERT_OK ]
        then
            echo "Revert success, please reboot the system."
        fi

        # no matter success or not, after revert, exit
        exit
    else
        # should be value assigned to x pattern
        x_pattern="$1"
        _logx "Gog X name pattern: $x_pattern"
    fi
fi

# default to hack X
TestPS
ParseLine
if [ ! "$?" -eq 88 ]
then
    CheckStatus
    return_val=$?
    if [ "$return_val" -eq $R_HACKED_REBOOTED ] || [ "$return_val" -eq $R_HACKED_NREBOOTED ]
    then
        echo "Already hacked X, don't repeat Hack it. Bye~"
        exit 88
    fi
else
    echo "Don't Find X. Bye~"
    exit 88
fi

echo
_logx "Finally, going to hack $x_bin in $x_dir"
echo

cd $x_dir
if [[ $? ]]
then
    _logx $PWD
else
    echo "No dir $x_dir, hacking terminated. Bye~"
    exit 88
fi

# Gnerate script
if [ "$return_val" -eq $R_REVERTED_NREBOOTED ]
then
    x_bin=${x_path%$x_suffix}
    x_newbin=$x_path
    _logx "Reverted not reboot. hack $x_bin to $x_newbin"
else
    x_bin=$x_path
    x_newbin=$x_path$x_suffix
    _logx "Normal hack $x_bin to $x_newbin"
fi

if [ -e $x_newbin ]
then
    echo " $x_newbin already exist! Cannot change filename to it. Bye~"
    exit 88
else
    _logx "Start creating script"
fi

mv $x_bin $x_newbin
if [ ! $? ]
then
    echo "mv fail. Bye~"
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
