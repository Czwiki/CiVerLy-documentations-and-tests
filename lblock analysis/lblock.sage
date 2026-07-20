from civerly.cipher_implementations.lblock import LBLOCK_CVL
from civerly.model_options import *
import os
import shutil


model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.LINEAR, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CADICAL_CVL())

for i in range(19,32):
    qalqan = LBLOCK_CVL(R=i)
    qalqan.analyse(model_options)
    qalqan.generate_report(model_options)
    os.rename("temp/LBLOCK.pdf", f"temp/LBLOCK_{i}.pdf")
    shutil.move(f"temp/LBLOCK_{i}.pdf", f"LBLOCK_{i}.pdf")
    os.system("rm -f temp/*")


