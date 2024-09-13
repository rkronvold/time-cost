#!/bin/bash

# This script is used to configure the input files for the timecostdata.sh script
# It will prompt the user to select the input files from a list of files in the WORKPATH
# The selected files will be written to the timecostdata.conf file

# load config file
source ./timecostdata.conf

# TODO: check for required variables and create them from a template if they don't exist

# check for required commands
# check for csvkit
[ ! $(which csvcut) ]    && echo "csvkit not found.  Exiting." && exit 1
[ ! $(which csvformat) ] && echo "csvkit not found.  Exiting." && exit 1
[ ! $(which csvgrep) ]   && echo "csvkit not found.  Exiting." && exit 1
[ ! $(which csvjoin) ]   && echo "csvkit not found.  Exiting." && exit 1
[ ! $(which csvlook) ]   && echo "csvkit not found.  Exiting." && exit 1
[ ! $(which csvsort) ]   && echo "csvkit not found.  Exiting." && exit 1
[ ! $(which csvstack) ]  && echo "csvkit not found.  Exiting." && exit 1
[ ! $(which csvclean) ]  && echo "csvkit not found.  Exiting." && exit 1
# check for in2csv
[ ! $(which in2csv) ]    && echo "in2csv not found.  Exiting." && exit 1
# check for fzf
[ ! $(which fzf) ]       && echo "fzf not found.  Exiting."    && exit 1

newconfig() {
  cat <<EOG | column -s: -t > ./timecostdata.conf
#input files

#end input files
:
#paths
WORKPATH="/mnt/c/Users/rkronvold/OneDrive - GLM"    : # this MUST be set
CONFDIR="\$(pwd)"                                   : # no need to change this
TMPDIR="\${CONFDIR}/tmp"                            : # defaults to under wherever the conf file is
:
#working files                                      : # These should automatically
INFILE="\${TMPDIR}/inputfile.csv"
CLEANFILE="\${TMPDIR}/cleaned_timesheet.csv"
CLEANTMPFILE="\${TMPDIR}/tmp_timesheet.csv"
HEADERFILE="\${TMPDIR}/header.csv"
PREPFILE="\${TMPDIR}/prepared_timesheet.csv"
EISCFILE="\${TMPDIR}/prepared_esic.csv"
POSTFILE="\${TMPDIR}/post_timesheet.csv"
:
#data tables                                         : # These should automatically
ITEMTABLE="\${TMPDIR}/itemtable.csv"
RATETABLE="\${TMPDIR}/ratetable.csv"
CLASSTABLE="\${TMPDIR}/classtable.csv"
ETABLE="\${TMPDIR}/employee.csv"
ESITABLE="\${TMPDIR}/esitable.csv"
ESICTABLE="\${TMPDIR}/esictable.csv"
:
#settings                                            : # These are set to defaults automatically
EMPLOYEEinMEMO=1  : # If 1 then employee name is included in memo field, otherwise just the service item
PROGRESS=         : # If 1 then progress marks are included, otherwise not
DEBUG=            : # If 1 then debug output is included, otherwise not
EOG
  echo "New config file created.  Please edit WORKPATH and run again."
  exit 0
}

# verify if critical variables exist
for VAR in CONFDIR WORKPATH INFILE CLEANFILE CLEANTMPFILE HEADERFILE PREPFILE EISCFILE POSTFILE ITEMTABLE RATETABLE CLASSTABLE ETABLE ESITABLE ESICTABLE; do
  if [[ ! -v $VAR ]]; then
    echo "$VAR does not exist." >&2
    # prompt to create new config file from template
    read -p "Create new config file from template? [y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      newconfig
      exit 1
    else
      echo "Cannot continue without $VAR.  Exiting." >&2
      exit 1
    fi
    echo "Cannot continue without $VAR.  Exiting." >&2
    exit 1
  fi
done


