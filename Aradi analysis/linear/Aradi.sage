from civerly.cipher_implementations.aradi import ARADI_CVL
from civerly.model_options import *

aradi = ARADI_CVL(R=2, rks=[0,0,0])
model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.LINEAR, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, linear_layer_modeling=LINEAR_LAYER_MODELING.EXCLUDE_ODD, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, logic_minimizer=ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CADICAL_CVL())
#aradi.model(model_options)
# .mps file is created
#scip = SCIP_CVL()
#scip.invoke(Path("./temp"), Path("./temp")) # timeouts!!!

aradi.analyse(model_options)
aradi.generate_report(model_options)
#results, objective = solver.process_solution_file(output_file)
