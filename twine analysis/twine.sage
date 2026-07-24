from civerly.cipher_implementations.twine import TWINE_CVL
from civerly.model_options import *
import os
import shutil


model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.LINEAR, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CADICAL_CVL())

for i in range(20,36):
    twine = TWINE_CVL(R=i)
    twine.analyse(model_options)
    twine.generate_report(model_options)
    os.rename("temp/TWINE.pdf", f"temp/TWINE_{i}.pdf")
    shutil.move(f"temp/TWINE_{i}.pdf", f"TWINE_{i}.pdf")
    os.system("rm -f temp/*")


