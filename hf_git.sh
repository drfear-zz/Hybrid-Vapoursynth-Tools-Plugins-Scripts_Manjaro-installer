##############################################################################################################
#
# hf_git.sh - the github source installs and pseudo package manager
#
# Everything needed by Hybrid+Vapoursynth which is not in the Manjaro/AUR repos.
#
# When executed directly, this script sources hf_header.sh, which has to be in the same folder.
#
##############################################################################################################


# ascertain by reading arg 1 if we are running this standalone or whether it is called from hybrid_full_install
# (if from full, option variables are already set)
if [[ "$1" != "child" ]]
then
  # pull in the header file
  . ./hf_header.sh
  # and setup git install options from any args supplied
  setoptions "$@"
fi

#
# define util functions used only in this module
#

# this first one is blatantly stolen and then adapted from https://github.com/Selur/hybrid-vapoursynth-addon
retry_git_clone() {

  local repo_url="$1"
  local target_dir="$2"
  local max_attempts="${3:-3}"
  local attempts=0

  while true; do

    if [ "$attempts" -ge "$max_attempts" ]; then
      echo "Maximum number of clone attempts reached. Giving up."
      return 1
    fi
    if git clone --depth 1 --recursive "https://github.com/$repo_url.git" $target_dir; then
      return 0
    else
      attempts=$((attempts +1))
      echo "clone attempt $attempts with URL $repo_url failed"
      sleep 5
    fi
  done
}

# echo (to stdout) ISO format datetime (it is always in Zulu) of the latest git page commit
# will echo empty string if there's any error such as page not found etc etc
get_git_timestamp () {
  local whopage="$1"
  local branch="${2:-master}"
  curl "https://api.github.com/repos/$whopage/commits/$branch" 2> /dev/null | \
  grep -o -P '(?<=date": ")[0-9T:-]+' | tail -1
}

# echo a file timestamp in ISO format ensuring it is shifted from local system time to UTC
# nb we already tested that the file, provided as arg 1, exists
get_file_timestamp () {
  date --date="@$(stat -c "%Y" "$1")" -u +%Y-%m-%dT%H:%M:%S
}

# we store up the actual system file installs until the end, when we can do them all with one root password ask
# array chicken is where the eggs in the basket came from (on call) and where they are now (on exit)
# so eventual install is just mv -T $chicken[$egg]/$egg $basket[$egg]
declare -A basket=() chicken=()
basket_dir="$(pwd)/tmp_install_cache_$unique_date"
mkdir -p $basket_dir

add_to_basket () {
  local egg="$1" destination="$2" origin="$3"
  if $git_kill
  then
    cp -r "$egg" $basket_dir
    origin="$basket_dir"
  fi
  basket[$egg]="$destination"
  chicken[$egg]="$origin"
}


# DIY_check_install - args as named, any further args would be passed as args to the named builder function.
# (But currently no build routines require any arguments, this is a future-proofing measure.)
# for wget, or if there is no named target for git clone, specify arg 5 as "", don't just omit it
# also nb, target - arg 5 - is not allowed to contain spaces (anyway it would be crazy to want them)
# Arg 7 was added as a patch for a couple of packages for which I spotted only last-minute that the master
# source branch is called main instead of being called master (this matters for picking up latest commit date)

