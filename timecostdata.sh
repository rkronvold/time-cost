#!/bin/bash

# read config and validate
source "./timecostdata.conf"

# check for WORKPATH, if this doesn't exist, run the config tool.
if [ ! -d "$WORKPATH" ]; then
  ./configtimesheet.sh
  exit 0
fi

# Check that all required input files are present
for VAR in CONFDIR WORKPATH INFILE CLEANFILE CLEANTMPFILE HEADERFILE PREPFILE EISCFILE POSTFILE ITEMTABLE RATETABLE CLASSTABLE ETABLE ESITABLE ESICTABLE; do
  if [[ ! -v $VAR ]]; then
    echo "Missing $VAR.  Running config." >&2 && ./configtimesheet.sh && exit 1
  fi
done

# check for input files to exist
[ ! -e "$XLSXINFILE" ] && echo "Missing $XLSXINFILE.  Running config." >&2 && ./configtimesheet.sh && exit 1
[ ! -e "$ITEMFILE" ]   && echo "Missing $ITEMFILE.  Running config." >&2   && ./configtimesheet.sh && exit 1
[ ! -e "$RATEFILE" ]   && echo "Missing $RATEFILE.  Running config." >&2   && ./configtimesheet.sh && exit 1
[ ! -e "$CLASSLIST" ]  && echo "Missing $CLASSLIST.  Running config." >&2  && ./configtimesheet.sh && exit 1

# check for confdir and tmpdir and create if possible
[ ! -d "$TMPDIR" ] && mkdir -p "$TMPDIR" && echo "Missing $TMPDIR attempting to create." >&2
[ ! -d "$TMPDIR" ] && echo "Missing $TMPDIR.  Exiting." >&2         && exit 1

LASTMONTH=$(date -d "$(date +%Y%m01) -1 month" +'%b%y')
THISMONTH=$(date -d "$(date +%Y%m01) +0 month" +'%m/%d/%y')

# check for required commands
# check for csvkit
[ ! $(which csvcut) ]    && echo "csvkit not found.  Exiting." >&2 && exit 1
[ ! $(which csvformat) ] && echo "csvkit not found.  Exiting." >&2 && exit 1
[ ! $(which csvgrep) ]   && echo "csvkit not found.  Exiting." >&2 && exit 1
[ ! $(which csvjoin) ]   && echo "csvkit not found.  Exiting." >&2 && exit 1
[ ! $(which csvlook) ]   && echo "csvkit not found.  Exiting." >&2 && exit 1
[ ! $(which csvsort) ]   && echo "csvkit not found.  Exiting." >&2 && exit 1
[ ! $(which csvstack) ]  && echo "csvkit not found.  Exiting." >&2 && exit 1
[ ! $(which csvclean) ]  && echo "csvkit not found.  Exiting." >&2 && exit 1
# check for in2csv
[ ! $(which in2csv) ]    && echo "in2csv not found.  Exiting." >&2 && exit 1
# check for fzf
[ ! $(which fzf) ]       && echo "fzf not found.  Exiting." >&2    && exit 1
# check for bc
[ ! $(which bc) ]        && echo "bc not found.  Exiting." >&2     && exit 1
calculate()
{
    floatscale=1 #default
    result=
    expression=
    while [[ $# -gt 0 ]] && [[ "$1" == "--"* ]] ;
    do
        opt=${1}
        case "${opt}" in
            "--" )
                break 2;;
            "--scale="* )
                floatscale="${opt#*=}";;
            *)
            #   erm.  nothing here.
            ;;
        esac
        shift
    done
    expression=$*
    result=$(echo "scale=${floatscale}; ${expression}" | bc -q 2>/dev/null)
    printf '%*.*f' 0 "${floatscale}" "${result}"
}

hr () { printf "%0$(tput cols)d" | tr 0 ${1:-=}; }

blankhours() { csvgrep -c "quantity" -r "^\\s*$" $POSTFILE | csvlook; }
starttimer() { STARTTIME=$(date +%s); }
stoptimer() { ENDTIME=$(date +%s); ELAPSED=$(( $ENDTIME - $STARTTIME )); echo "Elapsed time: $ELAPSED seconds"; }

