function data = load_cnn_data( filenames )
%LOAD_CNN_DATA Converts an array of files to a matrix of feature data.
    global net layer;
    here = pwd;
    cd '/stash/mm-group/evan/sequencer/cnn/matconvnet-1.0-beta20'
    
    if 0==0

        disp('Starting MatConvNet');
        % Must be called for MatConvNet to work
        run matlab/vl_setupnn
        net = vl_simplenn_tidy(load('imagenet-vgg-f.mat'));
        layer = 18;
        net.layers = net.layers(1:layer);
    end
    disp('Processing images');
    data = cell2mat(map(filenames, @(x) cnn_process(imread(x)))')';
    cd (here);

end