DIY_check_install () {
  local thing="$1"
  local prog_or_plugin="$2"
  local git_or_wget="$3"
  local URL="$4"
  local git_target="$5"
  local builder="$6"
  local git_branch="$7"     # omitting this arg sets the main source branch name to "master"

  local no_install=false installed=false time_comparable=false
  local existing_pathfilename existing_timestamp

  # take a very quick exit if the package is not in the shortlist (if there is a shortlist)
  if $git_shortlist && [[ "${shortlist[$thing]}" != "1" ]]
  then
    return 0
  fi

  echo -e "\n____________________________ Processing $thing __________________________\n"

  # first check if thing already installed (in *system* location - we do not care about local or other copies)
  # we need this info for logging even for --git-update-all
  if [[ "$prog_or_plugin" == "prog" && -f /usr/bin/$thing ]]
  then
    installed=true
    existing_pathfilename="/usr/bin/$thing"
  elif [[ "$prog_or_plugin" == plugin && -e "$VS_CORE_PLUGINS/$thing" ]]
  then
    installed=true
    existing_pathfilename="$VS_CORE_PLUGINS/$thing"
  elif [[ "$prog_or_plugin" == scripts && -d "$VS_CORE_SCRIPTS" ]]
  then
    installed=true
    existing_pathfilename="$VS_CORE_SCRIPTS"
  fi

  if [[ -n "$existing_pathfilename" ]]
  then
    existing_timestamp="$(get_file_timestamp "$existing_pathfilename")"
  fi

  if ! $git_force_all
  then
    # if installed, check the timestamps
    if $installed
    then
      if [[ "$git_or_wget" == "git" ]]
      then
        git_date="$(get_git_timestamp $URL $git_branch)"
        if [[ ! "$git_date" =~ ^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}T?[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}$ ]]
        then
          echo "Failed to get valid commit/publish date for URL $URL. The value read was:"
          echo "'$git_date'"
        else
          time_comparable=true
        fi
      else
        echo -e "\nNo method available to obtain timestamp for $thing from $URL"
      fi
      if $time_comparable
      then
        if [[ $existing_timestamp > "$git_date" ]]
        then
          no_install=true
        fi
      elif $git_nodate_ok
      then
        no_install=true
      else
        echo "--> Install will overwrite existing"
      fi
    fi
  fi
  echo -e "\nCall to install: $thing"
  if $time_comparable
  then
    echo "github source date: $git_date"
  fi
  if $installed
  then
    echo "current installed file date: $existing_timestamp"
  else
    echo "not currently installed"
  fi
  if $no_install
  then
    echo -e "Current version of $thing is identified as up to date - no re-install performed\n"
    return
  fi
  echo ""
  if $git_confirm
  then
    echo -n "Proceed with installation?  [y|N]"
    read
    if [[ "$REPLY" != "y" ]]
    then
      echo -e "\n***** Installation of $thing cancelled\n"
      return 1
    fi
    echo ""
  fi
  #
  # the actual build/install to tmp starts here, if we reach it
  #
  if $dry_run
  then
    echo -e "---> would download, build and install here if not --git-dry-run\n"
  else
    startdir="$(pwd)"
    tmpdir="vs-$thing-$unique_date"
    mkdir $tmpdir
    cd $tmpdir
    if ( [[ "$git_or_wget" == "git" ]] && retry_git_clone "$URL" $git_target ) || \
      ( [[ "$git_or_wget" == "wget" ]] && wget "$URL" )
    then
      shift 7
      $builder "$@"
      if [[ "$prog_or_plugin" == "plugin" ]]
      then
        chmod a-x $thing
        strip $thing
        add_to_basket $thing "$VS_CORE_PLUGINS" "$(pwd)"
      fi
    else
      echo "***************** $thing: source code download failed, maybe try again later  **********************"
    fi
    cd "$startdir"
    if $git_kill
    then
      rm -rf $tmpdir
    fi
  fi
}


##############################################################################################################
# here we go with the installs of the outstanding Hybrid tools
##############################################################################################################

