#! /bin/sh
# repo2solv
#
# give it a directory of a local mirror of a repo and this
# tries to detect the repo type and generate one SOLV file on stdout

LANG=C

dir="$1"
cd "$dir" || exit 1
if test -d repodata; then
  cd repodata || exit 2

  # This contains a primary.xml* and maybe patches
  for i in primary.xml*; do
    case $i in
      *.gz) cmd="gzip -dc" ;;
      *.bz2) cmd="bzip2 -dc" ;;
      *) cmd="cat" ;;
    esac
    # only check the first primary.xml*, in case there are more
    break
  done
  primfile="/nonexist"
  if test -n "$cmd"; then
    # we have some primary.xml*
    primfile=`mktemp` || exit 3
    $cmd $i | rpmmd2solv > $primfile
  fi

  patchfile="/nonexist"
  if test -f patches.xml; then
    patchfile=`mktemp` || exit 3
    (
     echo '<patches>'
     for i in patch-*.xml*; do
       case $i in
         *.gz) gzip -dc "$i" ;;
	 *.bz2) bzip2 -dc "$i" ;;
	 *) cat "$i" ;;
       esac
     done
     echo '</patches>'
    ) | grep -v '\?xml' | patchxml2solv > $patchfile
  fi

  # Now merge primary and patches
  if test -s $primfile && test -s $patchfile; then
    mergesolv $primfile $patchfile
  elif test -s $primfile; then
    cat $primfile
  elif test -s $patchfile; then
    cat $patchfile
  fi
  rm -f $primfile $patchfile
elif test -d suse/setup/descr; then
  cd suse/setup/descr || exit 2
  (
    # First packages
    if test -s packages.gz; then
      gzip -dc packages.gz
    elif test -s packages.bz2; then
      bzip2 -dc packages.bz2
    elif test -s packages; then
      cat packages
    fi

    # XXX need to do something with packages.DU and packages.{lang}

    # Now patterns.  Not simply those files matching *.pat{,.gz,bz2},
    # but only those mentioned in the file 'patterns'
    if test -f patterns; then
      for i in `cat patterns`; do
        test -s "$i" || continue
        case $i in
          *.gz) gzip -dc "$i" ;;
	  *.bz2) bzip2 -dc "$i" ;;
	  *) cat "$i" ;;
	esac
      done
    fi
  ) | susetags2solv
fi