Wie komme ich an eine .sat Datei? check
Wann benutze ich MILP und wann SAT? MILP geht nicht für alles, sondern nur für SBoxCipher()
Was geht da mit diesen .pla-Dateien? Kann man erneut benutzen, Output Dateien von Espresso
Was kommt nach analyse? generate_report(model_options) oder get_trail(model_options) <- kommt bei stdout raus 

Difference distribution tables erstellen zu chiffren und die Transtion funktion S(X)^S(X^a) = b minimieren, indem man die Inputs findet 

DDT geben Auskunft über die Stärke der S-Box. Je niedriger die Werte, desto besser ist die SBOX, Je höher die Werte, desto mehr X gibt es, die eine Transition von a nach b mappen

Möglichst viele S-Boxen in eine triviale "umwandeln"/inaktivieren, um die Konfusion mögliochst niedirg zu halten (gegen Diffusion (Linear layer) kann man halt erstmal nichts machen)

Diffusion "bekämpft" man mit wordwise analyse
mit bitwise geht man darüber hinaus und versucht, auch die S-Boxen zu minimieren

Granularity = Steuereung von Wordwise und bitwise
solver mit Präfix steuern

[nix installieren
nix develop in CiVerLy directory aufrufen => neues Environment]


Angriff suchen mit 70+24 Angriff, oberflächlicher Abgleich mit meiner Analyse

generate test vectors with reference implementation 
try to benchmark against all-in-one-differential papter results on KATAN-32

https://eprint.iacr.org/2012/401.pdf
