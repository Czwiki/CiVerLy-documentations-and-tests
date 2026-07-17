from civerly.cipher_implementations.blink import BLINK_CVL
from civerly.model_options import *

# way to many variables
blink = BLINK_CVL(n=64)
model_options = model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.MILP, granularity=GRANULARITY.WORDWISE, sbox_modeling=None, linear_layer_modeling=LINEAR_LAYER_MODELING.GENERALIZED_WORDWISE,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp64"), milp_solver=SCIP_CVL())

blink.analyse(model_options)
blink.generate_report(model_options)

#blink = BLINK_CVL(n=128)
#model_options = model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.MILP, #granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, #linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp128"), #milp_solver=SCIP_CVL())
#blink.analyse(model_options)
#blink.generate_report(model_options)