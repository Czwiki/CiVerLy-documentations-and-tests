from civerly.cipher_implementations.qalqan import QALQAN_CVL
from civerly.model_options import *

qalqan = QALQAN_CVL(R=4, key=0)
model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CADICAL_CVL())

qalqan.analyse(model_options)
qalqan.generate_report(model_options)

