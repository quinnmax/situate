# handshaking situation exposes additional complexities
the classifier seemed to over fit to the data in the training set
it had very high training accuracy, pretty low on a validation set (AUROC .98 vs AUROC .76)
using the high AUROC, the external support weight was near 0
using the low AUROC, the external support weight was very high

# bad cycle
with a very high external support weight, early samples with high internal support still have very low total support (as the external support prior to conditioning is always low)
then nothing is added to the workspace
then no conditioning happens
nothing happens

# possible solutions
	-internal support is dynamic as a function of the history of internal support scores found
	-external support is different. combination of pairs and triples in the situation
	-total support is only evaluated once there is conditioning. something like a different total support function pre and post conditioning

# currently implemented solution
the total support functions are now determined using information from all of the classifiers. There is a target value for the total amount of external support that will be used across all object types, as well as a minimum external support for each object. the balance per-object is still a function of AUC, but takes these whole-situation values into account. How this scales to situations with more than 3 objects is not totally clear


