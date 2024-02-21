# Hybrid+Vapoursynth full install for Manjaro

## Preamble
This set of bash scripts aims to install a complete Hybrid+Vapoursynth environment, with **all** Hybrid tools,
all of the "core" plugins (that enable the various filters in Hybrid's Vapoursynth tab), the master scripts
that enable connections between Hybrid GUI filters and Vapoursynth plugins, and the necessary user config scripts.

It can be considered as a Manjaro equivalent of https://github.com/Selur/hybrid-vapoursynth-addon (which is
scripted for Ubuntu), although there is not much code shared between the two. Some important differences between
the Ubuntu and Manjaro versions:

  * In this installation, as much as possible is installed from Manjaro and AUR repos.  As a consequence, all the
  plugins are installed *globally* (in /usr/lib/vapoursynth) - whereas the Ubuntu version installs to an
  individual user home directory. The Ubuntu version groups everything into one user's "vapoursynth library", this
  Manjaro version has everything system-distributed.
  * Far more plugins are available as AUR packages than are available in Ubuntu repos. Also Ubuntu versions are
  "fixed" aka "binary" packages, and often quite out of date, whereas almost all the AUR versions are -git packages,
  meaning they will use the latest version of the source code taken from the plugin author's github page, downloaded
  and built at the moment of installation.
  * The downside of this: AUR packages are at some risk of being broken by recent source code or dependency updates
  and will then fail to install (whereas Ubuntu's fixed binary installs will be very unlikely to break, simply because
  they do not update "live").

Basically then, this is a set of scripts for relatively advanced users who are able to fix most problems for themselves,
either by temporarily disabling installation of a rogue plugin altogether, or by downloading a source and compiling
outside pamac.  But I hope you will find in these scripts at least a handy package list, and the vast majority will
run first time.

## Installation
You will be installing something like 1GB of software, so make sure you have enough disk space. And time.

All the files in this package should be placed in the same directory (I would recommend a new directory, given that
a bunch of other files will be generated in this same place).  Then

1) Check you are happy with the location for VS_CORE_SCRIPTS as set in hf_header.sh, line 26.  Some people would
say you should really use /opt or /etc or at least something with /local in it for this kind of thing.

2) Ensure that hybrid_full_install.sh and hf_git.sh are executable.  Also be sure to retain a read-only backup of
hf_pamac_list.txt. You will quite likely find yourself having to edit this file after hitting a broken package, so
keeping a clean copy of the original version is a good plan.

3) Run, NOT as sudo,

  `[user]$ ./hybrid_full_install.sh --no-confirm --dry-run --git-dry-run --git-no-confirm `
  
On the basis it is better to identify problems, and perhaps fix those, in advance of the actual install.  I don't
suppose you will actually do this step, but I feel an obligation to at least *try* to persuade you.

5) Run, NOT as sudo,
   
  `[user]$ ./hybrid_full_install.sh [<arguments>]`
  
  with any of the following optional arguments:
  
  * passed through to pamac install (and thus applying to all pamac packages) are any of
    
  `--ignore --overwrite --download-only -w -d --dry-run --as-deps --as-explicit --upgrade --no-upgrade --no-confirm`
  
  * special to github installs and with explanations below are
    
  `--git-dry-run --git-no-confirm --git-no-install --git-force-all --git-retain-source --git-nodate-ok--git-only`
  
  Once you have carefully studied the transcript of the dry run in Step 3 (be honest) and are confident all will go
  well, run
  
  `[user]$ ./hybrid_full_install.sh --no-confirm --git-no-confirm`
  
  and give it about 10 min or so while pamac prepares the transaction(s), then you will be prompted for sudo password.
  I wish that was the end of it, but unfortunately you will have to provide your sudo password *again* every 10 minutes
  or so (depending on your system settings for sudo timeout; in Manjaro this is configurable but tricky). At least
  you don't have to do it for every single package. Right near the very end you will have to respond to a simpler sudo
  password prompt, for the git installs, but after that, it will only take a minute until it's all over.

## pamac and updates - a note about versions
In the nature of AUR -git packages, the version that is installed today is based on today's git clone, and this may be a
later version than what the package promises in its PKGINFO. When you "update" some packages, the "update" will appear to
be a downgrade, eg at the time of writing this, given I already have these packages installed, I get
```text
To build (2):
  vapoursynth-plugin-lsmashsource-git        A.5b.0.gfb891d0-1  (A.5b.10.g5bea7a5-1)  AUR
  vapoursynth-plugin-neo_vague_denoiser-git  2.2.g784b43c-1     (2.3.g5716b33-1)      AUR
```
You might therefore be very tempted to say N to the install - no, I don't want to downgrade!  BUT in fact, if you say
yes, you will find that the version *actually* installed is the latest, eg here for lsmashsource you will end up with
A.5b.10.g5bea7a5-1 installed even though it *says* it will install A.5b.0.gfb891d0-1.  (Of course in this particular case I answer N anyway, because I know I already have the latest, and there's no point
in just replacing it with itself.)

