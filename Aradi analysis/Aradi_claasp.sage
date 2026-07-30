from claasp.ciphers.block_ciphers.aradi_block_cipher_sbox import AradiBlockCipherSBox
from claasp.cipher_modules.models.sat.sat_models.sat_xor_linear_model import SatXorLinearModel
import pprint
cipher = AradiBlockCipherSBox(number_of_rounds=1)
model = SatXorLinearModel(cipher)
trail = model.find_lowest_weight_xor_linear_trail()
pprint.pp(trail)

#from claasp.ciphers.block_ciphers.aradi_block_cipher_sbox import AradiBlockCipherSBox
#from claasp.cipher_modules.models.milp.milp_models.milp_xor_linear_model import MilpXorLinearModel
#import pprint
#cipher = AradiBlockCipherSBox(number_of_rounds=1)
#model = MilpXorLinearModel(cipher)
#trail = model.find_lowest_weight_xor_linear_trail()
#pprint.pp(trail)