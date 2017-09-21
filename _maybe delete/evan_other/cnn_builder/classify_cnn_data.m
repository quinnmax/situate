function predictions = classify_cnn_data(filenames,net)
%LOAD_CNN_DATA Converts an array of files to a matrix of feature data.
    % global net 
    here = pwd;
    % cd '/stash/mm-group/evan/sequencer/cnn/matconvnet-1.0-beta20'
    % net = load('crop_net.mat');

    disp('Starting MatConvNet');
        % Must be called for MatConvNet to work
    run '/stash/mm-group/evan/sequencer/cnn/matconvnet-1.0-beta20matlab/vl_setupnn'

    disp('Processing images');
    predictions = cell2mat(map(filenames, @(x) cnn_classify(imread(x),net))')';
    cd (here);

end