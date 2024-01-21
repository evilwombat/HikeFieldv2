#!/bin/bash

PRODUCTS=""

PROD_LIST="all"

if [[ $PROD_LIST == "all" ]]
then
    PRODUCTS+="approachs60 approachs62 approachs7042mm approachs7047mm d2air d2airx10 d2charlie d2delta d2deltapx d2deltas d2mach1 "
    PRODUCTS+="descentmk1 descentmk2 descentmk2s descentmk343mm descentmk351mm enduro epix2 epix2pro42mm epix2pro47mm epix2pro51mm "
    PRODUCTS+="fenix5 fenix5plus fenix5s fenix5splus fenix5x fenix5xplus fenix6 fenix6pro fenix6s fenix6spro fenix6xpro fenix7 fenix7pro "
    PRODUCTS+="fenix7pronowifi fenix7s fenix7spro fenix7x fenix7xpro fenix7xpronowifi fenixchronos "
    PRODUCTS+="fr245 fr245m fr255 fr255m fr255s fr255sm fr55 fr645 fr645m fr735xt fr745 fr935 fr945 fr945lte fr955 "
    PRODUCTS+="legacyherocaptainmarvel legacyherofirstavenger legacysagadarthvader "
    PRODUCTS+="legacysagarey marq2 marq2aviator marqadventurer marqathlete marqaviator marqcaptain marqcommander marqdriver marqexpedition "
    PRODUCTS+="marqgolfer venu venu2 venu2plus venu2s venu3 venu3s venud venusq venusqm "
    PRODUCTS+="vivoactive3 vivoactive3d vivoactive3m vivoactive3mlte vivoactive4 vivoactive4s vivoactive5 "
fi

if [[ $PROD_LIST == "short" ]]
then
    PRODUCTS+="d2charlie d2delta d2deltapx d2deltas "
    PRODUCTS+="descentmk1 "
    PRODUCTS+="fenix5 fenix5plus fenix5s fenix5splus fenix5x fenix5xplus fenixchronos "
    PRODUCTS+="fr55 fr645 fr645m fr935 "
    PRODUCTS+="venusq venusqm "
fi

if [[ $PROD_LIST == "mid" ]]
then
    PRODUCTS+="vivoactive3 vivoactive3d vivoactive3m vivoactive3mlte vivoactive5 venu3 venu3s "
fi


for TARGET in $PRODUCTS
do
    echo 
    echo "Launching for $TARGET"

    if [[ $1 == '-b' ]]
    then
        make TARGET=$TARGET
    else
#       make clean
        make run TARGET=$TARGET
    fi
done
