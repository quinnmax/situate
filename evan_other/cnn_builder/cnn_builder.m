
run(fullfile('/u/eroche/matlab/cnn/matconvnet-1.0-beta20', 'matlab', 'vl_setupnn.m')) ;

opts.expDir = '/stash/mm-group/evan/crop_learn/part3'

opts.batchSize = 50 ;

opts.learningRate = 0.01 ;

opts.numEpochs = 90 ;

% opts.learningRate = logspace(-4, -5.5, 300) ;
% opts.numEpochs = numel(opts.learningRate) ;

opts.continue = true ;

opts.backPropDepth = 3; %just retrain the last real layer (1 is softmax)
% opts.backPropDepth = 9; %just retrain the fully connected layers
% opts.backPropDepth = +inf; %retrain all layers [default]

net = cnn_init();

% if exist(opts.imdbPath, 'file')
%   imdb = load(opts.imdbPath) ;
% else
  imdb = cnn_data(net.meta.normalization.averageImage);
  % mkdir(opts.expDir) ;
  % save(opts.imdbPath, '-struct', 'imdb') ;
% end


[net, info] = cnn_train(net, imdb, @getBatch, opts, 'val', find(imdb.images.set == 2)) ;

