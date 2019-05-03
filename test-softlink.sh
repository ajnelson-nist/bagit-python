#!/bin/bash

# This software was developed at the National Institute of Standards
# and Technology in whole or in part by employees of the Federal
# Government in the course of their official duties. Pursuant to
# title 17 Section 105 of the United States Code portions of this
# software authored by NIST employees are not subject to copyright
# protection and are in the public domain. For portions not authored
# by NIST employees, NIST has been granted unlimited rights. NIST
# assumes no responsibility whatsoever for its use by other parties,
# and makes no guarantees, expressed or implied, about its quality,
# reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.

# Usage:
#   $0 (1|2|3|4|5|6|7|8)
#
#   The first argument is an integer to pick the test.
#
#   1: Call bagit.py on directory with one regular file nested in one directory.
#   2: As with 1, but there is also a soft link to the regular file.
#   3: As with 2, but there is also a soft link to the directory.
#   4: As with 3, but there is also a soft link to a file outside of the bag directory, absolute-pathed.
#   5: As with 4, but there is also a soft link to a file outside of the bag directory, relative-pathed.
#   6: As with 5, but there is also a soft link to a non-existent file.
#   7: As with 6, but expected soft link files are listed in a soft-link manifest file.
#      That manifest file is created by hand.
#   8: As with 7, but the soft-link manifest file is not created by hand.
#
#   This is the goal test matrix status:
#
#   # | PASS | FAIL | XPASS | XFAIL
#   _______________________________
#   1 |    1 |      |       |
#   2 |    1 |      |       |
#   3 |    1 |      |       |
#   4 |    1 |      |       |
#   5 |    1 |      |       |
#   6 |    1 |      |       |
#   7 |    1 |      |       |
#   8 |    1 |      |       |
#
#   This is the current test matrix status:
#
#   # | PASS | FAIL | XPASS | XFAIL
#   _______________________________
#   1 |    1 |      |       |
#   2 |    1 |      |       |
#   3 |    1 |      |       |
#   4 |      |    1 |       |
#   5 |      |    1 |       |
#   6 |      |    1 |       |
#   7 |      |    1 |       |
#   8 |      |    1 |       |

set -e
set -u

this_script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
bn0=$(basename $0)

test_mode=$1
if [ 0 -ge $test_mode -o 9 -le $test_mode ]; then
  echo "ERROR:$bn0:\$1 (the test mode) is expected to be an integer in the range {1, ..., 8}." >&2
  exit 1
fi

# Variable declared here for visual scope representation.
absolute_path_file_outside_bag_txt=

