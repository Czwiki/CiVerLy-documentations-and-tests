from civerly.cipher_implementations.serpent import SERPENT_CVL
from civerly.model_options import *
import os
import shutil

first_rounds = [ 1, 5, 1, 4]
last_rounds =  [ 5, 9, 6, 9]

for first, last in zip(first_rounds, last_rounds):
    serpent = SERPENT_CVL(first_round=first, last_round=last)
    model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,logic_minimizer= ESPRESSO_CVL(), path=Path("./temp"), sat_solver=CADICAL_CVL())
    serpent.analyse(model_options)
    serpent.generate_report(model_options)
    os.rename("temp/SERPENT.pdf", f"temp/SERPENT_first{first}_last{last}.pdf")
    shutil.move(f"temp/SERPENT_first{first}_last{last}.pdf", f"SERPENT_first{first}_last{last}.pdf")
    os.system("rm -f temp/*")
   




# s5 three rounds => first round = 5, last round = 7
# s2 three rounds => first round = 2, last round = 4
# s1 four rounds  => first round = 1, last round = 4 (already known)
# s6 four rounds  => first round = 6, last round = 9
# s1 four rounds  => first round = 1, last round = 4 (new)
# s1 five rounds => first round = 1, last round = 5
# s5 five rounds => first round = 5, last round = 9 (already known)
# s5 five rounds => first round = 5, last round = 9 (new)
# s1 six rounds => first round = 1, last round = 6 (already known)
# s4 six rounds => first round = 4, last round = 9 (new)
