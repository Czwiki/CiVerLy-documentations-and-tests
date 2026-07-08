from civerly.cipher_implementations.aradi import ARADI_CVL
from civerly.model_options import *

aradi = ARADI_CVL(R=3, rks=[0,0,0,0])
model_options = model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES, logic_minimizer= ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CADICAL_CVL())

aradi.analyse(model_options)
aradi.generate_report(model_options)
