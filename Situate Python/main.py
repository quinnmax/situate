from experiment import run_experiment
from settings import settings

# -----------------------------------------------------------

'General GUI settings'

settings.experiment_title = 'test'

settings.show_gui = True
settings.show_iter_mod = 100
settings.show_conditional_dists_overlay = True
settings.show_graph = True
settings.print_results = True

# -----------------------------------------------------------

'Basic IOU Oracle settings'

settings.box_evaluator = 'IOUOracle'

settings.use_prior_dists = True
settings.use_posterior_dists = True

settings.temperature = 1.5

settings.def_object('Walker', checkin_threshold=.1, final_threshold=.65)
settings.def_object('Dog', checkin_threshold=.1, final_threshold=.65)
settings.def_object('Leash', checkin_threshold=.1, final_threshold=.65)

# -----------------------------------------------------------

'Basic Faster-RCNN settings'

# settings.box_evaluator = 'FasterRCNN'
#
# settings.use_external_support = True
# settings.external_support_weight = 2
#
# settings.use_prior_dists = True
# settings.use_posterior_dists = True
#
# settings.prior_external_weight = .1
# settings.posterior_external_weight = .2
#
# settings.def_object('Walker', classes=[14])
# settings.def_object('Dog', classes=[11, 7, 9, 16], weight=1e9)  # These classes are (in order): dog, cat, cow, sheep

# -----------------------------------------------------------

'Run a single 10-fold crossvalidated experiment'

run_experiment()

# -----------------------------------------------------------

'An example of a more complicated experiment on temperature'

# num_successful = np.zeros([10, 3])
# median_iters = np.zeros([10, 3])
#
# for i in xrange(10):
#     print 'Temperature:', .25 + i * .25
#     for j in xrange(3):
#         settings.temperature = .25 + i * .25
#         results = run_experiment()
#
#         num_successful[i, j] = results.num_successful()
#         median_iters[i, j] = np.median(results.iters[results.successful])
#
# print num_successful
# print median_iters

# -----------------------------------------------------------

'An example of a more complicated experiment on thresholds'

# num_successful = np.zeros([6, 6])
# median_iters = np.zeros([6, 6])
#
# for i in xrange(6):
#     for j in xrange(6):
#         for obj in settings.objects:
#             obj.checkin_threshold = i * .05
#             obj.final_threshold = .5 + j * .05
#
#         results = run_experiment()
#
#         num_successful[i, j] = results.num_successful()
#         median_iters[i, j] = results.median_iters()
#
# print num_successful
# print median_iters
