#!/usr/bin/env python3

import os
import shutil

from devices import DEFAULT_CONSTANTS, DEVICES, models_all

CONST_DIR = "constants"

def generate_constants():
    if os.path.exists(CONST_DIR):
        shutil.rmtree(CONST_DIR)

    os.mkdir(CONST_DIR)

    for model in models_all():
        model_path = os.path.join(CONST_DIR, model)
        model_file = os.path.join(model_path, "constants.mc")
        os.mkdir(model_path)

        with open(model_file, "w") as f:
            model_constants = DEVICES[model].get('constants', {})

            for key in DEFAULT_CONSTANTS.keys():
                val = model_constants.get(key, DEFAULT_CONSTANTS[key])

                f.write(f"const {key} = {val};\n")


generate_constants()