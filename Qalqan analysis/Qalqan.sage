from civerly.cipher_implementations.qalqan import QALQAN_CVL
from civerly.model_options import *
import os
import shutil

model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES, logic_minimizer= ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CRYPTOMINISAT_CVL())

for i in range(6,10):
    qalqan = QALQAN_CVL(R=i, variant="original")
    qalqan.analyse(model_options)
    qalqan.generate_report(model_options)
    os.rename("temp/QALQAN.pdf", f"temp/QALQAN_diff_{i}.pdf")
    shutil.move(f"temp/QALQAN_diff_{i}.pdf", f"QALQAN_diff_{i}.pdf")
    os.system("rm -f temp/*")
    qalqan = QALQAN_CVL(variant="original", start=i, end=i)
    qalqan.analyse(model_options)
    qalqan.generate_report(model_options)
    os.rename("temp/QALQAN.pdf", f"temp/QALQAN_diff_{i}_single.pdf")
    shutil.move(f"temp/QALQAN_diff_{i}_single.pdf", f"QALQAN_diff_{i}_single.pdf")
    os.system("rm -f temp/*")
