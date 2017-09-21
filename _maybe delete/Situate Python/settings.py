class Settings(object):
    experiment_title = 'untitled'            # The title of the experiment

    show_gui = True                          # Whether to show the GUI or not
    show_iter_mod = 1                        # Increase this to skip over many iterations at once
    show_conditional_dists_overlay = False   # Whether to show the location distribution over the GUI
    show_graph = True                        # Whether to show a successes-by-iteration graph
    print_results = True                     # Whether to print the number of successes by object category

    save_results = False                     # Whether to save the results of the experiment to the disk

    situation = 'dogwalking'          # The mat file in /data/ to load image filenames from

    box_evaluator = 'IOUOracle'       # The method to use to evaluate boxes, currently supports IOUOracle and FasterRCNN

    max_iters = 1000                  # The maximum number of iterations to run

    use_prior_dists = False           # Whether to use prior distributions to generate boxes
    use_posterior_dists = False       # Whether to use conditional distributions to generate boxes

    temperature = 1                   # The factor by which to multiply the covariance of the gaussian

    # Relevant for Faster-RCNN only
    use_external_support = False      # Whether to use external support to help score boxes
    external_support_weight = 0       # The weight of the entire external support
    prior_external_weight = 0         # The weight of the prior MVN probability density
    posterior_external_weight = 0     # The weight of the conditional MVN probability density
    use_logistic_regression = False   # Whether to use logistic regression to choose the above weights

    #
    # THE ABOVE SETTINGS ARE THE PARAMETERS OF THE EXPERIMENT
    # -----------------------------------------------------------------------------------------------------------
    #

    # The list of all the defined objects
    objects = []

    class _Object(object):
        def __init__(self, name, classes=None, checkin_threshold=0, final_threshold=1, weight=1):
            self.name = name
            self.classes = classes if classes is not None else [len(settings.objects)]
            self.checkin_threshold = checkin_threshold
            self.final_threshold = final_threshold
            self.weight = weight

    def all_classes(self):
        """Returns the set of all classes that some object corresponds to."""
        return frozenset(cls for obj in self.objects for cls in obj.classes)

    def cls_to_obj(self, cls):
        """Gets the object that corresponds to the given class."""
        for obj in self.objects:
            if cls in obj.classes:
                return obj
        return None

    def def_object(self, name, **kwargs):
        """Defines an object. The supported keyword arguments are: classes, checkin_threshold, final_threshold, weight"""
        self.objects.append(self._Object(name, **kwargs))


settings = Settings()
