import matplotlib.pyplot as plt
import scipy.ndimage
from scipy.stats import multivariate_normal

from label import *
from settings import *
from util import *


class Workspace(object):
    def __init__(self, image_file):
        self.image_file = image_file
        self.label = Label(image_file.replace('.jpg', '.labl'))
        self.iters = 0
        self.detections_boxes = {}
        self.detections_data = {}
        self.scores = {obj: obj.checkin_threshold for obj in settings.objects}

        # Load the image only if it'll actually be used
        if settings.show_gui:
            self.image = scipy.ndimage.imread(image_file)

        self.overlay_dist = None

    def draw(self, state, query=None):
        """Draws the workspace to the screen. State 0 is initial workspace, state 1 is in-progress, state 2 is final workspace."""

        # Show the image
        plt.imshow(self.image)

        # Show the overlay distribution
        if state is 1 and self.overlay_dist is not None:
            mean = self.overlay_dist[0][:2]
            cov = self.overlay_dist[1][:2, :2]
            mean = mean * np.sqrt(self.label.num_pixels) + self.label.image_size / 2
            cov *= self.label.num_pixels
            overlay = multivariate_normal.pdf(
                np.array(np.meshgrid(np.arange(self.label.image_size[0]), np.arange(self.label.image_size[1])))
                    .reshape(2, -1).T, mean, cov)
            overlay /= overlay.max()
            plt.imshow(overlay.reshape(self.label.image_size[[1, 0]]), alpha=.2)

        # Set the figure title
        if state is 0:
            plt.title('Initial workspace')
        elif state is 1:
            if query is not None:
                plt.title(str(self.iters) + ' iterations - searching for ' + query['obj'].name)
            else:
                plt.title(str(self.iters) + ' iterations')
        elif state is 2:
            plt.title('Final workspace after ' + str(self.iters) + ' iterations')
        else:
            raise Exception('Invalid state:' + str(state))

        # Draw the proposed box
        if query is not None:
            self._draw_rectangle(query['box'], [0, 0, 1])
            plt.text(query['box'][0], query['box'][1], query['obj'].name)

        # Draw all the detected boxes
        for obj in self.detections_boxes:
            self._draw_rectangle(self.detections_boxes[obj], [1, 0, 0])
            plt.text(self.detections_boxes[obj][0], self.detections_boxes[obj][1], obj.name)
            plt.text(self.detections_boxes[obj][0], self.detections_boxes[obj][1] + 25,
                     ' IOU:' + str(IOU(self.detections_boxes[obj], self.label.boxes[obj.name])))

        plt.show()

    @staticmethod
    def _draw_rectangle(box, color):
        plt.gca().add_patch(plt.Rectangle((box[0], box[1]), box[2], box[3], color=color, fill=False))
