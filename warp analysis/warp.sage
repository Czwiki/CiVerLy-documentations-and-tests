from civerly.cipher_implementations.warp import WARP_CVL
from civerly.model_options import *
import os
import shutil


model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.LINEAR, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CADICAL_CVL())

for i in range(1,20):
    warp = WARP_CVL(R=i)
    warp.analyse(model_options)
    warp.generate_report(model_options)
    os.rename("temp/WARP.pdf", f"temp/WARP_{i}.pdf")
    shutil.move(f"temp/WARP_{i}.pdf", f"WARP_{i}.pdf")
    os.system("rm -f temp/*")


