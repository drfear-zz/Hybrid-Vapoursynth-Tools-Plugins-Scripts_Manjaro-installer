#!/bin/bash
##############################################################################################################
##############################################################################################################
#
# Install Hybrid + Vapoursynth + all Hybrid tools + Vapoursynth editor/viewer + all Hybrid core scripts
# for Manjaro
#
##############################################################################################################
##############################################################################################################

# Usage: See README.md !!!


##############################################################################################################
# Source the header file
##############################################################################################################

# This will: reject root, setup environment variables (paths), prepare a date to use as a file suffix to
# make them unique, define setoptions() used to process options

. ./hf_header.sh

# Go process the arguments , if any, to this script call instance
setoptions "$@"


##############################################################################################################
# Install as much as possible from Manjaro/AUR using pamac
##############################################################################################################

# this part of the process reads the package list in hf_pamac_list.txt and passes that to pamac install
# It is possible (likely?) that at some point in this long list of AUR installs, pamac will fail.  You can then
# work on fixing the cause of the error, and then pick up again after commenting out everything that is
# already successfully installed. I did not build in changing the name of hf_pamac_list.txt, but you can
# change its contents.

# before doing anything else at all, ensure AUR is enabled
if [[ "$(grep -E '^EnableAUR$' /etc/pamac.conf)" != "EnableAUR" ]]
then
  echo "You do not have AUR enabled in pamac.  There is no point continuing"
  exit 1
fi

if {  # start a subshell to capture screen output in transcript (saves having to look in both pamac.log and pacman.log)
      # and also to test if it runs error-free

# echo some potentially useful info
siread=$(grep -E '^SimpleInstall$' /etc/pamac.conf)
echo "FYI, your /etc/pamac.conf SimpleInstall setting = ${siread:-(not set)}"
echo "FYI, your /etc/pacman.conf ignore package/group settings are (blank = none)"
grep -E '^(IgnorePkg|IgnoreGroup)' /etc/pacman.conf
echo ""

# read in the package list, ignoring comment lines
pkg_list="$(while read -r pkg
do
  [[ "${pkg:0:1}" != '#' ]] && echo -n "$pkg "
done < hf_pamac_list.txt)"

# Now do the packages install in one massive transaction. Minimal root authentification! (But at the cost
# that one error stops the whole process without attempting the rest of the install.)

if ! pamac install $pamac_install_options $pkg_list
then
  exit 1                      # this exits the screen capture subshell, not the whole script
fi

echo -e "\n###############################################################################################
A transcript of the output from pamac has been written to file ./transcript_hf_pamac_$unique_date
###############################################################################################\n"

# end the transcript file process and write it out
} |& tee ./transcript_hf_pamac_$unique_date
# continue from the if {} enclosing the pamac and transcript process; testing the exit code
then
  echo '

No pamac errors reported!

'
else
  echo -n'

pamac install was stopped either because of an error encountered or because you responded N to decline
the transaction. A script cannot distinguish which of these occurred so please clarify:

y) pamac cancel was deliberate, answered N to an install prompt, but continue now to install the git packages

N) fatal error encountered during pamac installation of a package.  Installation is therefore incomplete and you
will need to fix what broke (see the above output or the transcript file), or perhaps accept omission of the
problem package.  Then comment out (or simply delete) packages that have already been successfully installed (i.e.
those installed before the pamac error) in hf_pamac_list.txt, then rerun this script.

Proceed to installation of the non-pamac packages?  [y|N] '

  read
  if [[ "$REPLY" != "y" ]]
  then
    echo '

***** Hybrid installation cancelled

'
    exit
  fi
fi

##############################################################################################################
# a couple of tweaks:
##############################################################################################################

# Hybrid by default looks for binary called "tsMuxeR" whereas the Manjaro installed binary is called "tsmuxer"
# I prefer to leave the Hybrid default and create a link (the alternative would be to manually set the path to
# "tsmuxer" in Config->Tools tool tsMuxeR in Hybrid GUI)
echo '
Tweaking, if needed, the names of tsMuxeR and bdsup2sub++ (you will need to provide sudo password, if requested)

'
if [[ -f /usr/bin/tsmuxer && ! -f /usr/bin/tsMuxeR ]]
then
  sudo ln  /usr/bin/tsmuxer /usr/bin/tsMuxeR
fi
# likewise Hybrid looks for an executable called bdsup2sub++ rather than b2sup2subpp
if [[ -f /usr/bin/bdsup2subpp && ! -f /usr/bin/bdsup2sub++ ]]
then
  sudo ln  /usr/bin/bdsup2subpp /usr/bin/bdsup2sub++
fi


##############################################################################################################
# If there were no pamac errors, continue by installing everything outstanding by building from source
##############################################################################################################

. ./hf_git.sh child


##############################################################################################################
# Just one thing left - create config scripts. Neither Hybrid nor Vapoursynth will work without them.
##############################################################################################################

# Hybrid reads and saves settings to directory $HOME/.hybrid. Using this precise location is NOT user configurable.
# I separately create $HOME/.config/hybrid, where I would normally look, as a link to $HOME/.hybrid.
# (That is not done in this script.)

# In this script we make backups of pre-existing folder and files, and create fresh ones.

echo -e "\n____________________________ Creating config scripts __________________________\n"

cd
if [[ -d ".hybrid" ]]
then
  mv ".hybrid" ".hybrid_backup_$unique_date"
fi
mkdir ".hybrid"
# the hybrid/misc.ini folder names need to be quoted
echo "vsScriptPath=\"$VS_CORE_SCRIPTS\"
vsPluginsPath=\"$VS_CORE_PLUGINS\"" > ".hybrid/misc.ini"

vsdir=".config/vapoursynth"
mkdir -p $vsdir
vsconf="$vsdir/vapoursynth.conf"
if [[ -f "$vsconf" ]]
then
  mv "$vsconf" "${vsconf}_backup_$unique_date"
fi
# but NB !! the VS.conf plugin folder names MUST **NOT** be quoted (if they are, no plugins are found)
echo "SystemPluginDir=$VS_CORE_PLUGINS" > "$vsconf"

echo "Config scripts $HOME/.hybrid/misc.ini and $HOME/$vsconf have been created"
echo "  (with any pre-existing versions saved as dated copies)"
echo -e "\n\nThat's all folks!\n\nEnjoy Hybrid!\n\n"

##############################################################################################################


