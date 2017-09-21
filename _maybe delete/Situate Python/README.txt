Situate-Python
--------------

Run the project by running the file main.py in python. Edit main.py to
configure the experiment's settings, or to run more complicated experiments.

Situate-python currently supports two modes: IOU Oracle and Faster-RCNN. IOU
Oracle compares proposed boxes directly against the ground truth boxes, while
Faster-RCNN uses a CNN to evaluate boxes without looking at human-generated
labels.

Both modes rely on a mat file that stores the image filenames as well as the
results of running the actual Faster-RCNN code on the images. This mat file
should be located in data/[situation].mat, and it should contain a cell array
of all the image filenames (called im_names), and optionally a cell array of
the Faster-RCNN results (called results), which is required for the Faster-RCNN
mode. The script data/faster_rcnn_compute.m can generate the Faster-RCNN
results, but will have to be modified to run on a different computer.


Documentation
-------------

This file provides a high-level overview of the functionality of different
parts of the code. See comments in individual files for function-level
documentation.

box_evaluators.py:
The selected BoxEvaluator determines what mode situate-python runs in. There
are two built-in BoxEvaluators: IOUOracle and FasterRCNN. New BoxEvaluators
must implement each of the functions in the BoxEvaluator abstract class, and
should be placed in the box_evaluators.py file.

conditional_distributions.py:
This file handles creating and querying multivariate gaussian distributions
based on the training data. The class ConditionalDistributions has functions to
get the probability density of a location or to sample boxes from itself. A
ConditionalDistributions is never updated with new detections. Instead, all of
its functions have a detections argument that represents the current detections.

experiment.py:
This file has the code to actually run experiments. Its run_experiment()
function is used to run an experiment with the current settings. It should
not be modified to change experiment settings. Instead, modify the main.py file.

label.py
The Label class stores all the information of the ground-truth boxes of an
image. It also has several functions that are specific to an individual image,
such as checking if a box is contained by that image, or converting a box to
a normalized form (which is dependant on the size of the image).

logistic_regression.py
This file handles using logistic regression to determine the total support
function when using Faster-RCNN. It's currently less optimized than the rest of
the program, and could easily be improved.

main.py
Use this file to configure the experiment's settings, or to run more complicated
experiments. main.py also contains examples of experiment settings that were
found to produce the best results.

settings.py
The settings.settings variable is a global variable that stores the experiment
settings. The settings variable may be read by any file, but it should not be
edited outside of main.py. This file could be useful to look at to get a list of
all the supported experiment settings. Do not modify it to change the experiment
settings directly. Instead, modify the main.py file.

util.py
This file has several utility functions that don't fit anywhere else in the
project, including the function to calculate IOU.

workspace.py
The Workspace class stores all the of information of the current workspace,
including the current image, the number of iterations, and the current
detections. It also has a draw() function that draws the current workspace,
which should be edited to improve situate-python's user interface.