# set fzf options
export FZF_DEFAULT_OPTS="--layout=reverse --select-1 --exit-0 --border --border-label-pos=3 --height=80% --margin=20%,20% --header='CTRL-c or ESC to quit'"

########
# MAIN
#
# read command line params
# --clear to clear input files
# anything else runs an interactive config walkthrough

# backup config file
cp ./timecostdata.conf ./timecostdata.bak

if [ "${1}" == "--clear" ]; then
  cat ./timecostdata.conf | sed '1,/#end input files/d' > ./timecostdata.new
  mv -v ./timecostdata.new ./timecostdata.conf
  echo "Cleared input files"
  exit 0
fi

# --border=[style]
#[rounded|sharp|bold|block|thinblock|double|horizontal|vertical|top|bottom|left|right|none] (default: rounded)

THISMONTH=$(date +'%m-%Y')
LASTMONTH=$THISMONTH
# select WORKDIR
WORKDIR="$WORKPATH/$(ls "$WORKPATH" | fzf -1 --query=${THISMONTH} --border-label="Select folder where review file is located")"
[ "$XLSXINFILE" == "" ] && XLSXINFILE=$(ls "${WORKDIR}"/*Review.xlsx | fzf -1 --query=${LASTMONTH} --border-label="Select input xlsx file")
# set OUTFILE to XLSXINFILE with "Review" replaced with "Import" and replace the extension with csv then replace /Files - GLM All/Billing/ with /Files - GLM Admin/Human Resources/Time-Cost Reports/
[ "$OUTFILE" == "" ] && OUTFILE=$(echo "$XLSXINFILE" | sed 's/\/Files - GLM All\/Billing\//\/Files - GLM Admin\/Human Resources\/Time-Cost Reports\//' | sed 's/Review/Import/' | sed 's/\(.*\)\..*/\1.csv/')
# show the list of xlsx files and select one for CLASSLIST
[ -e "$CLASSLIST" ] || CLASSLIST=$(ls -1 "${WORKDIR}"/../*xlsx | fzf -1 --border-label="Select Class List file")
# Itemfile and Ratefile default to the same dir as OUTFILE and the filename LookUps.xlsx but can be set manually to different files
[ -e "$ITEMFILE" ] || ITEMFILE="$(dirname "$OUTFILE")/LookUps.xlsx"
[ -e "$RATEFILE" ] || RATEFILE="$(dirname "$OUTFILE")/LookUps.xlsx"

# verify all files exist except INFILE and OUTFILE, send a message and exit if not
for FILE in "$XLSXINFILE" "$ITEMFILE" "$RATEFILE" "$CLASSLIST"; do
  if [ ! -e "$FILE" ]; then
    echo "File $FILE does not exist.  Exiting."
    exit 1
  fi
done

# Format output
cat <<EOA  | column -s: -t > ./timecostdata.new
#input files
:
XLSXINFILE="${XLSXINFILE}" :# imports from the Hours tab
CLASSLIST="${CLASSLIST}"   :# imports from the Class LookUp tab
ITEMFILE="${ITEMFILE}"     :# imports from the Item tab
RATEFILE="${RATEFILE}"     :# imports from the Rate tab
OUTFILE="${OUTFILE}"       :# This should automatically be set to match the XLSXINFILE location
:
#end input files
EOA



# display the new config file
# confirm and write to config file
REPLY=$(( printf "Write to config\nAbort\n" ; cat ./timecostdata.new ) | fzf --border-label="Confirm write to config file?" )

if [[ "$REPLY" == "Write to config" ]]; then
  cat ./timecostdata.conf | sed '1,/#end input files/d' > ./timecostdata.clear
  cat ./timecostdata.new ./timecostdata.clear > ./timecostdata.conf
  rm -f ./timecostdata.new ./timecostdata.clear
  echo "Config file updated"
else
  echo "Aborted"
  rm -f ./timecostdata.new
fi
exit 0

# End of script
