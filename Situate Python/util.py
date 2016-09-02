import itertools

import numpy as np


def IOU(box1, box2):
    """Computes the IOU of two boxes in XYWH format."""
    xmin = max(box1[0], box2[0])
    ymin = max(box1[1], box2[1])
    xmax = min(box1[0] + box1[2], box2[0] + box2[2])
    ymax = min(box1[1] + box1[3], box2[1] + box2[3])
    if xmin >= xmax or ymin >= ymax:
        return 0
    intersection = (xmax - xmin) * (ymax - ymin)
    return intersection / float(box1[2] * box1[3] + box2[2] * box2[3] - intersection)


def merge_dicts(*dict_args):
    """Merges multiple dicts, with later values overwriting previous ones."""
    result = {}
    for dictionary in dict_args:
        result.update(dictionary)
    return result


def powerset(s):
    """Returns the powerset (as a list of frozensets) of any iterable."""
    return [frozenset(l) for r in range(len(s) + 1) for l in itertools.combinations(s, r)]


def sigmoid(x):
    """Computes the sigmoid of the input."""
    return 1 / (1 + np.exp(-x))
