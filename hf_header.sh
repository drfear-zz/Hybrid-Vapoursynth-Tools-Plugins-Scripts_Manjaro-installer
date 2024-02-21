##############################################################################################################
#
# Hybrid_full_install - header program.
# Source (not execute) this header as a part of every script run.
# -- check caller is not root
# -- setup key installation "environment" variables
# -- define setoptions(), used to setup pamac and git option strings from any --options supplied to scripts
#
##############################################################################################################

# failsafe check user is user, and not root
# NB in particular pamac must never be called by root.  It will run, but with bizarre results

if [[ $(id -u) -eq 0 ]]
then
  echo -e "\nhf_*.sh install scripts must NOT be run as sudo. All operations cancelled.\n"
  exit 1
fi

#
# environment variables
#

# change this next, if you like, to suit your own preference, but in keeping with the philosophy that
# Hybrid will be system-installed, use a location in system folders, not in your own $HOME.
export VS_CORE_SCRIPTS="/usr/share/hybrid/VapoursynthScriptsInHybrid"

# don't change this one (because Manjaro installs of plugins will always place them in /usr/lib/vapoursynth):
export VS_CORE_PLUGINS="/usr/lib/vapoursynth"

# certain other locations, eg installation of programs into /usr/bin, are hard coded
# (or used without option by pamac) and not configurable

#
# the date and time down to microseconds used to provide a unique filename (same time for the whole run)
#
unique_date="$(date +%Y-%m-%dT%H_%M_%S.%3N)"


#
# define function setoptions()
#

# initialize
pamac_install_options=''
git_force_all=false
git_kill=true
dry_run=false
git_confirm=true
git_install=true
git_nodate_ok=false
git_shortlist=false
declare -A shortlist=()

setoptions () {
  for opt in "$@"
  do
    if $git_shortlist
    then
      shortlist[$opt]=1       # for later checking; if shortlist[pkg-name] is not 1, then it's not in the list
    else
      case $opt in
        --git-dry-run)
            dry_run=true;;
        --git-no-confirm)
            git_confirm=false;;
        --git-no-install)
            git_install=false;;
        --git-force-all)
            git_force_all=true;;
        --git-retain-source)
            git_kill=false;;
        --git-nodate-ok)
            git_nodate_ok=true;;
        --git-only)
            git_shortlist=true;;
        --ignore|--overwrite|--download-only|-w|--dry-run|--as-deps|--as-explicit|--upgrade|--no-upgrade|--no-confirm)
            pamac_install_options="$pamac_install_options $opt";;
        -d)
            pamac_install_options="$pamac_install_options --dry-run";;
        *)
            echo -e "\nUnrecognized argument '$opt' - script cancelled\n\n"
            exit;;
      esac
    fi
  done
}