workdir=$(mktemp -d)
pushd $workdir
  # Beginning scaffolding setup:  Hand-crafting the bag to stress-test symbolic link features.

  # Scaffolding: One file outside the directory to be bagged.
  echo 'file_outside_bag.txt' > file_outside_bag.txt

  mkdir dir_to_bag
  pushd dir_to_bag
    # Scaffolding: One directory, one file in that directory, inside the directory to be bagged.
    mkdir directory
    echo 'regular_file.txt' > directory/regular_file.txt
    #DEBUG ls -lR directory

    # Scaffolding for additional tests.
    if [ 2 -le $test_mode ]; then
      ln -s directory/regular_file.txt link_to_regular_file.txt
    fi

    if [ 3 -le $test_mode ]; then
      ln -s directory link_to_directory
    fi

    if [ 4 -le $test_mode ]; then
      absolute_path_file_outside_bag_txt=$(realpath ${PWD}/../file_outside_bag.txt)
      ln -s "$absolute_path_file_outside_bag_txt" link_to_absolute_file_outside_bag.txt
    fi

    if [ 5 -le $test_mode ]; then
      ln -s ../file_outside_bag.txt link_to_relative_file_outside_bag.txt
    fi

    if [ 6 -le $test_mode ]; then
      ln -s nonexistent.txt link_to_nonexistent_file.txt
    fi
  popd #dir_to_bag

  # Finished with scaffolding.

  # Build the bag.
  python "${this_script_dir}/bagit.py" dir_to_bag

  pushd dir_to_bag
    #DEBUG cat manifest-sha256.txt

    # Expect: data/directory/regular_file.txt in manifest-sha256.txt
    manifest_has_regular_file_txt=$(grep 'data\/directory\/regular_file.txt' manifest-sha256.txt | wc -l | tr -d ' ')
    if [ 0 -eq $manifest_has_regular_file_txt ]; then
      echo "ERROR:$bn0:Expected file not found in hash manifest: data/directory/regular_file.txt." >&2
      exit 1
    fi

    # Expect: data/link_to_regular_file.txt in manifest-sha256.txt
    if [ 2 -le $test_mode ]; then
      manifest_has_link=$(grep 'data\/link_to_regular_file.txt' manifest-sha256.txt | wc -l | tr -d ' ')
      if [ 0 -eq $manifest_has_link ]; then
        echo "ERROR:$bn0:Expected file not found in hash manifest: data/link_to_regular_file.txt." >&2
        exit 1
      fi
    fi

    # Expect: data/link_to_directory/regular_file.txt NOT in manifest-sha256.txt
    if [ 3 -le $test_mode ]; then
      manifest_has_link=$(grep 'data\/link_to_directory\/regular_file.txt' manifest-sha256.txt | wc -l | tr -d ' ')
      if [ 0 -ne $manifest_has_link ]; then
        echo "ERROR:$bn0:Unexpected file found in hash manifest: data/link_to_directory/regular_file.txt." >&2
        exit 1
      fi
    fi

    # Expect: data/link_to_nonexistent_file.txt NOT in manifest-sha256.txt
    if [ 6 -le $test_mode ]; then
      manifest_has_link=$(grep 'data\/link_to_nonexistent_file.txt' manifest-sha256.txt | wc -l | tr -d ' ')
      if [ 0 -ne $manifest_has_link ]; then
        echo "ERROR:$bn0:Unexpected file found in hash manifest: data/link_to_nonexistent_file.txt." >&2
        exit 1
      fi
    fi

    if [ ! -r manifest-links.txt ]; then
      if [ 8 -le $test_mode ]; then
        echo "ERROR:$bn0:manifest-links.txt was not created by bagit.py." >&2
        exit 1
      fi
      printf "directory/regular_file.txt\tlink_to_regular_file.txt\n" > manifest-links.txt
      printf "directory\tlink_to_directory\n" >> manifest-links.txt
      printf "${absolute_path_file_outside_bag_txt}\tlink_to_absolute_file_outside_bag.txt\n" >> manifest-links.txt
      printf "../file_outside_bag.txt\tlink_to_relative_file_outside_bag.txt\n" >> manifest-links.txt
      printf "nonexistent.txt\tlink_to_nonexistent_file.txt\n" >> manifest-links.txt
    fi

    # Expect: data/link_to_regular_file.txt              in manifest-links.txt
    # Expect: data/link_to_directory                     in manifest-links.txt
    # Expect: data/link_to_absolute_file_outside_bag.txt in manifest-links.txt
    # Expect: data/link_to_relative_file_outside_bag.txt in manifest-links.txt
    # Expect: data/link_to_directory/regular_file.txt    NOT in manifest-links.txt
    # Expect: data/link_to_nonexistent_file.txt          NOT in manifest-links.txt
    #TODO: Turn the above into an expected-contents file, and run 'comm' instead of grep tests.  Forward slashes in patterns sometimes behave in unexpected ways, so it's best to remove that question possibility.
    if [ 7 -le $test_mode ]; then
      for x in \
        data/link_to_regular_file.txt \
        data/link_to_directory \
        data/link_to_absolute_file_outside_bag.txt \
        data/link_to_relative_file_outside_bag.txt \
        ; do
        manifest_has_link=$(grep "$x" manifest-links.txt | wc -l | tr -d ' ')
        if [ 1 -ne $manifest_has_link ]; then
          echo "ERROR:$bn0:Expected file not found in hash manifest: $x." >&2
          exit 1
        fi
      done

      for x in \
        data/link_to_directory/regular_file.txt \
        data/link_to_nonexistent_file.txt \
        ; do
        manifest_has_link=$(grep "$x" manifest-links.txt | wc -l | tr -d ' ')
        if [ 0 -ne $manifest_has_link ]; then
          echo "ERROR:$bn0:Unexpected file found in hash manifest: $x." >&2
          exit 1
        fi
      done
    fi
  popd #dir_to_bag
popd #$workdir