## Maintenance
Unlike in the Ubuntu Hybrid package, the code here compares source code date with the date of your current binary (if any), and
will by default not perform an unnecessary re-install.  Thus this code comes pre-built as ideal for re-use after the
initial installation to pick up source code updates, like a pseudo mini package manager.

Well - that's not the case for the pamac installs, for which pamac will *itself* take charge of testing for packages being
already present and up to date, and notifying if there are updates and then offering to install them (and/or or you can
explicitly run `$pamac checkupdates -a --devel` from time to time).

But for the github-based installs, the hf_git.sh script is designed to be capable of being run "standalone" (well,
I say standalone, but actually it sources hf_header.sh, which needs to be in the same folder). In this use it will,
like an original install, compare the latest github commit date with the date of the binary on your system, and will
update/install on that basis.

As a disclaimer: hf_git.sh can be used as a package-manager *emulator*, it is not a true package manager.

### hf_git.sh arguments
The following optional arguments can be provided to hybrid_full_install.sh for the initial installation (from where they
will be passed to hf_git.sh when the installer calls that), or directly to hf_git.sh when used as a standalone updater:

--git-dry-run  compare dates to see what would update, but do not git clone sources or build or install

--git-no-install  do everything - download and build (if not already up to date) - except for the very final step of
                       (over)writing the built files into system folders
                       (a temporary script will be created which you can run to do the last step if all went well)
                       
--git-no-confirm    -> don't ask questions, just do it
--git-retain-source -> keep rather than delete the download and build directories
--git-force-all     -> force download and rebuild for all github packages regardless of existing timestamps
                       (default is not to rebuild and reinstall if the existing install has timestamp later than github latest)
--git-nodate-ok     -> if a package is found to be already installed, but there is no github API commit datetime check available,
                       assume it is up to date (default is to re-install it)
--git-only item1 item2 ...
                    -> packages not mentioned in the list will be completely ignored. This option must be placed last, with
                       everything following --git-only being read as a list of package names, separated by space.  For this
                       purpose, "package name" must match exactly the first argument to the relevant DIY_check_install() call
                       in hf_git.sh (including .so extension for plugins), eg
                       `--git-only libvsrawsource.so libvsimagereader.so`

Footnote: although I describe all the source-code installs as "git", some of the source code packages are not actually found
on github, but are found archived elsewhere.  That's to say, I have a rather loose definition of "git", should really
say "non-pamac". (But there again all the pamac -git plugins actually use git too ... so it's a very grey area.)  Likewise I
talk about "git packages" but they are not actually packages in any strict sense.

Footnote2: to save you looking them all up, the names of the "github packages" in the current version of hf_git.sh are:
xvid_encraw telxcc vsViewer libscenechange.so libfrfun7.so libgrayworld.so libneo-fft3d.so libvsimagereader.so
libvsrawsource.so libvs_placebo.so libdescratch.so libchromanr.so VapoursynthScriptsInHybrid GLSL

### uninstalling git packages
There's no specific script command or option for this. You simply sudo rm the relevant binary (or script folder) from its
system directory (in almost all cases, there is only one binary per "package"), then next time you run hf_git.sh the package
will be identified as not installed.

## Troubleshooting and adapting this source code
As with all things Hybrid, it is assumed that you are not a complete beginner, so I won't explain too much.
What I *will* mention here that I think is not immediately obvious is that in the event of a complete AUR package failure
that seems likely to have no chance of a quick fix, you could write up your 'git clone build install' substitute as an
extra "module" in a modified hf_git.sh for future reference and updating.  To this end I would for example start from a
clone of the builder/DIY_check_install code block for libneo-fft3d.so (because that one is short and sweet) and I point out:
  * The meaning and usage of the arguments to the DIY_check_install call are quite straightforwardly self-documented in the
  source code for that function.
  * The "builder" function is everything you need to do after the git clone of the source is completed, apart from the actual
  installation of the binary. This function does not have to be called builder, I was just lazy, but the name must be in
  arg 6 of DIY_check_install.
  * The builder function for a plugin *must* exit with the binary to be installed in its current directory (to ensure which,
  you are likely to have to cd to it). The builder function for a prog (destined for /usr/bin) must itself explicitly call
  add_to_basket(). (See e.g. telxcc in hf_git.sh code].)

I'm afraid I cannot offer direct support in case of pamac install failures - please raise any such with the package
maintainer or perhaps try forums.

If one of my builder_DIY_check_install combos becomes broken or if you have a suggestion for an improvement or a new feature,
please raise it as an issue on the github page.





