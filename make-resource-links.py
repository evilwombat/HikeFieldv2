#!/usr/bin/env python3

import os
import sys
import shutil

from devices import models_shortlabels, models_midlabels, models_longlabels, models_all

languages = [
    "default",
    "fre",
]


def resource_path(model, lang):
    if lang == "default":
        return f"resources-{model}"
    return f"resources-{model}-{lang}"


def remove_overrides():
    models = models_all()

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
create_overrides(models_longlabels(), "long")
create_overrides(models_midlabels(), "mid")
create_overrides(models_shortlabels(), "short")
