#!/bin/bash

[ -z "$NOCLEAR" ] && exec env -i NOCLEAR=1 HOME=$HOME TERM=$TERM PS1="(.venv) $PS1" "$0" "$@"

unset NOCLEAR

PATH=$PWD/.venv/bin
VENV=$PWD/.venv
PS1="\u@\h:\w$ "
export PATH VENV PS1

if [ -r $PWD/.venv/env ]; then
  . $PWD/.venv/env
fi

bash --norc --noprofile
