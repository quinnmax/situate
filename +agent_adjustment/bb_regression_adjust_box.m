function [ adjusted_box_r0rfc0cf, delta_xywh ] = bb_regression_adjust_box( weight_vects, box_in_r0rfc0cf, image, cnn_features )

    % [ adjusted_box_r0rfc0cf, delta_xywh ] = bb_regression_adjust_box( weight_vects, box_in_r0rfc0cf, image, cnn_features );
    %
    % uses 4096 element output from vgg16
    % weight_vects: should be for [delta_x, delta_y, delta_w, delta_h] (ie, 4097x4)
    % adjusted_box_r0rfc0cf: the adjusted bounding box is returned in r0rfc0cf format
    % delta_xywh: the delta used to generate the adjusted box
    %
    % if cnn features are provided, these will be used. otherwise, they'll be
    % extracted from the input image
    
    % get starting stats
    r0 = box_in_r0rfc0cf(1);
    rf = box_in_r0rfc0cf(2);
    c0 = box_in_r0rfc0cf(3);
    cf = box_in_r0rfc0cf(4);
    w = cf - c0  +  1;
    h = rf - r0  +  1;
    x = c0 + w/2 - .5;
    y = r0 + h/2 - .5;
   
    % get cnn features, if necessary
    if ~exist('cnn_features','var') || isempty(cnn_features)
        if mean(image(:)) < 1, image = image*255; end
        cnn_features = cnn.cnn_process( image(r0:rf,c0:cf,:))';
    end
    
    % predict the deltas
    delta_xywh = [1 cnn_features] * weight_vects;
    delta_x = delta_xywh(1);
    delta_y = delta_xywh(2);
    delta_w = delta_xywh(3);
    delta_h = delta_xywh(4);
    
    if any( isnan( delta_xywh ) )
        error('getting NaNs from box_adjust');
    end
    
    % predict the new box values
    adjusted_x = x + delta_x * w;
    adjusted_y = y + delta_y * h;
    adjusted_w = w * exp(delta_w);
    adjusted_h = h * exp(delta_h);
    
    r0_adjusted = round( adjusted_y  - adjusted_h/2 + .5 );
    rf_adjusted = round( r0_adjusted + adjusted_h - 1);
    c0_adjusted = round( adjusted_x  - adjusted_w/2 + .5 );
    cf_adjusted = round( c0_adjusted + adjusted_w - 1);
    
    % correct for edge effects, update based on changes
    r0_adjusted = max( r0_adjusted, 1 );
    c0_adjusted = max( c0_adjusted, 1 );
    
    if ~isempty(image)
        rf_adjusted = min( rf_adjusted, size(image,1) );
        cf_adjusted = min( cf_adjusted, size(image,2) );
    else
        warning('image was empty. need it to make sure boxes are in bounds.');
    end
    
    adjusted_box_r0rfc0cf = [r0_adjusted rf_adjusted c0_adjusted cf_adjusted];
   
end