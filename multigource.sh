#!/usr/bin/env bash
# Generates gource video (h.264) out of multiple repositories.
# Pass the repositories in command line arguments.
# Example:
# multigource.sh /path/to/repo1 /path/to/repo2

VERSION=1.0.0
RESOLUTION="1920x1080"
OUTPUT_FILE="gource.mp4"
COMBINED_LOG="/tmp/gource.combined"
COMMITTERS_FILE="committers.txt"
REPOSITORIES_FILE="repositories.txt"
IMAGE_DIR="users"
ROOT_FOLDER="$( cd "$( dirname "$0" )" && pwd )"

cd "${ROOT_FOLDER}"

# Tests exit code. Exits on failure and prints message.
# On success, prints optional message.
# $1 = return code to check. 0 is success, anything else failure
# $2 = error message
# $3 = optional success message
test_exit() {
    if [[ $1 -ne 0 ]]; then
        echo -e "$2"
        exit $1
    elif [[ -n ${3+x} ]]; then
        echo -e "$3"
    fi
}

# Merges multiple lines into given file into one sed replacement line:
#   <pattern1>,<replacement1>\n<pattern2>,<replacement2>
# to
#   s/<pattern1>/<replacement1>/;s/<pattern2>/<replacement2>/
# $1 = input file name
# $2 = separator
load_sed_pattern_from_file() {
    local sep="${2}"

    if [[ -f ${1} ]]; then
        sed "s/\(.*\),\(.*\)/s\/${sep}\1${sep}\/${sep}\2${sep}\//" ${1} | tr '\n' ';'
    else
        echo ""
    fi
}

# Ask if patterns are OK and save into file if user says no.
# $1 = Pattern name (plural, lower cased)
# $2 = sed replace pattern used in replacing values
# $3 = File with patterns
# $4 = Discovered values from combined log
save_patterns_to_file() {
    local pattern_name=$1
    local sed_replace_patterns=$2
    local filename=$3
    local values=$4

    echo -e "\n${pattern_name^} replacement pattern: '${sed_replace_patterns}'\n\n"
    echo -e "${pattern_name^}:\n=============\n\n${values}\n"

    read -p "Are you satisfied with the list of ${pattern_name} above? [y]/n " answer

    if [[ ${answer} == 'n' ]]; then
        if [[ ! -f ${filename} ]]; then
            echo "${values}" | awk '{print $0","$0}' >${filename}
        fi
        test_exit 1 "\nEdit ${filename}. Each line is '<match>,<replacement>'. Remove this file to have new one generated.\n"
    fi
}

gource --help >/dev/null 2>&1
test_exit $? "Gource is not installed. Visit https://gource.io/"

ffmpeg --help >/dev/null 2>&1
test_exit $? "ffmpeg is not installed."

read -p "Output video into [${OUTPUT_FILE}]: " answer
[[ -n ${answer} ]] && OUTPUT_FILE="${answer}"

read -p "Output video resolution [${RESOLUTION}]: " answer
[[ -n ${answer} ]] && RESOLUTION="${answer}"

read -p "Do you want to pull all repositories? y/[n] " answer
[[ ${answer} == 'y' ]] && pull_repos=true

if [[ $# -eq 0 ]]; then
    echo "Auto discovering repositories..."
    repositories=$(find . -maxdepth 1 -mindepth 1 -type d ! -name 'users' -printf "%f\n" | sort)
else
    echo "Using repositories given from command line ..."
    repositories=$(echo $* | tr ' ' '\n')
fi

echo -e "\nCollecting git logs ..."

i=0
for repo in ${repositories}; do
    echo "Processing ${repo}"

    if [[ -n ${pull_repos} ]]; then
        cd ${repo}
        git fetch --all -p
        git pull
        cd "${ROOT_FOLDER}"
    fi

	# Generate a Gource custom log files for each repo. This can be
	# facilitated by the --output-custom-log FILE option of Gource as of 0.29:
	logfile="$(mktemp /tmp/gource.XXXXXX)"
	gource --output-custom-log "${logfile}" ${repo}

	# 2. If you want each repo to appear on a separate branch instead of merged
	# onto each other (which might also look interesting), you can use a 'sed'
	# regular expression to add an extra parent directory to the path of the
	# files in each project:
	sed -i -E "s#(.+)\|#\1|/${repo}#" ${logfile}
	logs[$i]=${logfile}
	let i=$i+1
done

echo -e "\nCombining logs, replacing user and repository names ..."

committers_sed_patterns=$(load_sed_pattern_from_file ${COMMITTERS_FILE} '|')
repository_sed_patterns=$(load_sed_pattern_from_file ${REPOSITORIES_FILE} '')

cat ${logs[@]} | sort -n | sed "${committers_sed_patterns}${repository_sed_patterns}" >${COMBINED_LOG}
rm ${logs[@]}

save_patterns_to_file "committers" "${committers_sed_patterns}" "${COMMITTERS_FILE}" \
    "$(cat ${COMBINED_LOG} | awk -F\| {'print  $2'} | sort | uniq)"
save_patterns_to_file "repository names" "${repository_sed_patterns}" "${REPOSITORIES_FILE}" \
    "$(cat ${COMBINED_LOG} | awk -F\| {'print  $4'} | sed 's/\/\([^/]*\)\/.*/\1/' | sort | uniq)"

echo -e "\nTo add/change photos of users, put image files into the '${IMAGE_DIR}' directory. File name must match displayed user name.\n"
mkdir -p ${IMAGE_DIR}

#     --dir-name-position 1 \
time \
gource ${COMBINED_LOG} \
	--seconds-per-day .5 \
    --auto-skip-seconds 1 \
    --filename-time 2.0 \
	-${RESOLUTION} \
	--highlight-users \
    --highlight-colour FF8888 \
	--hide filenames \
    --max-user-speed 100 \
	--file-extensions \
    --date-format "%d %B %Y" \
    --bloom-intensity 0.25 \
	--hide mouse,filenames \
    --dir-name-depth 1 \
    --user-image-dir ${IMAGE_DIR} \
	--stop-at-end \
    --output-ppm-stream - | \
ffmpeg \
    -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libx265 -preset ultrafast \
    -pix_fmt yuv420p -crf 1 -threads 0 -bf 0 "$OUTPUT_FILE"

echo "Output video:"
du -h ${OUTPUT_FILE}

#rm ${COMBINED_LOG}
