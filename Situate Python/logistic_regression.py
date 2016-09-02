from sklearn.linear_model import LogisticRegression

from label import *
from settings import *
from util import *


class LogisticModels(object):
    def __init__(self, label_files, aboxes, boxes, scores, conditional_dists):

        """
        For Faster-RCNN, the logistic regression has three input variables:
            The initial score proposed by the RPN
            The internal score output by Fast-RCNN
            The probability density given by the MVN

        These are called:
            Prior
            Internal
            External
        """

        self._all_models = {}
        self._conditional_dists = conditional_dists

        # Step through each of the objects
        for obj in settings.objects:
            # Step through each of the possible sets to condition on
            could_condition_on = list(settings.objects)
            could_condition_on.remove(obj)
            for condition_on in powerset(could_condition_on):
                # Step through each of the possible object classes
                for cls in obj.classes:

                    prior_list = []
                    internal_list = []
                    external_list = []
                    iou_list = []

                    # Step through each of the images
                    for i in xrange(len(label_files)):
                        label = Label(label_files[i])

                        # Assume perfect detections
                        detections = {o: label.data[o.name] for o in condition_on}

                        # Compute the actual values
                        data = label.box_to_data(boxes[i][:, cls * 4:(cls + 1) * 4].T).T
                        iou_list += [IOU(box, label.boxes[obj.name]) for box in boxes[i][:, cls * 4:(cls + 1) * 4]]

                        prior = np.log(aboxes[i][:, 4])
                        internal = np.log(scores[i][:, cls])
                        external = conditional_dists.logpdf({obj: np.array(data)}, detections)

                        prior_list += list(prior)
                        internal_list += list(internal)
                        external_list += list(external)

                    # Process data
                    input_data = np.array([prior_list, internal_list, external_list]).T
                    iou_list = np.array(iou_list)
                    zeros = iou_list < 0

                    input_data = input_data[~zeros]
                    iou_list = iou_list[~zeros]

                    # Perform logistic regression
                    # model = LogisticRegression(class_weight='balanced')
                    # model = LogisticRegression()
                    model = LogisticRegression(class_weight={1: 1, 0: 1000})
                    model.fit(input_data, iou_list >= .5)

                    # Save the model
                    self._all_models[(cls, condition_on)] = model

                    # print cls, [o.name for o in condition_on]
                    # print model.coef_, len(iou_list)
                    #
                    # probs = model.predict_proba(input_data)
                    #
                    # results = np.zeros([2, 2], dtype=int)
                    # for iou, prob in zip(iou_list, probs[:, 1]):
                    #     results[prob < .5, iou > .5] += 1
                    # print results
                    #
                    # fig, ax = plt.subplots()
                    # ax.scatter(iou_list, probs[:, 1])
                    # plt.plot([.5, .5], [0, 1])
                    # plt.plot([0, 1], [.5, .5])
                    # plt.show()

                    # input_data = input_data[:1000]
                    # iou_list = iou_list[:1000]
                    #
                    # fig = plt.figure()
                    # ax = fig.add_subplot(111, projection='3d')
                    # ax.scatter(input_data[iou_list < .5, 0], input_data[iou_list < .5, 1], input_data[iou_list < .5, 2],
                    #            c='b')
                    # ax.scatter(input_data[iou_list >= .5, 0], input_data[iou_list >= .5, 1],
                    #            input_data[iou_list >= .5, 2], c='r')
                    # plt.show()

    def eval(self, cls, detections, prior, box_data, score):
        # Set variables
        obj = settings.cls_to_obj(cls)
        internal = np.log(score)
        external = self._conditional_dists.logpdf({obj: box_data}, detections)

        # Choose the correct model
        condition_on = list(detections.keys())
        if obj in condition_on:
            condition_on.remove(obj)
        model = self._all_models[(cls, frozenset(condition_on))]

        # Evaluate the box
        return model.predict_proba(np.array([[prior, internal, external]]))[0][1]
