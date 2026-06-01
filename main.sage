from civerly.cipher_implementations.katan import KATAN_CVL
from civerly.model_options import *

katan = KATAN_CVL(R=50)
model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, sat_solver=CADICAL_CVL(), logic_minimizer=ESPRESSO_CVL(), path=Path(".")) 
katan.analyse(model_options)
katan.generate_report(model_options)
