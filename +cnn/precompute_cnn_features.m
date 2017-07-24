function data = precompute_cnn_features( image, resolution )
%PRECOMPUTE_CNN_FEATURES Precomputes the convolutional layers of a CNN on
%a full image.
    persistent net layer;
    if ~exist('net', 'var') || isa(net, 'double')
        run matconvnet/matlab/vl_setupnn
        net = vl_simplenn_tidy(load('+cnn/imagenet-vgg-f.mat'));
        layer = 13;
        net.layers = net.layers(1:layer);
    end
    
    im_ = imresize(single(image), resolution*16);
    im_ = bsxfun(@minus, im_, imresize(net.meta.normalization.averageImage, resolution*16));
    
    if isa(net, 'dagnn.DagNN')
        % run the CNN
        net.eval({'data', im_});
        
        scores = gather(net.vars(layer).value);
        data = scores;
    else
        % run the CNN
        res = vl_simplenn(net, im_);
        
        data = res(layer).x;
    end
end
