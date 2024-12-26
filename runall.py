#!/usr/bin/env python3

import subprocess

from devices import models_shortlabels, models_midlabels, models_longlabels, models_all

def build_all():
    subprocess.check_call(["make", "clean"])

    for target in models_all():
        subprocess.check_call(["make", "TARGET=" + target])

def run(targets):
    for target in targets:
        subprocess.check_call(["make", "TARGET=" + target, "run"])

#build_all()
run(models_all())
