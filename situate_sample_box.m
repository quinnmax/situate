
function [d,box_r0rfc0cf,w,h,rc,cc] = situate_sample_box( d, parameters_struct )



%   function [d,box,w,h,rc,cc] = situate_sample_box( d );
% 
%   d is a structure that contain information about how to generate a
%   bounding box, both location and box shape/size. see the switch
%   statements below to see the supported options and expected fields for
%   each option.
%
%   the distribution structure d might be modified, so is returned
%   the box is in [r0 rf c0 cf] format


    if isfield(parameters_struct,'rcnn_boxes') && parameters_struct.rcnn_boxes
        % pick a box using the saved rcnn box scores
        box_ind = sample_1d( d.learned_stuff.faster_rcnn_data.box_scores );
        box_xywh = double(d.learned_stuff.faster_rcnn_data.boxes_xywh(box_ind,:));
        c0 = box_xywh(1);
        r0 = box_xywh(2);
        w  = box_xywh(3);
        h  = box_xywh(4);
        rf = r0 + h - 1;
        cf = c0 + w - 1;
        rc = r0 + h/2;
        cc = c0 + w/2;
        box_r0rfc0cf = [r0 rf c0 cf];
        return
    end
       
    

    switch d.location_sampling_method
        case 'ior_peaks'
            [point, d.location_data] = ior_peaks(    d.location_data, 1, parameters_struct.inhibition_size, parameters_struct.inhibition_method, parameters_struct.inhibition_intensity );
            d.location_display = d.location_data;
            rc = point(1);
            cc = point(2);
        case 'ior_sampling' 
            [point, d.location_data] = ior_sampling( d.location_data, 1, parameters_struct.inhibition_size, parameters_struct.inhibition_method, parameters_struct.inhibition_intensity );
            d.location_display = d.location_data;
            rc = point(1);
            cc = point(2);
        case 'sampling'
            [point] = sample_2d( d.location_data, 1 );
            d.location_display = d.location_data;
            rc = point(1);
            cc = point(2);
        case '4d'
            % just pass on through, it'll all happen in the box_method
            % section
            
                
        
        otherwise
            warning('newmethodwarning','new method code goes here');
        
            error('situate_sample_box:unrecognized_location_sampling_method', ['situate_sample_box:unrecognized_location_sampling_method \n method was ' d.location_sampling_method] );
    end

    switch d.box_method
        case '4d_log_aa'
            % we'll ignore the sampled location from above and just use the
            % 4d salience block to get the whole thing
            method = 'peak';
            inhibition_dimensions = d.box_data.inhibition_widths;
            [s_ind,d.box_data.pdf4d] = ior_4d_sample( d.box_data.pdf4d, inhibition_dimensions, parameters_struct.inhibition_intensity, method );
            rc = d.box_data.domains{1}(s_ind(1));
            cc = d.box_data.domains{2}(s_ind(2));
            aspect = 2 .^ d.box_data.domains{3}(s_ind(3));
            area   = d.image_size_px * 10 .^ d.box_data.domains{4}(s_ind(4));
            [w,h] = box_aa2wh(aspect,area);
            % d.sampled_boxes_record_pdf4d_inds(end+1,:) = s_ind;
        case 'conditional_mvn_log_aa', 
            temp = mvnrnd( d.box_data.mu, d.box_data.Sigma );
            log2_aspect_ratio = temp(1);
            log10_area_ratio  = temp(2);
            aspect = 2.^log2_aspect_ratio;
            area   = d.image_size_px * 10.^log10_area_ratio;
            [w,h] = box_aa2wh(aspect,area);
        case 'conditional_mvn_aa',
            temp = mvnrnd( d.box_data.mu, d.box_data.Sigma);
            aspect     = temp(1);
            area_ratio = temp(2);
            [w,h] = box_aa2wh( aspect, d.image_size_px * area_ratio );
        case 'conditional_mvn_log_wh',
            temp = mvnrnd( d.box_data.mu, d.box_data.Sigma);
            log_width = temp(1);
            log_height = temp(2);
            w = sqrt(d.image_size_px) * exp(log_width);
            h = sqrt(d.image_size_px) * exp(log_height);
        case 'conditional_mvn_wh',
            temp = mvnrnd( d.box_data.mu, d.box_data.Sigma);
            w = sqrt(d.image_size_px) * temp(1);
            h = sqrt(d.image_size_px) * temp(2);
            
        case 'independent_uniform_log_wh'
            w = sqrt(d.image_size_px) * exp( sample_1d( d.box_data.pdf1.x, d.box_data.pdf1.y, 1 ) );
            h = sqrt(d.image_size_px) * exp( sample_1d( d.box_data.pdf2.x, d.box_data.pdf2.y, 1 ) );
        case 'independent_uniform_wh'
            w = sqrt(d.image_size_px) * sample_1d( d.box_data.pdf1.x, d.box_data.pdf1.y, 1 );
            h = sqrt(d.image_size_px) * sample_1d( d.box_data.pdf2.x, d.box_data.pdf2.y, 1 );
        case 'independent_uniform_log_aa'
            aspect =  2.^( sample_1d( d.box_data.pdf1.x, d.box_data.pdf1.y, 1 ) );
            area   = d.image_size_px * 10.^( sample_1d( d.box_data.pdf2.x,   d.box_data.pdf2.y, 1 )   );
            [w,h]  = box_aa2wh( aspect, area );
        case 'independent_uniform_aa'
            aspect = sample_1d( d.box_data.pdf1.x, d.box_data.pdf1.y, 1 );
            area   = d.image_size_px * sample_1d( d.box_data.pdf2.x, d.box_data.pdf2.y, 1 );
            [w,h]  = box_aa2wh( aspect, area );
            
        case 'independent_normals_aa'
            aspect = d.box_data.pdf1.mu + d.box_data.pdf1.sigma * randn(1);
            area   = d.image_size_px * d.box_data.pdf2.mu + d.box_data.pdf2.sigma * randn(1);
            [w,h]  = box_aa2wh( aspect, area );
        case 'independent_normals_log_aa'
            aspect = 2  ^ (d.box_data.pdf1.mu + d.box_data.pdf1.sigma * randn(1));
            area   = d.image_size_px * 10 ^ (d.box_data.pdf2.mu + d.box_data.pdf2.sigma * randn(1));
            [w,h]  = box_aa2wh( aspect, area );
        case 'independent_normals_wh'
            w = sqrt(d.image_size_px) * (d.box_data.pdf1.mu + d.box_data.pdf1.sigma * randn(1));
            h = sqrt(d.image_size_px) * (d.box_data.pdf2.mu + d.box_data.pdf2.sigma * randn(1));
        case 'independent_normals_log_wh'
            w = sqrt(d.image_size_px) * exp( d.box_data.pdf1.mu + d.box_data.pdf1.sigma * randn(1) );
            h = sqrt(d.image_size_px) * exp( d.box_data.pdf2.mu + d.box_data.pdf2.sigma * randn(1) );
            
        otherwise
            
            warning('newmethodwarning','new method code goes here');
        
            error('situate_sample_box:unrecognized_box_method',['situate_sample_box:unrecognized_box_method \n method was ' d.box_method ]);
    end

    r0 = rc - round(h/2);
    rf = r0  + h - 1;
    c0 = cc - round(w/2);
    cf = c0  + w - 1;
    
    box_r0rfc0cf = [r0 rf c0 cf];
    
    d.sampled_boxes_record_r0rfc0cf(end+1,:) = box_r0rfc0cf;
    d.sampled_boxes_record_centers(end+1,:)  = [rc cc];
    
end








        


















