from civerly.cipher_implementations.blink import BLINK64_CVL, BLINK128_CVL
from civerly.model_options import *

blink = BLINK64_CVL(R=4, k=0x1, t=0x2)
model_options = model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.MILP, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp64"), milp_solver=SCIP_CVL())

blink.analyse(model_options)
blink.generate_report(model_options)

blink = BLINK128_CVL(R=2, k=0x1, t=0x2)
model_options = model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.MILP, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp128"), milp_solver=SCIP_CVL())
blink.analyse(model_options)
blink.generate_report(model_options)