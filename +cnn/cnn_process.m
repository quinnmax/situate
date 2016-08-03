function data = cnn_process( image, image_size )
%CNN_PROCESS Uses a pre-trained CNN to extract features from an image. 
    persistent net layer;
    if ~exist('net', 'var') || isa(net, 'double')
        % Must be called for MatConvNet to work
        run matconvnet/matlab/vl_setupnn
        net = vl_simplenn_tidy(load('+cnn/imagenet-vgg-f.mat'));
        layer = 18;
        net.layers = net.layers(1:layer);
        net = vl_simplenn_move(net, 'gpu');
%         net = dagnn.DagNN.loadobj(load('+cnn/imagenet-resnet-152-dag.mat')) ;
%         net.mode = 'test' ;
%         net.conserveMemory = false;
%         layer = 502;
    end
    
    if nargin < 2
        image_size = net.meta.normalization.imageSize(1:2);
    end
    image = imresize(single(image), image_size);
    image = bsxfun(@minus, image, imresize(net.meta.normalization.averageImage, image_size));
    image = gpuArray(image);
    
    if isa(net, 'dagnn.DagNN')
        % run the CNN
        net.eval({'data', image});
        
        data = gather(net.vars(layer).value);
    else
        % run the CNN
        res = vl_simplenn(net, image);
        
        data = gather(res(layer).x);
    end
    
    if nargin < 2
        data = data(:);
    end
end
