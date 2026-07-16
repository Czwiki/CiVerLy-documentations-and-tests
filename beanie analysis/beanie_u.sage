from civerly.cipher_implementations.beanie import BEANIE_CVL
from civerly.model_options import *

beanie = BEANIE_CVL(rl=5,rr=1,rks=[0,0,0,0,0,0], rks_right=[0,0])
model_options = MODEL_OPTIONS(cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL, optimization=OPTIMIZATION.SAT, granularity=GRANULARITY.BITWISE, linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES, sbox_modeling=SBOX_MODELING.LOGICAL_COND_ESPRESSO, sat_solver=CADICAL_CVL(), logic_minimizer=ESPRESSO_CVL(), path=Path("temp/")) 
beanie.analyse(model_options)
beanie.generate_report(model_options)


# Errors when executing:

#Traceback (most recent call last):
#  File "/Users/Uni/Documents/GitHub/CiVerLy-documentations-and-tests/beanie analysis/beanie_u.sage.py", line 13, in <module>
#    beanie.generate_report(model_options)
#    ~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^
#  File "/nix/store/wxz0c42zh7jjj3sd70fj3yh6mk9mzbdz-python3-3.13.11-env/lib/python3.13/site-packages/civerly/cipher.py", line 1758, in generate_report
#    self._write_and_compile_tex(string, model_options)
#    ~~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^
#  File "/nix/store/wxz0c42zh7jjj3sd70fj3yh6mk9mzbdz-python3-3.13.11-env/lib/python3.13/site-packages/civerly/cipher.py", line 2103, in _write_and_compile_tex
#    raise ChildProcessError("Error when compiling .tex file.")
#ChildProcessError: Error when compiling .tex file.