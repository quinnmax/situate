import pydoc
import sys
from datetime import datetime

import hickle
import matplotlib.pyplot as plt
from sklearn.cross_validation import KFold

from workspace import *


class ExperimentResults(object):
    """This class represents the results of an experiment."""

    def __init__(self, completed, iters):
        self.completed = completed
        self.iters = iters
        self.successful = completed.reshape([len(completed), -1])[:, 0].astype(bool)

    def median_iters(self):
        return np.median(self.iters)

    def num_successful(self):
        return np.sum(self.successful)


def run_experiment():
    """Run a single 10-fold crossvalidated experiment."""

    box_evaluator = pydoc.locate('box_evaluators.' + settings.box_evaluator)()
    image_files = box_evaluator.get_image_files()

    # Initialize misc variables
    image_count = 0
    completed = np.zeros([len(image_files)] + [3] * len(settings.objects))
    iters = np.zeros([len(image_files)])

    # Divide the data into 10 folds for crossvalidation
    for train, test in KFold(len(image_files), n_folds=10, shuffle=True):

        # Learn things from the training data
        box_evaluator.train(train)

        # Step through each of the images
        for i in test:
            # Display progress
            image_count += 1
            sys.stdout.write('\r')
            sys.stdout.write('Calculating image ' + str(image_count) + '/' + str(len(image_files)))
            sys.stdout.flush()

            # Actually evaluate the image
            completed[i], iters[i] = process_image(i, box_evaluator)

    # Save results
    if settings.save_results:
        hickle.dump((completed, iters, settings),
                    open('experiments/' + settings.experiment_title + str() + '_' + str(datetime.now()), 'w'))

    # Plot a situate-style graph
    if settings.show_graph:
        successful_by_iteration = np.zeros([settings.max_iters])
        for i in xrange(len(iters)):
            if completed[i].reshape([-1])[0]:
                successful_by_iteration[iters[i]:settings.max_iters] += 1

        plt.plot(successful_by_iteration)
        plt.show()

    # Display result matrix
    if settings.print_results:
        print 'Result matrix:'
        print np.sum(completed, axis=0)
        for obj_i in xrange(len(settings.objects)):
            print settings.objects[obj_i].name + ' results:'
            print np.sum(completed, axis=tuple(i for i in xrange(len(settings.objects) + 1) if i != obj_i + 1))

    return ExperimentResults(completed, iters)


def process_image(image_index, box_evaluator):
    """Evaluate the given image."""

    # Create the workspace
    workspace = Workspace(box_evaluator.get_image_files()[image_index])

    # Show initial workspace
    if settings.show_gui:
        workspace.draw(0)

    # Update box evaluator
    box_evaluator.workspace = workspace
    box_evaluator.next_image(image_index)

    # Step through each of the boxes
    while True:
        # Check if the situation detection is completed
        continue_searching = filter(box_evaluator.continue_searching, settings.objects)
        if not continue_searching:
            break
        workspace.iters += 1
        if workspace.iters > settings.max_iters:
            break

        # Randomly choose an object type to look for
        weight_sum = float(sum(obj.weight for obj in continue_searching))
        obj = np.random.choice(continue_searching, p=[obj.weight / weight_sum for obj in continue_searching])

        # Choose which box to evaluate
        general_box = box_evaluator.next_box(obj)
        max_score = 0

        # Evaluate the proposed box
        for cls in obj.classes:

            box, score = box_evaluator.get_box_score(obj, cls)
            max_score = max(score, max_score)

            # If it's the highest-scoring box so far
            if score > workspace.scores[obj]:
                workspace.detections_boxes[obj] = box
                workspace.detections_data[obj] = workspace.label.box_to_data(box)
                workspace.scores[obj] = score

                # Update the box evaluator with the detection
                box_evaluator.workspace_update(obj)

        # Show the workspace
        if settings.show_gui and workspace.iters % settings.show_iter_mod == 0:
            workspace.draw(1, query={'obj': obj, 'box': general_box, 'score': max_score})

    # Determine the results
    results = []
    for obj in settings.objects:
        if obj not in workspace.detections_boxes:
            results.append(2)
        elif IOU(workspace.detections_boxes[obj], workspace.label.boxes[obj.name]) < .5:
            results.append(1)
        else:
            results.append(0)

    completed = np.zeros([3] * len(settings.objects))
    completed[tuple(results)] = 1

    # Show the final workspace
    if settings.show_gui:
        workspace.draw(2)

    return completed, workspace.iters
