from abc import *

import scipy.io

from conditional_distributions import *
from logistic_regression import *


class BoxEvaluator(object):
    __metaclass__ = ABCMeta
    workspace = None

    @abstractmethod
    def get_image_files(self):
        """Returns a list of image filenames."""
        raise NotImplementedError

    @abstractmethod
    def train(self, train_set):
        """Performs any training needed on the training set of images. The training set is provided as an array of image indices."""
        raise NotImplementedError

    @abstractmethod
    def next_image(self, image_index):
        """Performs any actions needed when moving to the next image."""
        raise NotImplementedError

    @abstractmethod
    def continue_searching(self, obj):
        """Returns whether to continue searching for the given object."""
        raise NotImplementedError

    @abstractmethod
    def next_box(self, obj):
        """Samples and returns a box for the given object."""
        raise NotImplementedError

    @abstractmethod
    def get_box_score(self, obj, cls):
        """Returns the current exact box and score for a given object and class."""
        raise NotImplementedError

    @abstractmethod
    def workspace_update(self, obj):
        """Performs any actions needed when adding an object to the workspace."""
        raise NotImplementedError


class IOUOracle(BoxEvaluator):
    def __init__(self):
        mat_data = scipy.io.loadmat('data/' + settings.situation + '.mat')
        self.image_files = [i[0][0] for i in mat_data['im_names']]

    def get_image_files(self):
        return self.image_files

    def train(self, train_set):
        # Compute conditional distributions from the training data
        label_files = [self.image_files[i].replace('.jpg', '.labl') for i in train_set]
        if settings.use_prior_dists or settings.use_posterior_dists:
            self.conditional_dists = ConditionalDistributions(label_files)
        else:
            self.conditional_dists = None

    def next_image(self, image_index):
        pass

    def continue_searching(self, obj):
        return self.workspace.scores[obj] <= obj.final_threshold \
               and any(self.workspace.scores[obj] < .5 for obj in settings.objects)

    def next_box(self, obj):
        if settings.use_prior_dists or (settings.use_posterior_dists and self.workspace.detections_data):
            # Sample from the conditional distributions
            condition_on = self.workspace.detections_data if settings.use_posterior_dists else None
            sampled_data = self.conditional_dists.sample(obj, condition_on, settings.temperature)
            self.box = self.workspace.label.data_to_box(sampled_data)
            while not self.workspace.label.is_inside_image(self.box):
                sampled_data = self.conditional_dists.sample(obj, condition_on, settings.temperature)
                self.box = self.workspace.label.data_to_box(sampled_data)
            if settings.show_gui and settings.show_conditional_dists_overlay:
                self.workspace.overlay_dist = self.conditional_dists.get_mean_cov(obj, self.workspace.detections_data)
        else:
            # Sample uniformly from the image
            possible_box = np.random.uniform(size=4)
            possible_box[2:] -= possible_box[:2]
            while any(possible_box < 0):
                possible_box = np.random.uniform(size=4)
                possible_box[2:] -= possible_box[:2]
            self.box = possible_box * np.hstack([self.workspace.label.image_size, self.workspace.label.image_size])
        return self.box

    def get_box_score(self, obj, cls):
        return self.box, IOU(self.box, self.workspace.label.boxes[obj.name])

    def workspace_update(self, obj):
        pass


class FasterRCNN(BoxEvaluator):
    def __init__(self):
        # Load data from the Faster-RCNN results mat file
        mat_data = scipy.io.loadmat('data/' + settings.situation + '.mat')
        self.image_files = [i[0][0] for i in mat_data['im_names']]
        self.all_aboxes = mat_data['results'][0]
        self.all_boxes = mat_data['results'][1]
        self.all_scores = mat_data['results'][2]

        # Convert boxes to XYWH format
        for i in xrange(len(self.image_files)):
            self.all_aboxes[i][:, 2:4] -= self.all_aboxes[i][:, :2]
            for cls in settings.all_classes():
                self.all_boxes[i][:, 4 * cls + 2:4 * cls + 4] -= self.all_boxes[i][:, 4 * cls:4 * cls + 2]

    def get_image_files(self):
        return self.image_files

    def train(self, train_set):
        # Compute conditional distributions from the training data
        label_files = [self.image_files[i].replace('.jpg', '.labl') for i in train_set]
        if settings.use_prior_dists or settings.use_posterior_dists:
            self.conditional_dists = ConditionalDistributions(label_files)
        else:
            self.conditional_dists = None

        # Compute a logistic regression model from the training_data
        if settings.use_logistic_regression:
            self.logistic_models = LogisticModels(label_files, self.all_aboxes[train_set], self.all_boxes[train_set],
                                                  self.all_scores[train_set], self.conditional_dists)
        else:
            self.logistic_models = None

    def next_image(self, image_index):
        # Compute data specific to this image
        self.aboxes = self.all_aboxes[image_index]
        self.boxes = self.all_boxes[image_index]
        self.scores = self.all_scores[image_index]
        self.data = np.array([self.workspace.label.box_to_data(box) for box in self.aboxes])

        # Define the initial ordering of the boxes
        self.external_scores = {}
        self.ordering = {}
        self.checked = {}
        for obj in settings.objects:

            self.external_scores[obj] = np.log(self.aboxes[:, 4])
            if settings.use_prior_dists:
                self.external_scores[obj] += self.conditional_dists.logpdf(obj, self.data) \
                                             * settings.prior_external_weight

            self.external_scores[obj] -= np.mean(self.external_scores[obj], axis=0)
            self.ordering[obj] = np.argsort(self.external_scores[obj]).tolist()
            self.checked[obj] = np.zeros([len(self.external_scores[obj])])

    def continue_searching(self, obj):
        return self.workspace.scores[obj] < obj.final_threshold and self.ordering[obj]

    def next_box(self, obj):
        self.box_index = self.ordering[obj][0]
        self.external_score = self.external_scores[obj][self.box_index]

        # Remove this box from the ordering
        self.external_scores[obj][self.box_index] = 0
        self.ordering[obj] = self.ordering[obj][1:]
        self.checked[obj][self.box_index] = True

        if settings.show_gui and settings.show_conditional_dists_overlay:
            self.workspace.overlay_dist = self.conditional_dists.get_mean_cov(obj, self.workspace.detections_data)

        return self.aboxes[self.box_index]

    def get_box_score(self, obj, cls):
        box = self.boxes[self.box_index, cls * 4:(cls + 1) * 4]
        score = self.scores[self.box_index, cls]

        # Modify the score according to the external support
        if settings.use_external_support:
            if settings.use_logistic_regression:
                score = self.logistic_models.eval(cls, self.workspace.detections_data, self.aboxes[self.box_index, 4],
                                                  self.data[self.box_index], score)
            else:
                score = sigmoid(np.log(score) + self.external_score * settings.external_support_weight)

        return box, score

    def workspace_update(self, obj):
        # Update the ordering by the new conditional distributions
        if settings.use_posterior_dists:
            for obj2 in settings.objects:
                if obj != obj2:
                    self.external_scores[obj2] = np.log(self.aboxes[:, 4]) \
                                                 + self.conditional_dists.logpdf(obj2, self.data,
                                                                                 self.workspace.detections_data) * settings.posterior_external_weight
                    self.external_scores[obj2] -= np.mean(self.external_scores[obj2], axis=0)
                    self.ordering[obj2] = np.argsort(self.external_scores[obj2])
                    self.ordering[obj2] = [x for x in self.ordering[obj2] if not self.checked[obj2][x]]
