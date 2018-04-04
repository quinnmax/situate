function data = cnn_process( image, image_size, layer_in )
% data = cnn_process( image, image_size, layer_in )
%
% layer 18 is the last layer before classification
% layer 15 is the last layer where there's still a spatial layout

    if ~exist('matconvnet/imagenet-vgg-f.mat','file')
        cnn.matconvnet_setup();
    end

    persistent net;
    persistent layer;
    
    if ~exist('net', 'var') ...
    || isa(net, 'double') ...
    || ( exist('layer','var') &&  exist( 'layer_in', 'var') && ~isequal(layer_in,layer) ) ...
    || ( exist('layer','var') && ~exist( 'layer_in', 'var') &&  layer ~= 18 )
        run('vl_setupnn');
        net = vl_simplenn_tidy(load('matconvnet/imagenet-vgg-f.mat'));
        if exist('layer_in','var') && ~isempty(layer_in)
            layer = layer_in;
        else
            layer = 18;
        end
        net.layers = net.layers(1:layer);
    end
    
    if ~exist('image_size','var') || isempty(image_size)
        image_size = net.meta.normalization.imageSize(1:2);
    end
    image = imresize(single(image), image_size);
    image = bsxfun(@minus, image, imresize(net.meta.normalization.averageImage, image_size));

%     try
%         image = gpuArray(image);
%     catch 
%     end
    
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
