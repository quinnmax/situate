function score = score_subimage_finetuned( image, subimage_xywh, model_ind, d )
    image = floor(256 * image( ...
        subimage_xywh(2):(subimage_xywh(2)+subimage_xywh(4)-1), ...
        subimage_xywh(1):(subimage_xywh(1)+subimage_xywh(3)-1), :));
    
    net = d(model_ind).learned_stuff.finetuned_cnn_models{model_ind};
    
    image_size = net.meta.normalization.imageSize(1:2);
    image = imresize(single(image), image_size);
    image = bsxfun(@minus, image, imresize(net.meta.normalization.averageImage, image_size));
    
    res = vl_simplenn(net, image);
    data = squeeze(gather(res(end).x));
    score = data(1);
end

