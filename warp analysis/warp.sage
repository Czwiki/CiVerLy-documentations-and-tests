from civerly.cipher_implementations.warp import WARP_CVL
from civerly.model_options import *
import os
import shutil
import time

#model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CRYPTOMINISAT_CVL())

#for i in range(1,10):
#    warp = WARP_CVL(R=i)
#    warp.analyse(model_options)
#    warp.generate_report(model_options)
#    os.rename("temp/WARP.pdf", f"temp/WARP_diff_{i}.pdf")
#    shutil.move(f"temp/WARP_diff_{i}.pdf", f"WARP_diff_{i}.pdf")
#    os.system("rm -f temp/*")

#model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.LINEAR, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CRYPTOMINISAT_CVL())

model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CRYPTOMINISAT_CVL())

times_diff = []

for i in range(1,10):
    qalqan = WARP_CVL(R=i)
    t = time.time()
    qalqan.analyse(model_options)
    t = time.time() - t
    times_diff.append(t)
    qalqan.generate_report(model_options)
    os.rename("temp/WARP.pdf", f"temp/WARP_diff_{i}.pdf")
    shutil.move(f"temp/WARP_diff_{i}.pdf", f"WARP_diff_{i}.pdf")
    os.system("rm -f temp/*")

print("\n Differential Times:")
for i in times_diff:
    print(f"Time taken for {times_diff.index(i)+1} rounds: {i:.2f} seconds")


model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.LINEAR, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CRYPTOMINISAT_CVL())

times_linear = []

for i in range(1,14):
    qalqan = WARP_CVL(R=i)
    t = time.time()
    qalqan.analyse(model_options)
    t = time.time() - t
    times_linear.append(t)
    qalqan.generate_report(model_options)
    os.rename("temp/WARP.pdf", f"temp/WARP_linear_{i}.pdf")
    shutil.move(f"temp/WARP_linear_{i}.pdf", f"WARP_linear_{i}.pdf")
    os.system("rm -f temp/*")

print("\n Linear Times:")
for i in times_linear:
    print(f"Time taken for {times_linear.index(i)+1} rounds: {i:.2f} seconds")