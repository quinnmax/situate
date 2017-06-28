
function [boxes_r0rfc0cf, sample_density] = uniform_sample( model, object_type, n, im_dims, existing_box_r0rfc0cf )
    
    % [boxes_r0rfc0cf, sample_density] = uniform_sample( model, object_type, [n], [im_row im_col]); 
    %   if run without the existing_box var, then you get a sampled box
    %   if run with an existing_box var, then you get the density for that box
   
    if ~exist('n','var') || isempty(n)
        n = 1;
    end
    
    if ~exist('im_dims','var')
        im_dims = [];
    end
    
    %% if existing box was passed in, just figure out its density and return
    if exist('existing_box_r0rfc0cf','var') && ~isempty(existing_box_r0rfc0cf)
        
        % location density is with respect to a unit area, so the density at each point is just 1
        location_density = 1;
        
        % shape density
        box_w = existing_box_r0rfc0cf(4) - existing_box_r0rfc0cf(3);
        box_h = existing_box_r0rfc0cf(2) - existing_box_r0rfc0cf(1);
        aspect_ratio = box_w / box_h;
        if aspect_ratio >= model.aspect_min && aspect_ratio <= model.aspect_max
            shape_density = 1 / (log(model.aspect_max) - log(model.aspect_min));
        else
            shape_density = 0;
        end
        
        % size density
        area_ratio = (box_w * box_h) / (im_dims(1) * im_dims(2));
        if aspect_ratio >= model.area_ratio_min && area_ratio <= model.area_ratio_max
            size_density = 1 / (log(model.area_ratio_max) - log(model.area_ratio_min));
        else
            size_density = 0;
        end
        
        boxes_r0rfc0cf = existing_box_r0rfc0cf;
        sample_density = location_density * shape_density * size_density;
        
        return;
        
    end
    
    %% otherwise, actually generate a bounding box
    
    % location density is with respect to a unit area, so the density at each point is just 1
        aspect_ratio = exp( log(model.aspect_min)     + rand() * (log(model.aspect_max)     - log(model.aspect_min)) );
        area_ratio   = exp( log(model.area_ratio_min) + rand() * (log(model.area_ratio_max) - log(model.area_ratio_min)) );
        [w,h] = box_aa2wh(aspect_ratio,area_ratio*im_dims(1)*im_dims(2));
        
        rc = round( 1 + h/2 + rand() * (im_dims(1)-h/2) );
        cc = round( 1 + w/2 + rand() * (im_dims(2)-w/2) );
        
        r0 = rc - h/2 +.5;
        rf = r0 + h - 1;
        c0 = cc - w/2 + .5;
        cf = c0 + w - 1;
        boxes_r0rfc0cf = round([r0 rf c0 cf]);
        
        % call with the generated box to get the density
        [~, sample_density] = situation_models.uniform_sample( model, object_type, 1, im_dims, boxes_r0rfc0cf );
        
        % if we have a violation, recall the function until we get something
        if r0 < 1 || c0 < 1 || rf > im_dims(1) || cf > im_dims(2)
            [boxes_r0rfc0cf, sample_density] = situation_models.uniform_sample( model, object_type, n, im_dims, [] );
        end
        
end







