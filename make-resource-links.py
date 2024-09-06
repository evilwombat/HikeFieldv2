#!/usr/bin/env python3

import os
import sys
import shutil

languages = [
    "default",
    "fre",
]

models_shortlabels = [
    "d2charlie",
    "d2delta",
    "d2deltapx",
    "d2deltas",
    "descentmk1",
    "fenix5",
    "fenix5plus",
    "fenix5s",
    "fenix5splus",
    "fenix5x",
    "fenix5xplus",
    "fenixchronos",
    "fr55",
    "fr645",
    "fr645m",
    "fr935",
    "venusq",
    "venusqm",
]

models_midlabels = [
    "approachs60",
    "fenix843mm",
    "fenix847mm",
    "fenixe",
    "fr165",
    "fr165m",
    "fr265",
    "fr265s",
    "fr955",
    "fr965",
    "vivoactive3",
    "vivoactive3d",
    "vivoactive3m",
    "vivoactive3mlte",
    "vivoactive5",
    "venu3",
    "venu3s",
]

models_longlabels = [
    "approachs62",
    "approachs7042mm",
    "approachs7047mm",
    "d2air",
    "d2airx10",
    "d2mach1",
    "descentmk2",
    "descentmk2s",
    "descentmk343mm",
    "descentmk351mm",
    "enduro",
    "enduro3",
    "epix2",
    "epix2pro42mm",
    "epix2pro47mm",
    "epix2pro51mm",
    "fenix6",
    "fenix6pro",
    "fenix6s",
    "fenix6spro",
    "fenix6xpro",
    "fenix7",
    "fenix7pro",
    "fenix7pronowifi",
    "fenix7s",
    "fenix7spro",
    "fenix7x",
    "fenix7xpro",
    "fenix7xpronowifi",
    "fenix8solar47mm",
    "fenix8solar51mm",
    "fr245",
    "fr245m",
    "fr255",
    "fr255m",
    "fr255s",
    "fr255sm",
    "fr735xt",
    "fr745",
    "fr945",
    "fr945lte",
    "legacyherocaptainmarvel",
    "legacyherofirstavenger",
    "legacysagadarthvader",
    "legacysagarey",
    "marq2",
    "marq2aviator",
    "marqadventurer",
    "marqathlete",
    "marqaviator",
    "marqcaptain",
    "marqcommander",
    "marqdriver",
    "marqexpedition",
    "marqgolfer",
    "venu",
    "venu2",
    "venu2plus",
    "venu2s",
    "venud",
    "vivoactive4",
    "vivoactive4s",
]

def resource_path(model, lang):
    if lang == "default":
        return f"resources-{model}"
    return f"resources-{model}-{lang}"


def remove_overrides():
    models = models_longlabels + models_midlabels + models_shortlabels

    for model in models:
        for lang in languages:
            path = resource_path(model, lang)
            if os.path.exists(path):
                shutil.rmtree(path)


def create_overrides(models, prefix):
    for lang in languages:
        target_file = f"../labels-{prefix}/{lang}.xml"
    
        for model in models:
            resource_dir = resource_path(model, lang)
            os.mkdir(resource_dir)
            os.symlink(target_file, f"{resource_dir}/strings.xml")


if len(sys.argv) == 2 and sys.argv[1] == '-c':
    remove_overrides()
    sys.exit(0)

remove_overrides()
create_overrides(models_longlabels, "long")
create_overrides(models_midlabels, "mid")
create_overrides(models_shortlabels, "short")