csv()
{
  if [ ! "${1}" ]; then
    echo "Usage: csv [items] >> {file.csv}"
    echo "   [items] will be protected against embedded commas"
    echo "   example:"
    echo "   # csv 1 \"2 3 4 5\" \"6-7?8\" \"9,10\""
    echo "   1,2 3 4 5,6-7?8,\"9,10\""
    return
  fi
  #
  local items=("$@") # quote and escape as needed
                     # datatracker.ietf.org/doc/html/rfc4180
  for i in "${!items[@]}"; do
    if [[ "${items[$i]}" =~ [,\"] ]]; then
       items[$i]=\"$(echo -n "${items[$i]}" | sed s/\"/\"\"/g)\"
    fi
  done
  (
    IFS=,
    echo "${items[*]}"
  )
}

############### MAIN
# import items, rates and classes from excel
# import the timesheet data
# clean up the timesheet data
# remove all rows with no employee

# make a list of all the employees
# for each employee, make a list of all employeeServiceItem (memo)
# for each employeeServiceItem, make a list of employeeServiceItemCustomer
# for each employeeServiceItemCustomer, sum hours (into quantity), calulate amount, and generate 2 lines of output with all other fields
#employee
## serviceItem
### company

[ "${DEBUG}" ] && echo "DEBUG enabled" >&2

starttimer

rm -f "$INFILE" "$CLEANFILE" "$CLEANTMPFILE" "$HEADERFILE" "$PREPFILE" "$EISCFILE" "$POSTFILE" "$ITEMTABLE" "$RATETABLE" "$CLASSTABLE" "$ETABLE" "$ESITABLE" "$ESICTABLE"

# verify input files contain sheets
[ "$(in2csv -n "$XLSXINFILE" | grep -c "^Hours$")" == "0" ] && echo "Hours sheet not found in $XLSXINFILE.  Exiting." >&2             && exit 1
[ "$(in2csv -n "$ITEMFILE" | grep -c "^Item$")" == "0" ] && echo "Item sheet not found in $ITEMFILE.  Exiting." >&2                   && exit 1
[ "$(in2csv -n "$RATEFILE" | grep -c "^Rate$")" == "0" ] && echo "Rate sheet not found in $RATEFILE.  Exiting." >&2                   && exit 1
[ "$(in2csv -n "$CLASSLIST" | grep -c "^Class LookUp$")" == "0" ] && echo "Class LookUp sheet not found in $CLASSLIST.  Exiting." >&2 && exit 1

# Convert xlsx's to csv's
echo "Importing Items from excel"   >&2
in2csv "$ITEMFILE"  --sheet Item | csvcut -c "service item","Item Name/Number","Expense Account" | csvformat -U 0 > "$ITEMTABLE"
echo "Importing Rates from excel"   >&2
in2csv "$RATEFILE"  --sheet Rate | csvcut -c Employee,Rate,Index | csvformat -U 0 > "$RATETABLE"
echo "Importing Classes from excel" >&2
in2csv "$CLASSLIST" --sheet "Class LookUp" | csvcut -c "Client Name","Counselor/Class" | csvformat -U 0 > "$CLASSTABLE"

if [ -e "$XLSXINFILE" ]; then
  echo "Importing timesheet data from excel $XLSXINFILE" >&2
  in2csv "$XLSXINFILE" --sheet Hours | csvformat -U 0 > "$INFILE"
fi
echo Import complete >&2
stoptimer >&2

# $INFILE
# "username","payroll_id","fname","lname","number","group","local_date","local_day","local_start_time","local_end_time","tz","hours","jobcode_1","jobcode_2","jobcode_3","class","service item","tasks","tasks gci55","location","notes","approved_status","has_flags","flag_types"

echo "Cleaning up unneeded columns from timesheet data" >&2
# strip unneeded columns from timesheet data
# count the job codes
nrjobcodes=$(csvcut -n "$INFILE" | grep jobcode | wc -l)
# always have 3 jobcodes even when there's only 2 in the input file
if [ $nrjobcodes -eq 2 ]; then
  cat "$INFILE" | csvcut -c fname,lname,hours,jobcode_1,jobcode_2,"service item" | \
    csvformat --out-escapechar \\ --out-quoting 3 | sed -e 's/\\,/%%%/g' | csvformat --out-quoting 0 > "$CLEANTMPFILE"
  csv "jobcode_3" > "$HEADERFILE"
  csvjoin -y 0 "$CLEANTMPFILE" "$HEADERFILE" | csvcut -c fname,lname,hours,jobcode_1,jobcode_2,jobcode_3,"service item" > "$CLEANFILE"
  rm -f "$HEADERFILE" "$CLEANTMPFILE"
else
  cat "$INFILE" | csvcut -c fname,lname,hours,jobcode_1,jobcode_2,jobcode_3,"service item" | \
   csvformat --out-escapechar \\ --out-quoting 3 | sed -e 's/\\,/%%%/g' | csvformat --out-quoting 0 > "$CLEANFILE"
fi

# $CLEANFILE
# "fname","lname","hours","jobcode_1","jobcode_2","jobcode_3","service item"

echo Wrote $CLEANFILE >&2
stoptimer >&2

#set up new files
echo "employee","memo","customer name","rawhours","item" > "$PREPFILE"
# read each line and process
# this could be replaced with csvcut and csvjoin's
echo "Reading timesheet and matching lookup data" >&2
cat "$CLEANFILE" | tail -n+2 | while IFS=, read -r fname lname hours job1 job2 job3 serviceitem ;
do
  # merge name and job code columns
  # if there is no fname, skip the line
  [ "${fname}" == "" ] && continue
  [ "${PROGRESS}" ] && echo -n '-' >&2 # progress indicator
  employee=$(echo "$fname $lname")
#  [ "${DEBUG}" ] && echo "Employee=$employee" >&2
#  [ "${DEBUG}" ] && echo "Hours=$hours" >&2
#  [ "${DEBUG}" ] && echo "job1=$job1" >&2
#  [ "${DEBUG}" ] && echo "job2=$job2" >&2
#  [ "${DEBUG}" ] && echo "job3=$job3" >&2
  jobcodes=$(echo "${job1}:${job2}:${job3}")
  [ "${job3}" == "" ] && jobcodes=$(echo "${job1}:${job2}")
  [ "${job2}" == "" ] && jobcodes=$(echo "${job1}")
  customer=$(echo $jobcodes | sed -e 's/%%%/,/g') # restore commas
  # customer=$(echo $jobcodes | sed -e 's/\$/\\\$/g') # escape dollar signs
# if service item is blank then service = customer, customer = "GLM Admin Time"
  if [ "${serviceitem}" == "" ]; then
    serviceitem=$customer
    customer="GLM Admin Time"
  fi
#  [ "${DEBUG}" ] && echo "customer=$customer" >&2
#  [ "${DEBUG}" ] && echo "serviceitem=$serviceitem" >&2
  [ $EMPLOYEEinMEMO ] && memo=$(echo "${serviceitem} ${employee}") || memo=$(echo "${serviceitem}")
#  [ "${DEBUG}" ] && echo "memo=$memo" >&2
  csv "$employee" "$memo" "$customer" "$hours" "$serviceitem"
done >> "$PREPFILE"

[ "${PROGRESS}" ] && echo "." >&2 # progress indicator end
echo Wrote $PREPFILE >&2
stoptimer >&2

# $PREPFILE
# "employee" "memo" "customer name" "rawhours" "item"

# make a list of all the employees
( echo "employee" ; csvcut -c "employee" "$PREPFILE" | tail -n+2 | sort | uniq ) | csvformat -d , -U 1 > "$ETABLE"

echo "employee,customer name,item,account,quantity,cost,amount,memo,class,invoice,billable,date" > "$POSTFILE"
# parse and total hours (quantity) for each employee, serviceItem, customer
cat "$ETABLE" | tail -n+2 | while read -r employee;
do  # for each employee, make a list of all employeeServiceItem
  # [ "${DEBUG}" ] && echo "employee=$employee" >&2
  e=$(echo $employee | sed 's/\"//g')
  ( echo "employeeServiceItem" ; csvgrep -c "employee" -r "^${e}$" "$PREPFILE" | csvcut -c "memo" | tail -n+2 | sort | uniq ) | csvformat -d , -U 1 > "$ESITABLE"
  [ "${PROGRESS}" ] && echo -n '*' >&2 # progress indicator
  # [ "${DEBUG}" ] && csvlook -y 0 "$ESITABLE" >&2
  cat "$ESITABLE" | tail -n+2 | while read -r employeeServiceItem;
  do  # for each employeeServiceItem, make a list of employeeServiceItemCustomer
  # [ "${DEBUG}" ] && echo "employeeServiceItem=$employeeServiceItem" >&2
    esi=$(echo $employeeServiceItem | sed 's/\"//g')
    ( echo "employeeServiceItemCustomer" > "$ESICTABLE" ; csvgrep -c "employee" -r "^${e}$" "$PREPFILE" | csvgrep -c "memo" -r "^${esi}$" | csvcut -c "customer name" | tail -n+2 | sort | uniq ) | csvformat -d , -U 1 >> $ESICTABLE
  # [ "${DEBUG}" ] && csvlook -y 0 "$ESICTABLE" >&2
    [ $EMPLOYEEinMEMO ] && si=$(echo "${employeeServiceItem/ ${e}/}" | sed 's/\"//g') || si=$(echo "${employeeServiceItem}" | sed 's/\"//g')
    account=$(csvgrep -c "service item" -r "^${si}$" "$ITEMTABLE" | csvcut -c "Expense Account" | tail -n+2)
    item=$(csvgrep -c "service item" -r "^${si}$" "$ITEMTABLE" | csvcut -c "Item Name/Number" | tail -n+2)
  # [ "${DEBUG}" ] && echo "si=$si" >&2
  # [ "${DEBUG}" ] && echo "item=$item" >&2
  # [ "${DEBUG}" ] && echo "account=$account"   >&2
    [ "${PROGRESS}" ] && echo -n '?' >&2 # progress indicator
    cat "$ESICTABLE" | tail -n+2 | while read -r employeeServiceItemCustomer;
    do  # for each employeeServiceItemCustomer, sum quantity, calulate amount, and generate 2 lines of output with all other fields
      esic=$(echo -n $employeeServiceItemCustomer | sed -e 's/\"//g' -e 's/\$/\\$/g' -e 's/(/\\(/g' -e 's/)/\\)/g')
      quantity=$(csvgrep -c "employee" -r "^${e}$" "$PREPFILE" | csvgrep -c "memo" -r "^${esi}$" | csvgrep -c "customer name" -u 1 -r "^${esic}$" | csvcut -c "rawhours" | tail -n+2 | awk '{s+=$1} END {print s}')
      reversequantity=$(calculate --scale=2 "-1 * $quantity")
      cost=$(csvgrep -c "Employee" -r "^${e}$" "$RATETABLE" | csvcut -c "Rate" | tail -n+2)
  #   [ "${DEBUG}" ] && echo "cost=$cost"   >&2    
      amount=$(calculate --scale=2 "$quantity * $cost")
      reverseamount=$(calculate --scale=2 "$reversequantity * $cost")
  #   [ "${DEBUG}" ] && echo "amount=$amount"    >&2   
      # if a class result is empty and class is 2 parts seperated by a colon, then split it and discard the 2nd half
      class=$(csvgrep -c "Client Name" -r "^${employeeServiceItemCustomer}$" "$CLASSTABLE" | csvcut -c "Counselor/Class" | tail -n+2)
      [ "$class" == "" ] && class=$(echo $employeeServiceItemCustomer | cut -d: -f1)
  #   [ "${DEBUG}" ] && echo "class=$class" >&2
      index=$(csvgrep -c "Employee" -r "^${employee}$" "$RATETABLE" | csvcut -c "Index" | tail -n+2)
      invoice=$(echo ${index}${LASTMONTH}cost)
  #   [ "${DEBUG}" ] && echo "index=$index" >&2
  #   [ "${DEBUG}" ] && echo "invoice=$invoice" >&2

      # "employee","customer name","item","account","quantity","cost","amount","memo","class","invoice","billable","date"
      csv "$employee" "$employeeServiceItemCustomer" "$item" "$account" "$quantity" "$cost" "$amount" "$employeeServiceItem" "$class" "$invoice" "N" "$THISMONTH"
      csv "$employee" "" "$item" "$account" "$reversequantity" "$cost" "$reverseamount" "$employeeServiceItem" "" "$invoice" "" "$THISMONTH"
      [ "${PROGRESS}" ] && echo -n '.' >&2 # progress indicator 
    done 
  done 
done >> "$POSTFILE"
# [ "${DEBUG}" ] && csvlook -y 0 -I "$POSTFILE" >&2

[ "${PROGRESS}" ] && echo '' >&2 # progress indicator end
echo Wrote $POSTFILE >&2
stoptimer >&2

# $POSTFILE
# "employee","customer name","item","account","quantity","cost","amount","memo","class","invoice","billable","date"

# sanity checks
echo "Calculating sanity checks..." >&2
# total original hours
totalrawhours=$(csvcut -c "rawhours" "$PREPFILE" | tail -n+2 | awk '{s+=$1} END {print s}')
#total of all positive hours
totalpositivehours=$(csvcut -c "quantity" "$POSTFILE" | tail -n+2 | awk '{if ($1 > 0) s+=$1} END {print s}')
#total quantity of hours
totalhours=$(csvcut -c "quantity" "$POSTFILE" | tail -n+2 | awk '{s+=$1} END {print s}')
# total amount column
totalamount=$(csvcut -c "amount" "$POSTFILE" | tail -n+2 | awk '{s+=$1} END {print s}')
printf "Total Output Hours,Total Output Amount,Total Raw Input Hours,Total Positive Output Hours\n$totalhours,$totalamount,$totalrawhours,$totalpositivehours" | csvlook -y 0 -I

# find all blank hours
echo "===Blank Hours===" >&2
hr
blankhours
hr
echo ""

# cleanup all temp files
rm -f "$INFILE" "$CLEANFILE" "$CLEANTMPFILE" "$HEADERFILE" "$PREPFILE" "$EISCFILE" "$ITEMTABLE" "$RATETABLE" "$CLASSTABLE" "$ETABLE" "$ESITABLE" "$ESICTABLE"

# prompt to move output to final destination
echo "Move $POSTFILE to $OUTFILE? (y/n)" ; read -r answer
[ "$answer" == "y" ] &&  mv -iv "$POSTFILE" "$OUTFILE" && echo "Moved $POSTFILE to $OUTFILE" >&2
# if POSTFILE still exists, then it wasn't moved
[ -e "$POSTFILE" ] && echo "Temporary file $POSTFILE preserved." >&2
exit 0


# each line repeats, swapping quantity and billable = "N" for -1*quantity and billable = ""
#  Employee  Customer Name  Item  Account  Quantity  Cost  Amount  Memo  Class  Invoice  Billable  Date
#  X         X              L     L        MATCH     L     Calc    X     Lookup LOOKUP   N         X
#  X                        "     "        -"        "     -"      "            "                  "

#Employee=$employee
#Customer Name=$company
#Item= lookup $item from itemtable
#Account= lookup $item from itemtable
#Quantity= sum of $hours per $company per $item per $employee
#Cost= lookup $employee from ratetable
#Amount= quantity * cost
#Memo= $item $employee
#Class= lookup $company from classlistmaster.xlsx
######  # if CLASS is blank then item = company, company = "GLM Admin Time"
#Invoice= lookup $employee index from ratetable + MMM + YY + "cost"
#Billable= "N" if $quantity is >0
#Date= manual?   First day of next month

# item subtotals grouped by company and employee
#  Employee1     Item1       Company1
#                          - Company1
#                            Company2
#                          - Company2
#                Item2       Company1
#                          - Company1
#                            CompanyX
#                          - CompanyX
#  Employee2
#  ...
