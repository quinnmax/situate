from frozendict import frozendict
from scipy.stats import multivariate_normal

from label import *
from settings import *
from util import *


class ConditionalDistributions(object):
    def __init__(self, label_files):

        labels = [Label(f) for f in label_files]
        data = [np.hstack([l.data[obj.name] for obj in settings.objects]) for l in labels]

        joint_mean = np.mean(data, axis=0)
        joint_cov = np.cov(data, rowvar=0)

        # Helper function to subdivide a matrix
        def sub_mean_cov(keep_inds):
            keep_inds = np.repeat(keep_inds, 4)
            return joint_mean[keep_inds], joint_cov[keep_inds, :][:, keep_inds]

        # Precompute things (to improve speed)
        self.precomputed = {}
        # Iterate though all possibilities
        for obj in settings.objects:
            could_condition_on = list(settings.objects)
            could_condition_on.remove(obj)
            for detections in powerset(could_condition_on):

                # If there are no detections, don't do any conditioning
                if not detections:
                    self.precomputed[(obj, detections)] = sub_mean_cov([o == obj for o in settings.objects])
                else:
                    # Now the math
                    # Divide the matrix into sections for the objects and detections
                    objects_ind = [o is obj for o in settings.objects]
                    detections_ind = [o in detections for o in settings.objects]
                    objects_mean, objects_cov = sub_mean_cov(objects_ind)
                    detections_mean, detections_cov = sub_mean_cov(detections_ind)

                    # Other useful variables
                    combined_cov = joint_cov[np.repeat(objects_ind, 4), :][:, np.repeat(detections_ind, 4)]
                    detections_cov_inverse = np.linalg.inv(detections_cov)
                    cc_dci = np.dot(combined_cov, detections_cov_inverse)

                    # Covariance doesn't depend on the detections
                    cov = objects_cov - np.dot(cc_dci, combined_cov.T)

                    self.precomputed[(obj, detections)] = (objects_mean, detections_mean, cc_dci, cov)

    def get_mean_cov(self, obj, detections, temperature=settings.temperature):
        """Get the mean and covariance of the conditional MVN for a given object type and given detections."""

        detections = {k: v for k, v in detections.items() if k is not obj}

        if not detections:
            return self.precomputed[(obj, frozenset(detections))]

        (objects_mean, detections_mean, cc_dci, cov) = self.precomputed[(obj, frozenset(detections))]
        detections_values = np.hstack([detections[o] for o in settings.objects if o in detections])

        mean = objects_mean + np.dot(cc_dci, detections_values - detections_mean)
        return mean, cov * temperature

    def logpdf(self, obj, obj_data, detections=frozendict(), temperature=settings.temperature):
        """Get the log probability density of an object at a given position, with given detections."""
        mean, cov = self.get_mean_cov(obj, detections, temperature)
        return multivariate_normal.logpdf(obj_data, mean, cov)

    def pdf(self, obj, obj_data, detections=frozendict(), temperature=settings.temperature):
        """Get the probability density of an object at a given position, with given detections."""
        mean, cov = self.get_mean_cov(obj, detections, temperature)
        return multivariate_normal.pdf(obj_data, mean, cov)

    # Presampling many values at once improves speed - about a 4x speedup
    presampled = {}

    def sample(self, obj, detections=frozendict(), temperature=settings.temperature):
        """Sample an object of a given type, with given detections."""
        detections = frozendict({k: tuple(v) for k, v in detections.items()})
        if (obj, detections) not in self.presampled or not self.presampled[(obj, detections)]:
            mean, cov = self.get_mean_cov(obj, detections, temperature)
            self.presampled[(obj, detections)] = list(np.random.multivariate_normal(mean, cov, 100))
        return self.presampled[(obj, detections)].pop()
