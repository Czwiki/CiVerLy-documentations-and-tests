from civerly.cipher_implementations.blink import BLINK_CVL
from civerly.model_options import *
import os
import shutil

#model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer=ESPRESSO_CVL(), path=Path("./temp128"), sat_solver=CADICAL_CVL())

model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.MILP, granularity=GRANULARITY.WORDWISE, linear_layer_modeling=LINEAR_LAYER_MODELING.BRANCH_NUMBER,logic_minimizer=ESPRESSO_CVL(), path=Path("./temp128"), milp_solver=SCIP_CVL())

#model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.MILP, granularity=GRANULARITY.WORDWISE, sbox_modeling=None, linear_layer_modeling=LINEAR_LAYER_MODELING.GENERALIZED_WORDWISE,logic_minimizer=ESPRESSO_CVL(), path=Path("./temp64"), milp_solver=SCIP_CVL())

#for a in range(1,4):
#    for b in range(1,6):
#        blink = BLINK_CVL(n=64,t=64,rl=a,rr=b)
#        blink.analyse(model_options)
#        blink.generate_report(model_options)
#        os.rename("temp64/Blink-64.pdf", f"temp64/Blink-64_ra{a}_rb{b}.pdf")
#        shutil.move(f"temp64/Blink-64_ra{a}_rb{b}.pdf", f"Blink-64_ra{a}_rb{b}.pdf")
#        os.system("rm -f temp64/*")

blink = BLINK_CVL(n=64,t=64, first_round=1, last_round=6)
blink.analyse(model_options)
blink.generate_report(model_options)