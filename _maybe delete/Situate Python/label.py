import numpy as np


class Label(object):
    def __init__(self, label_file):
        # Split the file by the | character
        file_parts = open(label_file).read().split('|')
        assert len(file_parts) % 5 == 3
        num_objects = (len(file_parts) - 3) / 5
        file_parts = [float(x) for x in file_parts[:-num_objects]] + file_parts[-num_objects:]

        # Convert the labels we care about to object types
        possible_labels = {
            'Dog': ['dog back', 'dog front', 'dog my-left', 'dog my-right'],
            'Walker': ['dog-walker back', 'dog-walker front', 'dog-walker my-left', 'dog-walker my-right'],
            'Leash': ['leash-/', 'leash-\\']}
        to_object = {v: k for k, l in possible_labels.items() for v in l}

        # Store useful image size variables
        self.image_size = np.array(file_parts[:2])
        self.num_pixels = self.image_size[0] * self.image_size[1]

        # Create XYWH boxes and normalized XcYcAsAr data for each object
        self.boxes = {}
        self.data = {}
        for i in xrange(num_objects):
            label = file_parts[-num_objects + i]
            if label in to_object:
                obj = to_object[label]
                self.boxes[obj] = np.array(file_parts[3 + 4 * i: 3 + 4 * (i + 1)])
                self.data[obj] = self.box_to_data(self.boxes[obj])

    def box_to_data(self, box):
        """Converts a box in XYWH format to data in XcYcAsAr format."""
        xc = (box[0] + box[2] / 2 - self.image_size[0] / 2) / np.sqrt(self.num_pixels)
        yc = (box[1] + box[3] / 2 - self.image_size[1] / 2) / np.sqrt(self.num_pixels)
        asR = np.log(box[2] / box[3])
        arR = np.log(box[2] * box[3] / self.num_pixels)
        return np.array([xc, yc, asR, arR])

    def data_to_box(self, data):
        """Converts data in XcYcAsAr format to a box in XYWH format."""
        w = np.sqrt(np.exp(data[3] + data[2]) * self.num_pixels)
        h = np.sqrt(np.exp(data[3] - data[2]) * self.num_pixels)
        x = data[0] * np.sqrt(self.num_pixels) - w / 2 + self.image_size[0] / 2
        y = data[1] * np.sqrt(self.num_pixels) - h / 2 + self.image_size[1] / 2
        return np.array([x, y, w, h])

    def is_inside_image(self, box):
        """Returns whether the given box is comlpetely contained by the image."""
        return all(box[:2] >= 0) and all(box[:2] + box[2:] <= self.image_size)
