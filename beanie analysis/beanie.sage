from civerly.cipher_implementations.beanie import BEANIE_CVL
from civerly.model_options import *

beanie = BEANIE_CVL(R=5)
model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, sat_solver=CADICAL_CVL(), logic_minimizer=ESPRESSO_CVL(), path=Path(".temp/")) 
beanie.analyse(model_options)
beanie.generate_report(model_options)