{  # start a subshell to capture screen output in transcript

#
# installing xvid_encraw
#

builder() {
  tar -xjf xvidcore-1.3.7.tar.bz2
  # make the xvidcore libraries, locally, because this make is needed for the programs' make, but
  # do not install the libraries (because you already have them, because you already have ffmpeg)
  cd xvidcore/build/generic/
  ./configure
  make
  # now make the executables
  cd ../../examples
  make
  for exe in xvid_bench xvid_decraw xvid_encraw
  do
    add_to_basket $exe "/usr/bin" "$(pwd)"
  done
}

DIY_check_install xvid_encraw prog wget https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.bz2 "" builder


#
# telxcc - Hybrid warns it might not work without this, although AFAIK it is only needed for manipulating
# old teletext text
#

builder() {
  cd telxcc
  make
  add_to_basket telxcc "/usr/bin" "$(pwd)"
}

DIY_check_install telxcc prog git debackerl/telxcc "" builder


########################################
# install vsViewer/vsedit
########################################

# Although not listed as a critical tool, and with no messaging if it is missing (except VS previews just don't work),
# your Hybrid/VS experience would be miserable without preview videos and a script editor.

# FYI The AUR package "vapoursynth-editor" installs the very latest YomikoR mod VapourSynth Editor r19-mod-6.3
# providing executable /usr/bin/vsedit (also providing a standalone QT6 desktop app in the whisker menu)
# BUT the Selur version of r19-mod-3 (https://github.com/Selur/vsViewer) is tailored to Hybrid and is preferred on those
# grounds, despite there is no AUR package for it. This provides an executable named vsViewer rather than vsedit.

builder () {
  cd vsViewer
  qmake
  # there must be a less cludgy way to get the include path right for Manjaro, but this works
  sed -i Makefile -e 's|-I/usr/local/include/vapoursynth|-I/usr/include/vapoursynth|'
  make
  cd build/release-64bit-gcc
  add_to_basket vsViewer "/usr/bin" "$(pwd)"
}

DIY_check_install vsViewer prog git Selur/vsViewer "" builder


##############################################################################################################
# and the outstanding plugins
##############################################################################################################

# for scenechange, the AUR package links to source in https://sl1pkn07.wtf/scenechange/scenechange-0.2.0-2.7z;
# this is currently broken (and has been for a little while - error code 522 - may or may not be down permanently).
# So for now at least let's DIY using Selur's link to alternative source

builder () {
  cd build
  export CFLAGS="-pipe -O3 -Wno-attributes -fPIC -fvisibility=hidden -fno-strict-aliasing \
                  $(pkg-config --cflags vapoursynth) -I/usr/include/compute"
  export CXXFLAGS="$CFLAGS -Wno-reorder"
  export LDFLAGS="-L$VSPREFIX/lib"
  gcc $CFLAGS $LDFLAGS -shared src/scenechange.c -o libscenechange.so -lm
}

DIY_check_install libscenechange.so plugin git darealshinji/scenechange build builder


# for frfun7 there is an avisynth, but no vapoursynth package on Manjaro/AUR, so build from scratch

builder () {
  cd vapoursynth-frfun7
  meson build
  ninja -C build
  cd build      # so we will end up in the right place for library copy call
}

DIY_check_install libfrfun7.so plugin git dubhater/vapoursynth-frfun7 "" builder main


# for grayworld I cannot find anything on Manjaro/AUR

builder() {
  cd AviSynthPlus-grayworld
  mkdir build
  cd build
  CXXFLAGS=-isystem\ /usr/include/vapoursynth cmake .. -DBUILD_VS_LIB=ON -DBUILD_AVS_LIB=OFF
  make -j$(nproc)
  mv libgrayworld*.so libgrayworld.so
}

DIY_check_install libgrayworld.so plugin git Asd-g/AviSynthPlus-grayworld "" builder main


# for libneo-fft3d - pamac has libfft3dfilter.so from vapoursynth-plugin-fft3dfilter-git,
# but does not have neo-fft3d

builder() {
  cd neo_FFT3D
  cmake .
  make
  cd ../Release_*
}

DIY_check_install libneo-fft3d.so plugin git HomeOfAviSynthPlusEvolution/neo_FFT3D "" builder


# vsimagereader from source (there is a bit more to this one, cos it also builds in local libjpeg-turbo; you
# actually already by this stage have libjpegturbo system-installed (by qt5-base, by hybrid-encoder, in the unlikely
# event you did not already have it)), but I think what is used below requires a particular version static

builder () {
  cd build
  if retry_git_clone libjpeg-turbo/libjpeg-turbo build
  then
    cd build
    mkdir build
    cd build
    cmake .. -DCMAKE_C_FLAGS="$CFLAGS" -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_TURBOJPEG=ON -DWITH_JAVA=OFF
    make -j$(nproc)
    # then build imagereader itself
    cd ../../src
    rm -f VapourSynth.h   # which means you will use installed /usr/include/vapoursynth/VapourSynth.h instead
    cat >> config.mak << EOF
    CC      = gcc
    LD      = gcc
    STRIP   = strip
    LIBNAME = libvsimagereader.so
    CFLAGS  = $CFLAGS -I../build -I../build/build -I/usr/include/vapoursynth
    LDFLAGS = -shared -Wl,-soname,\$(LIBNAME) $LDFLAGS
    LIBS    = ../build/build/libjpeg.a ../build/build/libturbojpeg.a -lpng
EOF
    make -j$(nproc)
  else
    echo " ***************** libjpeg-turbo for plugin libvsimagereader install failed git clone, try again later  **********************"
  fi
}

DIY_check_install libvsimagereader.so plugin git chikuzen/vsimagereader build builder


# for vsrawsource there is an AUR package but within that the link to source code is currently broken ... so DIY:

builder() {
  cd build
  ./configure --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS" || cat config.log
  make -j$(nproc) X86=1
}

DIY_check_install libvsrawsource.so plugin git chikuzen/vsrawsource build builder


##############################################################################################################
# plugins needed to drive certain filters that are not included in the Selur core package
##############################################################################################################

# required for DeBand -> vsPlacebo (nb but it still will not work unless you have NVIDIA+Vulkan)
# For vapoursynth-plugin-placebo-git the AUR package will not install because it wants to rebuild
# /usr/lib/libplacebo.so (via dependency on libplacebo-git) but that can't be done because libplacebo is a
# dependency of ffmpeg among many other things

builder() {
  cd vs-placebo
  # libp2p folder is not populated in the placebo git clone, it is a linked lib that still needs to be fetched
  git clone https://github.com/sekrit-twc/libp2p.git
  meson build
  ninja -C build
  cd build
}

DIY_check_install libvs_placebo.so plugin git Lypheo/vs-placebo "" builder

#
# required for Artifacts -> DeScratch

builder() {
  cd descratch
  export CFLAGS=" -fPIC $(pkg-config --cflags vapoursynth) $(pkg-config --cflags avisynth)"
  gcc $CFLAGS -shared src/descratch.cpp -o libdescratch.so -lm
}

DIY_check_install libdescratch.so plugin git vapoursynth/descratch "" builder

#
# required for DeNoise -> ChromaNR (nb this plugin also has a cuda version - here I do the non-cuda)

builder() {
  cd vapoursynth-chromanr
  zig build -Doptimize=ReleaseFast
  cd zig-out/lib/
}

DIY_check_install libchromanr.so plugin git dnjulek/vapoursynth-chromanr "" builder main



###############################################################################################
#
# install the Hybrid-VS master scripts
#
###############################################################################################

# I cannot find any Manjaro/AUR package that loads these scripts, despite that basically Hybrid
# cannot work at all without them.
# Update: since I wrote that, I found vapoursynth-plugin-hybrid-pack-git. This package is very oddly
# named, given it contains scripts, and no plugins at all. And, it renames the libraries with _h,
# so it won't link as needed for hybrid (although it would work with VS alone); and it does not mention
# or use misc.ini.  So I am quietly ignoring it.

builder() {
  add_to_basket VapoursynthScriptsInHybrid "$(dirname $VS_CORE_SCRIPTS)" "$(pwd)"
}

DIY_check_install VapoursynthScriptsInHybrid scripts git Selur/VapoursynthScriptsInHybrid "" builder


###############################################################################################
#
# install the GLSL filter scripts
#
###############################################################################################

# These could be regarded as kind of optional: without them nothing labelled (GLSL) will work,
# but there again nothing labelled (GLSL) will work anyway unless you have Nvidia/cuda setup,
# which clearly not everybody does.

builder() {
  cd hybrid-glsl-filters
  add_to_basket GLSL "$VS_CORE_PLUGINS" "$(pwd)"
  add_to_basket GLSL-Resizers "$VS_CORE_PLUGINS" "$(pwd)"
  prog_or_plugin="other"     # this prevents falling through to a normal plugin add_to_basket
}

DIY_check_install GLSL plugin git Selur/hybrid-glsl-filters "" builder main



###############################################################################################
#
# and finally, install the relevant files in system locations - will ask for sudo password
#
###############################################################################################

if $dry_run
then
  echo "---> if not for --git-dry-run, would prepare to install files to system locations here"
else
  # write the install to file so we can call it now with sudo
  # OR so you can run it separately after "--no-git-install" if you change your mind about not installing
  { \
  echo '#/bin/bash'
  declare -p basket
  declare -p chicken
  echo '
for egg in ${!basket[@]}
do
  cp -rf "${chicken[$egg]}/$egg" "${basket[$egg]}/"
done'
  } > tmp_hf_install_git$unique_date.sh
  chmod a+x tmp_hf_install_git$unique_date.sh

  if $git_install && [[ ${#basket[@]} -gt 0 ]]
  then
    echo -e "\n\nIf requested, please authenticate as sudo to perform the install to system folders"
    sudo mkdir -p "$VS_CORE_SCRIPTS"
    # compromise tweak to link from Hybrid-hard-coded /usr/bin/GLSL to where the scripts actually are
    if [[ ! -h /usr/bin/GLSL ]]
    then
      sudo ln -s /usr/lib/vapoursynth/GLSL /usr/bin/GLSL
    fi
    sudo ./tmp_hf_install_git$unique_date.sh
    rm -rf $basket_dir
    rm tmp_hf_install_git$unique_date.sh
  elif ! $git_install
  then
    echo "---> if not for --git-no-install, would install files to system locations now"
    echo "NB the files to install have been kept, and you may proceed now to final install
if you do it before tidying up you current directory - just run

sudo ./tmp_hf_install_git$unique_date.sh
"
  fi
fi

# end the transcript file process and write it out
} |& tee ./transcript_hf_git_$unique_date

echo -e "\n###############################################################################################
A transcript of the output from hf_git has been written to file ./transcript_hf_git_$unique_date
###############################################################################################\n"

