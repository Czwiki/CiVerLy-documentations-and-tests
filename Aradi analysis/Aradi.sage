from civerly.cipher_implementations.aradi import ARADI_CVL
from civerly.model_options import *
from civerly.solvers import SCIP_CVL, GUROBI_CVL, GLPK_CVL

aradi = ARADI_CVL(R=5, rks=[0,0,0,0,0,0])
model_options = model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.MILP, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.CONVEX_HULL, linear_layer_modeling=LINEAR_LAYER_MODELING.CONVEX_HULL, path=Path("./temp"))
aradi.model(model_options)
# .mps file is created
scip = SCIP_CVL()
scip.invoke(Path("./temp"), Path("./temp")) # timeouts!!!
# This next? aradi.generate_report(model_options)

#results, objective = solver.process_solution_file(output_file)
