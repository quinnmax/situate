function best = cnn_classify(image,net)
%CNN_PROCESS Uses a pre-trained CNN to extract features from an image. 
    % global net;

    % load and preprocess an image
    im_ = single(image) ; % note: 0-255 range
    im_ = imresize(im_, net.meta.normalization.imageSize(1:2)) ;
    im_ = bsxfun(@minus, im_, net.meta.normalization.averageImage) ;

    % run the CNN
    res = vl_simplenn(net, im_) ;

    scores = squeeze(gather(res(end).x)) ;
	[bestScore, best] = max(scores) ;
end
