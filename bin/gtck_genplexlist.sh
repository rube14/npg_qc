#!/usr/local/bin/bash

set -o pipefail

# $VERSION = '0';

GTCK_IRODS_ZONE="${GTCK_IRODS_ZONE:-seq}"
dttag="$(date +%Y%m%d%H%M%S)";

printf '*** gtck_genplexlist.sh ***\n'

for zone in ${GTCK_IRODS_ZONE} # single value or space-delimited list
do
  for qc_set in qc cgp ddd
  do
    printf "Generating data_object list for fluidigm_plex = %s\n" ${qc_set}
    jq -n "{avus: [{attribute: \"fluidigm_plex\", value: \"${qc_set}\"}]}" | (irodsEnvFile=$HOME/.irods/.irodsEnv-${zone}_gtck baton-metaquery --zone ${zone} --unbuffered) | jq . | egrep -v "^\[|\]$" | sed -e "s/^  \},$/  \}/" > fluidigm_${qc_set}_${zone}_baton_plex_list_${dttag}.txt

    if [ $? -ne 0 ]
    then
      printf "\n**** ERROR: failed to create plex list for qc_set ${qc_set}\n\n"
      exit -1
    fi

  done
done

echo "${dttag}" > latest_plex_list.txt

printf "Done\n"
