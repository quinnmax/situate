function data = cnn_process( image, image_size, layer_in )
% data = cnn_process( image, image_size, layer_in )
% image
%CNN_PROCESS Uses a pre-trained CNN to extract features from an image. 
    persistent net layer;
    if ~exist('net', 'var') || isa(net, 'double') || (exist('layer','var') && exist('layer_in','var') && ~isequal(layer_in,layer))
        % Must be called for MatConvNet to work
        % run matconvnet/matlab/vl_setupnn
        run vl_setupnn % matconvnet/matlab is in path. local path was messing it up for other scripts
        net = vl_simplenn_tidy(load('+cnn/imagenet-vgg-f.mat'));
        if exist('layer_in','var') && ~isempty(layer_in)
            layer = layer_in;
        else
            layer = 18;
        end
        net.layers = net.layers(1:layer);
        try
            net = vl_simplenn_move(net, 'gpu');
        catch
        end
%         net = dagnn.DagNN.loadobj(load('+cnn/imagenet-resnet-152-dag.mat')) ;
%         net.mode = 'test' ;
%         net.conserveMemory = false;
%         layer = 502;
    end
    
    if ~exist('image_size','var') || isempty(image_size)
        image_size = net.meta.normalization.imageSize(1:2);
    end
    image = imresize(single(image), image_size);
    image = bsxfun(@minus, image, imresize(net.meta.normalization.averageImage, image_size));
    try
        image = gpuArray(image);
    catch 
    end
    
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
